; ----------------------------------------------------------------------------
; sd_base.asm
; Minimal SD card library for ROM usage.
;
; v1.0 - 17th August 2024
; ----------------------------------------------------------------------------

; ----------------------------------------------------------------------------
; Hardware driver for the SPI port
; ----------------------------------------------------------------------------
#ifdef GENERIC_IO
; Generic I/O port
#include "..\\Library\\spi_IO.asm"
#endif

#ifdef TEC-1G_IO
; Generic I/O port
#include "..\\Library\\spi_TEC-1G.asm"
#endif

#ifdef Z80_PIO
; Z80 PIO
#include "..\\Library\\spi_Z80PIO.asm"
#endif

; ----------------------------------------------------------------------------
#include "..\\Library\\string.asm"
#include "..\\Library\\sd_base_inc.asm"
; ----------------------------------------------------------------------------

; ============================================================================
; Api calls
; ============================================================================
; ----------------------------------------------------------------------------
; sdInit#1
; Initialise communications to the SD card and checks for a compatible SD card
;
; Input:	None
; Output:	HL -- Error string if not no card detected
; 		Carry flag set if no card detected
; Destroys:	A, BC, HL
; ----------------------------------------------------------------------------
sdInit:
	call	spiInit			; Initialise the SPI driver

	ld	a,0			; Clear the CID info flag
	ld	(sdCIDInit),a

	ld	a,SD_INIT_RETRIES	; Number of retries for SD card detection
	ld	(sdInitRetry),a
	
_sdiLoop
	call	spiReset

	ld	hl,spiCMD0
	call	sendSPICommand		; Should come back as 01 if card present
	cp	01h
	jr	z,_sdiCardFound		; SD card detected
	ld	a,(sdInitRetry)		; No SD card detected so load retry counter
	and	a
	cp	0
	jr	z,_sdiError1		; No more retries left
	dec	a
	ld	(sdInitRetry),a		; Update the retry counter
	jr	_sdiLoop		; and try again
	
_sdiCardFound
	ld	hl,spiCMD8
	call	sendSPICommand
	cp	01
	jr	nz,_sdiCmd55		; Skip past if CMD8 not supported (older cards)
	ld	b,4			; Dump 4 bytes of CMD8 status

_sdiGet5Byte
	call	readSPIByte
	djnz	_sdiGet5Byte

_sdiCmd55
	ld	a,SD_INIT_RETRIES	; Number of retries for SD card detection
	ld	(sdInitRetry),a

_sdiCmd55Loop
	call	lDelay
	ld	hl,spiCMD55
	call	sendSPICommand
	ld	hl,spiACMD41
	call	sendSPICommand		; Expect to get 00; init'd. If not, init is in
					; progress
	cp	0
	jr	z,_sdiDone
	ld	a,(sdInitRetry)		; No init so load retry counter
	and	a
	cp	0
	jr	z,_sdiError4		; No more retries left
	dec	a
	ld	(sdInitRetry),a		; Update the retry counter
	jr	_sdiCmd55Loop		; Try again if not ready. Can take several 
					; cycles

_sdiDone				; we are initialised!!
	call	spiIdle			; Set the SPI bus to the idle state

	scf				; clear carry flag on exit
	ccf
	ret

_sdiError1
	ld	a,1			; Get no card detected error message
	call	errorMsg

	scf				; set carry flag on exit
	ret

_sdiError4
	ld	a,4			; Get unable to initialise card error message
	call	errorMsg

	scf				; set carry flag on exit
	ret

; ----------------------------------------------------------------------------
; getCardType#2
; Check and return whether the card is SDSC or SDHC
;
; Requires
;
; Input:	None.
; Output:	A -- 80h = SDSC, C0h = SDHC
;		Carry flag set if no card detected.
; Destroys:	A
; ----------------------------------------------------------------------------
getCardType:
	push	bc			; Save registers
	push	de
	push	hl

	call	getCID			; Get the SD card hw info
	jr	z,_getCT1		; OK, then continue
	pop	hl			; if not, restore registers
	pop	de
	pop	bc

	scf				; Return with carry flag set on error
	ret	nz			; and return

_getCT1
	ld	hl,spiCMD58		; Get OCR Register
	call	sendSPICommand
	cp	0
	jp	z,_checkOCROK
	pop	hl			; if not, restore registers
	pop	de
	pop	bc

	scf				; Return with carry flag set on error
	ret
	
_checkOCROK
	ld	b,4			; 4 bytes returned
	ld	hl,sdBuff

_getR3Response
	call	readSPIByte
	ld	(hl),a
	inc	hl
	djnz	_getR3Response

	ld	a,(sdBuff)		; Bit 7 = valid, bit 6 = SDHC if 1,
					; SDSC if 0
	and	0c0h

	pop	hl			; Restore registers
	pop	de
	pop	bc

	call	spiIdle

	scf				; clear carry flag on exit
	ccf
	ret				; and return

; ----------------------------------------------------------------------------
; selectDisk#3
; Sets the global disk offset to match the requested disk. In the event of an
; invalid disk number being selected, the disk will remain unchanged and the
; disk number in use will be returned in A.
; 
; Input:	A -- Disk number (0-7)
; Output:	A -- Disk number set, carry set on invalid disk, cleared on
; 		     success.
; Destroys:	A
; ----------------------------------------------------------------------------
selectDisk:
	cp	0			; Is the disk >= 0?
	jr	nc,_sdkValid
	jr	_sdkInv			; No, then not a valid disk number

_sdkValid
	cp	8			; Is the disk < 8 (0-7)
	jr	c,_sdkExit
	jr	_sdkInv			; No, then not a valid disk number

_sdkInv
	ld	hl,(diskOffset)		; Load the current disk back into A
	ld	a,h

	scf				; Return error
	ret

_sdkExit
	ld	h,a
	ld	l,0
	ld	(diskOffset),hl		; Update the new disk offset

	scf				; Return success
	ccf
	ret

; ----------------------------------------------------------------------------
; readSlotFCB#4
; Reads the FCB for the slot and returns the ASCII directory entry
; Assumes the SD card has already been initialised and is valid
;
; Input:	A -- Slot number (0-127).
; Output:	HL -- Pointer to ASCII version of slot directory entry
;		IY -- Pointer to FCB buffer
; Destroys:	A, BC, DE, HL
; ----------------------------------------------------------------------------
readSlotFCB:
	ld	hl,64			; Get first FCB into buffer
	ld	(currSlot),a		; Save the slot number
	and	0F8h			; Determine the sector offset
	srl	a
	srl	a
	srl	a
	add	a,l
	ld	(currSector),a

	ld	a,(currSlot)		; Remove sector info from slot
	and	07h
	ld	(slotOffset),a

	call	readSdSector		; Get the FCB sector for the slot
	ret	c			; Error has occured so bail out

	xor	a

	ld	hl,dirStrBuff		; Clear the directory buffer
	ld	a,' '
	ld	b,DIR_END
_rsLoop
	ld	(hl),a
	inc	hl
	djnz	_rsLoop

	ld	a,(currSlot)		; Save slot number to dir buffer
	ld	l,a
	ld	h,0
	ld	ix,decimalBuff
	call	decimalA
	
	ld	hl,decimalBuff
	ld	de,dirStrBuff+DIR_SLOT
_rsLoop1
	ld	a,(hl)
	ld	(de),a
	cp	' '
	jr	z,_rsLoop2
	inc	de
	inc	hl
	jr	_rsLoop1
	
_rsLoop2
	ld	a,(slotOffset)		; Restore the slot offset in the sector 
	call	getFileDir		; Get the rest of the dir contents

	call	spiIdle

	ret

; ----------------------------------------------------------------------------
; readFile#5
; Reads a file at the specified slot and loads it at the start address
; specified in the file to that RAM address.
;
; Input:	A -- Slot number to read from (0-127)
; Output:	HL -- Contains pointer to error message if read failed
; 		Carry flag set if file read failed, cleared if success
; Destroys:	A, BC, DE, HL
; ----------------------------------------------------------------------------
readFile:
	ld	(currSlot),a		; Save the slot number
	call	sdInit			; Initialise the SD card
	jp	nc,_readfCont		; Card detected
	ld	a,ERR_NO_CARD

	ret

_readfCont
	call	isFormatted		; SD present and formatted?
	jp	nc,_readfCont1		; Card formatted
	ld	a,ERR_NO_FORMAT

	ret

_readfCont1
	ld	hl,64			; Determine the FCB sector
	ld	a,(currSlot)
	and	0f8h
	srl	a
	srl	a
	srl	a
	add	a,l
	ld	l,a
	ld	(currSector),hl

	call	readSdSector

	ld	a,(currSlot)		; Remove sector info from slot
	and	07h			; A = old style slot (0-7)
					; currSlot = new style slot (0-127)
					; currSector = FCB sector

	ld	(fcbOffset),a
	call	calcOffset		; sets up IY register

	ld	l,(iy+FCB_START_ADDR)	; Start in memory, FFFF = no file
	ld	h,(iy+FCB_START_ADDR+1)	; Start in memory, FFFF = no file

	ld	de,0ffffh		; 16-bit CP
	or	a
	sbc	hl,de
	add	hl,de
	jr	nz,_readfValid

	ld	b,01			; error if selecting empty slot
	scf
	ret

_readfValid
	ld	(addrStart),hl
	ld	(memPos),hl

	ld	l,(iy+FCB_LENGTH)	; TEC memory length
	ld	h,(iy+FCB_LENGTH+1)	; TEC memory length
	ld	(memBlockSize),hl

	ld	l,(iy+FCB_START_SECT+2)	; start sector
	ld	h,(iy+FCB_START_SECT+3)	; start sector
	ld	(currSector),hl

	ld	l,(iy+FCB_SECT_COUNT)	; now many sectors to load
	ld	h,(iy+FCB_SECT_COUNT+1)	; now many sectors to load
	ld	(numSectors),hl

; prep done, now load

_blockFromSD
	call	readSdSector		; get block

	ld	bc,512
	ld	hl,(memBlockSize)
	or	a
	sbc	hl,bc
	add	hl,bc
	jr	nc,_mBlk
	ld	b,h
	ld	c,l

_mBlk
	ld	de,(memPos)		; copy to TEC memory
	ld	hl,sdBuff
	ldir

	ld	hl,(numSectors)
	dec	hl
	ld	(numSectors),hl

	ld	a,h			; 0 left to go?
	or	l
	jr	z,_loadDone

	ld	hl,(currSector)		; next sector
	inc	hl
	ld	(currSector),hl

	ld	hl,(memBlockSize)	; decrease count by length
	ld	bc,512
	or	a
	sbc	hl,bc
	ld	(memBlockSize),hl	; if there's a block theres a transfer....

	ld	hl,(memPos)		; next TEC memory location
	ld	bc,512
	add	hl,bc
	ld	(memPos),hl

	jr	_blockFromSD

_loadDone
	call	spiIdle

	ret

; ----------------------------------------------------------------------------
; writeFile#6
; Write a file to SD card at the specified slot
;
; Input:	A -- Slot number to write to (0-127)
;		BC -- Size of the block to write
;		DE -- Start address of memory block to write
;		IX -- Pointer to null terminated file name
; Output:	Carry flag set if file write failed, cleared if success
; Destroys:	A, BC, DE, HL
; ----------------------------------------------------------------------------
writeFile:
	push	ix
	pop	hl

	ld	(paramStrPtr),hl	; Save the parameters passed in
	ld	(fileStart),de
	ld	(fileLength),bc
	ld	(currSlot),a

	push	hl
	ld	hl,(fileStart)		; Add the start address and ...
	adc	hl,bc			; ... length together
	dec	hl			; Subtract 1 from the end address
	ld	(fileEnd),hl		; and store the end address

	pop	hl			; Calculate the current sector for the
					; slot number given
	ld	hl,64			; Get first FCB into buffer
	and	0F8h			; Determine the sector offset
	srl	a
	srl	a
	srl	a
	add	a,l
	ld	(currSector),a

	ld	a,(currSlot)		; Remove sector info from slot
	and	07h

	ld	(fcbOffset),a
	ld	hl,(currSector)
	ld	(fcbToUpdate),hl	; where FCB's go, later

	ld	hl,0000h		; calculate correct currSector for 
					; the write
	ld	a,(currSector)		; selected by selectSlot
	ld	b,a			; HL * 128 = page

	sub	64
	cp	0
	jr	z,_fixAADone
	ld	de,1024

_fixAA
	add	hl,de
	djnz	_fixAA

_fixAADone
	ld	a,(fcbOffset)		; calculate offset
	ld	b,a
	cp	0
	jr	z,_fixADone
	ld	de,128

_fixA
	add	hl,de
	djnz	_fixA

_fixADone
	ld	de,128			; add final offset
	add	hl,de

	ld	(currSector),hl
	ld	(startSector),hl

	ld	hl,(fileStart)		; transfer default into working area
	ld	(memPos),hl

	ld	hl,0
	ld	(numSectors),hl

_blockToSD
	ld	bc,512
	ld	hl,(fileLength)
	or	a
	sbc	hl,bc
	add	hl,bc
	jr	nc,_mBlk2
	ld	b,h
	ld	c,l

_mBlk2
	ld	de,sdBuff		; RAM > Buff
	ld	hl,(memPos)
	ldir

; prep done, now save
	call	writeSdSector
	ret	c

; next sector calculations
	ld	hl,(numSectors)		; count how many written
	inc	hl
	ld	(numSectors),hl

	ld	hl,(fileLength)		; decrease count by length
	ld	bc,512
	or	a
	sbc	hl,bc

	jr	z,_writeDone		; 0 bytes left
	jp	m,_writeDone		; we went negative, so done

	ld	(fileLength),hl		; size of next block

_nextblock
	ld	hl,currSector		; next sector
	inc	(hl)

	ld	hl,(memPos)		; next RAM block
	ld	bc,512
	add	hl,bc
	ld	(memPos),hl
	jr	_blockToSD

_writeDone
	ld	hl,(fcbToUpdate)	; get correct sector
	ld	(currSector),hl
	call	readSdSector

	call	calcOffset

	ld	hl,(paramStrPtr)	; See if we need to update the filename
	ld	a,h
	or	l
	jr	z,_fnDefault		; Use default filename


	push	iy
	push	iy
	pop	de
	ld	bc,DESC_SIZE
	ldir
	pop	iy

_fnDefault
	ld	hl,(fileStart)		; update start
	ld	(iy+FCB_START_ADDR),l
	ld	(iy+FCB_START_ADDR+1),h

; ******************* Need to check this!
	ld	hl,(fileEnd)
	ld	bc,(fileStart)
	or	a
	sbc	hl,bc
	inc	hl			; +1 for start byte
	ld	(iy+FCB_LENGTH),l	; update length
	ld	(iy+FCB_LENGTH+1),h	; update length

	xor	a			; not expand
	ld	(iy+FCB_EXPAND),a

	ld	hl,0
	ld	(iy+FCB_START_SECT),l	; update start sector MSW
	ld	(iy+FCB_START_SECT+1),h	; update start sector MSW
	ld	hl,(startSector)
	ld	(iy+FCB_START_SECT+2),l	; update start sector LSW
	ld	(iy+FCB_START_SECT+3),h	; update start sector LSW

	ld	hl,(numSectors)
	ld	(iy+FCB_SECT_COUNT),l	; update number of sectors
	ld	(iy+FCB_SECT_COUNT+1),h	; update number of sectors

	call	writeSdSector		; save change
	ret	c
	call	spiIdle

	ret

; ----------------------------------------------------------------------------
; sdFormatCard#7
; Formats the SD card with Mem-SDS
;
; Input:	None.
; Output:	None.
; Destroys:	A, BC, DE, HL
; ----------------------------------------------------------------------------
sdFormatCard:
	call	sdInit			; Initialise the SD card

; prep MBR
	ld	hl,sdBuff		; zero out buffer
	ld	de,sdBuff+1
	ld	bc,511
	xor	a
	ld	(hl),a
	ldir

	ld	hl,sdFormat		; copy format into buffer
	ld	de,sdBuff
	ld	bc,sdFormatLen
	ldir

	ld	a,0ffh			; Get disk number
	call	selectDisk
	
	ld	de,wordStrBuff
	call	aToString
	ld	de,wordStrBuff

	ld	a,(de)			; Add disk number to volume label
	ld	(sdBuff+19),a
	inc	de
	ld	a,(de)
	ld	(sdBuff+20),a

	ld	a,55h			; write partition signature
	ld	(sdBuff+510),a
	ld	a,0aah
	ld	(sdBuff+511),a

	ld	hl,0			; Write MBR sector
	ld	(currSector),hl
	call	writeSdSector

; now prep FCB file tables

	ld	hl,sdBuff		; zero out buffer
	ld	de,sdBuff+1
	ld	bc,511
	xor	a
	ld	(hl),a
	ldir

; 8 blocks
	ld	de,sdBuff
	ld	b,8			; 64b * 8 = 512b

_fillBuffFcb
	push	bc

	ld	hl,fcbFormat		; copy format into buffer
	ld	bc,fcbFormatLen
	ldir

	ld	hl,fcbFormatSpc		; skip over empty bytes
	add	hl,de
	ex	de,hl

	pop	bc
	djnz	_fillBuffFcb

	ld	hl,0			; set first file number
	ld	(byteBuff),hl
	ld	hl,64			; set first sector number
	ld	(currSector),hl

; now write that out to the card 16 times (16*8 = 128 files max)

_fcbLp
	call	fnStamp			; tweak the filenames
	call	writeSdSector

	ld	hl,(currSector)
	inc	hl
	ld	(currSector),hl

	ld	a,l			; find when at last sector
	cp	64+16
	jr	nz,_fcbLp

	call	spiIdle

	ret				; and return

; ============================================================================
; Function calls
; ============================================================================

; ----------------------------------------------------------------------------
; calcOffset
; Calculates the offset in the sector for the slots FCB and assigns to IY
; Requires fcbOffset to be calculated prior
;
; Input:	IY -- Pointer into sdBuff of current file's FCB entry
; Output:	None
; Destroys:	A, BC, DE, HL
; ----------------------------------------------------------------------------
calcOffset:
	push	af
	push	bc
	push	de

	ld	a,(fcbOffset)
	ld	iy,sdBuff
	cp	0
	jr	z,_coDone
	ld	b,a
	ld	de,64

_coLoop
	add	iy,de
	djnz	_coLoop

_coDone
	pop	de
	pop	bc
	pop	af
	ret

; ----------------------------------------------------------------------------
; CRC-16-CCITT checksum
;
; Poly: &1021
; Seed: &0000
;
; Input:	IX -- Data address
;		DE -- Data length
; Output:	HL -- CRC-16
; Destroys:	A, BC, DE, HL, IX
; ----------------------------------------------------------------------------
crc16:
	ld	hl,0000h
	ld	c,8

_c16Read
	ld	a,h
	xor	(ix+0)
	ld	h,a
	inc	ix
	ld	b,c

_c16Shift
	add	hl,hl
	jr	nc,_c16NoXor
	ld	a,h
	xor	010h
	ld	h,a
	ld	a,l
	xor	021h
	ld	l,a

_c16NoXor
	djnz	_c16Shift
	dec	de
	ld	a,d
	or	e
	jr	nz,_c16Read

	ret

; -----------------------------------------------------------------------------
; decimalA
; converts A to decimal
; Input:	A -- Number to convert
;		IX -- Memory location to store result
; Output:	None
; Destroys:	A, BC, DE, HL, IX
; -----------------------------------------------------------------------------
decimalA:
	ld	e,1			; 1 = don't print a digit

	ld	l,a
	ld	a,0
	ld	h,a

	ld	bc,-100
	call	_daNum1
	ld	c,-10
	call	_daNum1
	ld	c,-1

_daNum1
	ld	a,'0'-1

_daNum2
	inc	a
	add	hl,bc
	jr	c,_daNum2
	sbc	hl,bc

	ld	d,a			; backup a
	ld	a,e
	or	a
	ld	a,d			; restore it in case
	jr	z,_daProut		; if E flag 0, all ok, print any value

	ld	e,0			; clear flag & print it

_daProut
	ld	(ix),a
	inc	ix
	ld	a,' '
	ld	(ix),a
	ret

; ----------------------------------------------------------------------------
; errorMsg
; Returns error message for a given error code
;
; Input:	A -- Error code
; Output:	HL -- Pointer to string containing error message
;		Returns 'Invalid error code" string on invalid error code
; Destroys:	A, BC, DE, HL, IX
; ----------------------------------------------------------------------------
errorMsg:
	push	af
	ld	a,(errMax)
	ld	b,a
	pop	af
	cp	b
	jr	c,_errorValid		; Check for a valid error code
	ld	hl,errInvalidCode	; No, then report invalid code

	scf				; Return error in carry flag
	ret

_errorValid
	ld	hl,errTable		; Get the base to the error table
	sla	a			; multiple code by 2 for correct index
	ld	b,0
	ld	c,a
	adc	hl,bc			; Calculate the offset for the message

	push	hl
	pop	ix
	ld	h,(ix+1)		; Update HL with pointer to message
	ld	l,(ix+0)

	scf				; Return success
	ccf
	ret

; ----------------------------------------------------------------------------
; fnStamp
; Automatic numbering for default file names. Modifies the filename string
; directly
;
; Input:	None
; Output:	None
; Destroys:	A, DE, HL
; ----------------------------------------------------------------------------
fnStamp:
	push	bc
	push	de

	ld	de,sdBuff+05h
	ld	b,8

_fnLoop:
	ld	a,(byteBuff)
	push	af
	push	bc
	call	aToDecString
	pop	bc
	pop	af
	inc	a
	ld	(byteBuff),a

	ld	hl,64-3
	add	hl,de
	ex	de,hl

	djnz	_fnLoop

	pop	de
	pop	bc

	ret

; ----------------------------------------------------------------------------
; getCID
; Read the cards CID register and return a pointer to it in HL
;
; Input:	None
; Output:	HL -- Pointer to CID register
; Destroys:	A, BC, DE, HL
; ----------------------------------------------------------------------------
getCID:
	ld	a,(sdCIDInit)		; Check to see if we have already got
					; the CID info
	xor	a
	jr	z,_getCID1		; we haven't so go get the CID info

	ld	hl,sdCIDRegister	; Return pointer to the CID register
					; in hl
	ret

_getCID1
	ld	hl,spiCMD10
	call	sendSPICommand		; Check command worked (=0)
	cp	0
	ret	nz

	ld	bc,16			; How many bytes of data we need to get
	call	readSPIBlock

	ld	b,15
	ld	de,sdCIDRegister
	ld	hl,sdBuff

_getCID2
	ld	a,(hl)			; Copy CID register from buffer to var
	ld	(de),a 
	inc	de
	inc	hl
	djnz	_getCID2
	
	ld	hl,sdCIDRegister	; Return pointer to the CID register
					; in hl
	
	ld	a,1			; Record we have got the CID info.
	ld	(sdCIDInit),a

	call	spiIdle

	ret

; ----------------------------------------------------------------------------
; getFileDir
; Get the file directory information for a file
; A = Slot number
; Returns HL = File dir contents
; ----------------------------------------------------------------------------
getFileDir:
	ld	(fcbOffset),a		; Get the FCB associated with this slot
	call	calcOffset

	push	iy
	pop	hl
	ld	de,fcbDescription
	ld	bc,FCB_END+1
	ldir

	ld	hl,fcbDescription	; Get the filename from the FCB
	ld	de,dirStrBuff+DIR_DESC	; and store it in the dir buffer
	ld	bc,DESC_SIZE
	ldir

	ld	hl,(fcbStartAddress)	; Get the start address

	ld	de,0ffffh		; If it is FFFFH then this is an empty
	or	a			; slot
	sbc	hl,de
	add	hl,de
	jp	z,_gfNotFound		; This is an empty slot

	ld	hl,(fcbStartAddress)	; Get the start address
	ld	de,dirStrBuff+DIR_START
	call	hlToString

	ld	a,'H'			; Append the trailing hex symbol
	ld	(de),a

	ld	hl,(fcbLength)		; Get the file length
	ld	de,dirStrBuff+DIR_LENGTH
	call	hlToString

	ld	a,'H'			; Append the trailing hex symbol
	ld	(de),a

	ld	hl,dirStrBuff+DIR_END	; Append a null the end of the buffer
	ld	a,0
	ld	(hl),a

	scf				; clear carry flag, file found
	ccf

_gfExit
	ld	hl,dirStrBuff		; Return the directory entry

	ret

_gfNotFound
	scf				; Set carry flag - slot is empty
	jr	_gfExit

; ----------------------------------------------------------------------------
; isFormatted
; Checks to see if SD card is formatted by finding MBR signature
;
; Input:	None
; Output:	HL -- Error string if card is not formatted
;		Carry flag set if not a valid MBR, clear if valid
; Destroys:	A, BC, DE, HL, sdBuff
; ----------------------------------------------------------------------------
isFormatted:
	call	spiIdle

	ld	hl,0			; fetch sector
	ld	(currSector),hl
	call	readSdSector

	call	spiIdle

	ld	hl,sdFormat		; "MEMSDS"
	ld	de,sdBuff
	ld	b,6

; _ifCp	ld	a,(de)			; Check to see if the first 6 bytes of
	; ld	c,a			; the MBR contains "MEMSDS"
	; ld	a,(hl)
	; cp	c
	; jr	nz,_ifCpFail
	; inc	de
	; inc	hl
	; djnz	_ifCp
	call	strCompare
	jr	c,_ifCpFail

	scf
	ccf				; Successful so clear carry flag 
	ret

_ifCpFail
	ld	a,ERR_NO_FORMAT		; Card not formatted error
	call	errorMsg

	scf				; Error so set carry flag
	ret

; ----------------------------------------------------------------------------
; isSDHC
; Checks to see if SD card is an SDHC card
;
; Input:	None
; Output:	HL -- Error string if not an SDHC card
; 		Carry flag set if not an SDHC card, clear if it is.
; Destroys:	A, BC, DE, HL, sdBuff
; ----------------------------------------------------------------------------
isSDHC:
	call	getCardType

	cp	0c0h
	jr	z,_isSDHCOK

	ld	a,ERR_NO_SDHC		; Get no card detected error message

	scf				; Not an SDHC card so return carry set
	ret

_isSDHCOK
	scf				; Is an SDHC card so return carry clear
	ccf
	ret

; ----------------------------------------------------------------------------
; lDelay
; General purpose delay loop
;
; Input:	None
; Output:	None
; Destroys:	A
; ----------------------------------------------------------------------------
lDelay:	push	af
	push	de

	ld	de,0c000h

_lInner
	dec	de
	ld	a,d
	or	e
	jr	nz,_lInner

	pop	de
	pop	af

	ret

; ----------------------------------------------------------------------------
; readSdSector
; read a sector from SD card
; reads from currSector
;
; Input:	currSector
; Output:	None
;		Sets carry flag on error, clears on success
; Destroys:	A, BC, DE, HL
; ----------------------------------------------------------------------------
readSdSector:
	ld	hl,spiCMD17		; load up our variable
	ld	de,spiCMD17var
	ld	bc,6
	ldir

	ld	bc,(diskOffset)
	ld	(spiCMD17var+1),bc	; put our sector # MSW here

	ld	hl,(currSector)
	ld	a,h			; swap byte order
	ld	h,l
	ld	l,a
	ld	(spiCMD17var+3),hl	; put our sector # LSW here

	ld	hl,spiCMD17var		; write command
	call	sendSPICommand		; check command worked (=0)
	cp	0
	jr	z,_rssCont
	scf				; Error so set carry flag
	jr	_rssEnd

_rssCont
	ld	bc,514
	call	readSPIBlock
	scf
	ccf				; No error so clear carry flag

_rssEnd
	ret

; ----------------------------------------------------------------------------
; readSPIBlock
; Read SD card sector to buffer
;
; Input:	BC -- Number of bytes to read
; Output:	None
; Destroys:	A, BC, HL
; ----------------------------------------------------------------------------
readSPIBlock:
	ld	hl,sdBuff

_waitToken
	call	spiRdb
	cp	0ffh			; ffh == not ready yet
	jr	z,_waitToken
; todo = 0000xxxx = error token; handle this
; todo, add timeout
	cp	0feh			; feh == start token. We discard this.
	jr	nz,_waitToken

_blockLoopR				; Load in all the bytes
	call	spiRdb
	ld	(hl),a
	inc	hl
	dec	bc
	ld	a,b
	or	c
	jr	nz,_blockLoopR

	ret

; ----------------------------------------------------------------------------
; readSPIByte
; ReadSPIByte; reads with loop to wait for ready (FFh = not ready)
;
; Input:	currSector
; Output:	A -- Read value. Timeout error returns 0ffh
; Destroys:	A
; ----------------------------------------------------------------------------
readSPIByte:
	push	bc
	push	de
	ld	b,32			; Wait up to 32 tries, but should
					; need 1-2

_readLoop
	call	spiRdb			; Get value in A
	cp	0ffh
	jr	nz,_result
	djnz	_readLoop

_result
	pop	de
	pop	bc

	ret

; ----------------------------------------------------------------------------
; sendSPICommand
; 
; Input:	HL -- 6 byte command
; Output:	A -- Response code
; Destroys:	A
; ----------------------------------------------------------------------------
sendSPICommand:
	push	bc
	push	de
	push	hl
	ld	b,6

_sendSPIByte
	ld	c,(hl)
	call	spiWrb
	inc	hl
	djnz	_sendSPIByte
	call	readSPIByte
	pop	hl
	pop	de
	pop	bc

	ret

; ----------------------------------------------------------------------------
; writeSdSector
; Write a sector to SD card
;
; Calculates CRC16
; Writes 512b sdBuff to SD card at sector currSector
;
; Input:	sdBuff, currSector
; Output:	A -- Result code, 05 = success
;		Sets carry flag on error, clears on success
; Destroys:	A, BC, DE, HL
; ----------------------------------------------------------------------------
writeSdSector:
	ld	ix,sdBuff		; get CRC16
	ld	de,512
	call	crc16
	ld	a,h
	ld	(sdBuff+512),a		; and save CRC16
	ld	a,l
	ld	(sdBuff+513),a

	ld	hl,spiCMD24		; load up our variable
	ld	de,spiCMD24var
	ld	bc,6
	ldir

	ld	bc,(diskOffset)
	ld	(spiCMD24var+1),bc	; put our sector # MSW here

	ld	hl,(currSector)
	ld	a,h			; swap byte order
	ld	h,l
	ld	l,a
	ld	(spiCMD24var+3),hl	; put our sector # LSW here

	ld	hl,spiCMD24var		; write command
	call	sendSPICommand		; check command worked (=0)
	cp	0
	jp	z,_writeSdBlock		; No error
	call	spiIdle

	scf				; Set carry flag as error and return
	ret

_writeSdBlock
	call	writeSPIBlock
	cp	05h			; check write worked
	jp	z,_writeSdBlockOK	; No error
	scf				; Set carry flag as error
	ret

_writeSdBlockOK
	scf				; clear carry flag on exit
	ccf
	ret

; ----------------------------------------------------------------------------
; writeSPIBlock
; Write buffer to SD card sector
;
; Input:	sdBuff
; Output:	A -- Result code, 05 = success
;		Sets carry flag on error, clears on success
; Destroys:	A, BC, DE, HL
; ----------------------------------------------------------------------------
writeSPIBlock:
	push	bc
	push	de
	ld	hl,sdBuff
	ld	de,514			; #bytes to write

	ld	c,0feh			; send start block token
	call	spiWrb

_blockLoopW				; load in all the bytes incl. CRC16
	ld	c,(hl)
	call	spiWrb
	inc	hl
	dec	de
	ld	a,d
	or	e
	jr	nz,_blockLoopW

	call	readSPIByte		; get the write response token
	ld	c,a			; save result into C

_waitDone
	call	spiRdb			; 00 = busy - wait for card to finish
	cp	00h
	jr	z,_waitDone

	ld	a,c			; restore result to A register
	and	1fh			; return code 05 = success
	pop	de
	pop	bc

	ret

#ifdef ROM_LOAD
; ----------------------------------------------------------------------------
; RST 20H entry point
; ----------------------------------------------------------------------------
; ----------------------------------------------------------------------------
; rst20Entry
; Entry point from the RST 20H restart call
;
; Input:	B -- RST 20H function call
; Output:	Sets carry flag on error, clears on success
; Destroys:	HL, IX
; ----------------------------------------------------------------------------
rst20Entry:
	push	af			; Save registers
	push	bc
	push	de

	ld	a,(r20JumpMax)
	cp	b
	jr	nc,_rst20Valid		; Check for a valid jump function

	pop	de			; Restore registers
	pop	bc
	pop	af

	scf				; Return error in carry flag
	ret

_rst20Valid
	ld	a,b			; Set A with the function call B
	ld	hl,r20JumpTable		; Get the base to the error table
	sla	a			; multiple code by 2 for correct index
	ld	b,0
	ld	c,a
	adc	hl,bc			; Calculate the offset for the jump

	push	hl
	pop	ix
	ld	h,(ix+1)		; Update HL with jump pointer
	ld	l,(ix+0)

	pop	de			; Restore registers
	pop	bc
	pop	af

	jp	(hl)

	scf				; Return success
	ccf
	ret
#endif

; ----------------------------------------------------------------------------
; Data
; ----------------------------------------------------------------------------

; ---------------------------- Error codes
; Maximum of 256 error codes. String not to exceed 20 characters

errMax		.db	5			; Number of error messages
errTable	.dw	err00			; Pointer to error message 0...
		.dw	err01
		.dw	err02
		.dw	err03
		.dw	err04

err00		.db	"Fatal error",0		; Error message 0...
err01		.db	"No card detected",0
err02		.db	"Not an SDHC card",0
err03		.db	"Disk not formatted",0
err04		.db	"Unable to initialise card",0

errInvalidCode	.db	"Invalid error code",0

#ifdef ROM_LOAD
; ---------------------------- Jump Table
; Maximum of 256 jump points

r20JumpMax	.db	8			; Number of jump points
r20JumpTable	.dw	mainNoUIEntry		; Jump address
		.dw	sdInit
		.dw	getCardType
		.dw	selectDisk
		.dw	readSlotFCB
		.dw	readFile
		.dw	writeFile
		.dw	sdFormatCard
#endif

; ---------------------------- Strings
sdFormat	.db	"MEMSDS"		; Signature
sdVolLabel	.db	"Mem SDS Disk        "	; Volume Label
		.db	00,00,01,01,01,01,00	; 1am 1/1/2023
		.db	16			; directory Sectors
sdFormatLen	.equ	$-sdFormat

fcbFormat	.db	"SLOT 000            "	; name
		.dw	0ffffh			; start, ffff = no file
		.dw	0000h			; length
		.db	00,00,01,01,01,01,00	; 1am 1/1/2023
		.dw	0000h			; start sector # (32 bits)
		.dw	0000h
		.dw	0000h			; length in sectors
fcbFormatLen	.equ	$-fcbFormat
fcbFormatSpc	.equ	64-fcbFormatLen

; ---------------------------- SPI commands
spiCMD0		.db	40h,0,0,0,0,95h		; Reset			R1
spiCMD8		.db	48h,0,0,1,0aah,87h	; Send_if_cond		R7
spiCMD9		.db	49h,0,0,1,0aah,87h	; Send_CSD		R1
spiCMD10	.db	4ah,0,0,0,0,1h		; Send_CID		R1
spiCMD16	.db	50h,0,0,2,0,1h		; Set sector size	R1
spiCMD17	.db	51h,0,0,0,0,1h		; Read single block	R1
spiCMD24	.db	58h,0,0,0,0,1h		; Write single block	R1
spiCMD55	.db	77h,0,0,0,0,1h		; APP_CMD		R1
spiCMD58	.db	7ah,0,0,0,0,1h		; READ_OCR		R3
spiACMD41	.db	69h,40h,0,0,0,1h	; Send_OP_COND		R1