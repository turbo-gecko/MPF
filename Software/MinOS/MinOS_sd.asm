; ----------------------------------------------------------------------------
; MinOS_sd.asm
; Version: 0.9
; Last updated: 27/07/2024
;
; SD card functions for MinOS.
; ----------------------------------------------------------------------------

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
	push af
	push bc
	push de

	ld a,(fcbOffset)
	ld iy,sdBuff
	cp 0
	jr z,coDone
	ld b,a
	ld de,64

coLoop
	add iy,de
	djnz coLoop

coDone
	pop de
	pop bc
	pop af
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
	ld hl,0000h
	ld c,8

c16Read
	ld a,h
	xor (ix+0)
        ld h,a
        inc ix
        ld b,c

c16Shift
        add hl,hl
        jr nc,c16NoXor
        ld a,h
        xor 010h
        ld h,a
        ld a,l
    	xor 021h
        ld l,a

c16NoXor
        djnz c16Shift
        dec de
        ld a,d
        or e
        jr nz,c16Read

 	ret

; ----------------------------------------------------------------------------
; getPNM
; Read the cards Part Number and return a pointer to a 5 character, null
; terminated string containing the Part Number as ASCII text.
;
; Input:	None.
; Output:	HL -- Pointer to null terminated part number string.
;		Zero flag set to non-zero value on error.
;		Carry flag set on error.
; Destroys:	A, HL, IX, IY
; ----------------------------------------------------------------------------
getPNM:
	push bc				; Save registers
	push de

	call getCID			; Get the SD card hw info
	jr z,getPNM1			; OK, then continue
	pop de				; Restore registers
	pop bc

	scf				; Set carry flag
	ret nz				; and non-zero flag on return

getPNM1
	push hl				; Index to data in the CID buffer
	pop ix
	ld iy,paramStrBuff		; Index to the PNM string
	ld b,5				; PNM - Product name length (see SD card Spec)

getPNM2
	ld a,(ix+3)			; loop through the 5 bytes of PNM data
	ld (iy),a			; and copy to the string
	inc ix
	inc iy
	djnz getPNM2

	ld a,0				; Add terminating null
	ld (iy),a
	
	ld hl,paramStrBuff		; HL points to the Part Number string
	ld a,0				; ensure zero flag is set for successful

	pop de				; Restore registers
	pop bc

	scf				; clear carry flag on exit
	ccf
	ret				; and return.

; ----------------------------------------------------------------------------
; getCardType
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
	push bc				; Save registers
	push de
	push hl

	call getCID			; Get the SD card hw info
	jr z,getCT1			; OK, then continue
	pop hl				; if not, restore registers
	pop de
	pop bc

	scf				; Return with carry flag set on error
	ret nz				; and return

getCT1
	ld hl,spiCMD58			; Get OCR Register
	call sendSPICommand
	cp 0
	jp z,checkOCROK
	pop hl				; if not, restore registers
	pop de
	pop bc

	scf				; Return with carry flag set on error
	ret
	
checkOCROK
	ld b,4				; 4 bytes returned
	ld hl,sdBuff

getR3Response
	call readSPIByte
	ld (hl),a
	inc hl
	djnz getR3Response

	ld a,(sdBuff)			; Bit 7 = valid, bit 6 = SDHC if 1,
					; SDSC if 0
	and 0c0h

	pop hl			 	; Restore registers
	pop de
	pop bc

	call spiInit

	scf				; clear carry flag on exit
	ccf
	ret				; and return

; ----------------------------------------------------------------------------
; getMaxFiles
; Check and return the maximum number of files that can be saved to the SD
; card
;
; Input:	None.
; Output:	A -- Maximum number of files for the SD card
;		Carry flag set if no card detected
; Destroys:	A
; ----------------------------------------------------------------------------
getMaxFiles:
	push bc				; Save registers
	push de
	push hl

	call getCID			; Get the SD card hw info
	jr z,getMF1			; OK, then continue
	pop hl				; if not, restore registers
	pop de
	pop bc

	scf				; Return with carry flag set on error.
	ret nz				; and return

getMF1
	ld a,(sdBuff+33)		; # files supported
	rla
	rla
	rla

	pop hl				; Restore registers
	pop de
	pop bc

	scf				; clear carry flag on exit
	ccf
	ret				; and return

; ----------------------------------------------------------------------------
; sdFormat
; Formats the SD card with Mem-SDS
;
; Input:	None.
; Output:	None.
; Destroys:	A, BC, DE, HL
; ----------------------------------------------------------------------------
sdFormatCard:
	call sdInit			; Initialise the SD card

; prep MBR
	ld hl,sdBuff			; zero out buffer
	ld de,sdBuff+1
	ld bc,511
	xor a
	ld (hl),a
	ldir

	ld hl,sdFormat			; copy format into buffer
	ld de,sdBuff
	ld bc,sdFormatLen
	ldir

	ld a,0ffh			; Get disk number
	call selectDisk
	
	ld de,wordStrBuff
	call aToString
	ld de,wordStrBuff

	ld a,(de)			; Add disk number to volume label
	ld (sdBuff+19),a
	inc de
	ld a,(de)
	ld (sdBuff+20),a

	ld a,55h			; write partition signature
	ld (sdBuff+510),a
	ld a,0aah
	ld (sdBuff+511),a

;	ld iy,sdBuff+FCB_RTC		; output format timestamp
;	call addTimeStamp

	ld hl,0				; Write MBR sector
	ld (currSector),hl
	call writeSdSector

; now prep FCB file tables

	ld hl,sdBuff			; zero out buffer
	ld de,sdBuff+1
	ld bc,511
	xor a
	ld (hl),a
	ldir

; 8 blocks
	ld de,sdBuff
	ld b,8				; 64b * 8 = 512b

fillBuffFcb
	push bc

	ld hl,fcbFormat			; copy format into buffer
	ld bc,fcbFormatLen
	ldir

	ld hl,fcbFormatSpc		; skip over empty bytes
	add hl,de
	ex de,hl

	pop bc
	djnz fillBuffFcb

	ld hl,0				; set first file number
	ld (byteBuff),hl
	ld hl,64			; set first sector number
	ld (currSector),hl

; now write that out to the card 16 times (16*8 = 128 files max)

fcbLp
	call fnStamp			; tweak the filenames
	call writeSdSector

	ld hl,(currSector)
	inc hl
	ld (currSector),hl

	ld a,l				; find when at last sector
	cp 64+16+1
	jr nz,fcbLp

	call spiInit

	ret				; and return

; ----------------------------------------------------------------------------
; sdInit
; Initialise communications to the SD card and checks for a compatible SD card
;
; Input:	None
; Output:	HL -- Error string if not no card detected
; 		Carry flag set if no card detected
; Destroys:	A, BC, HL
; ----------------------------------------------------------------------------
sdInit:
	ld a,0				; Clear the CID info flag.
	ld (sdCIDInit),a

	ld a,SD_INIT_RETRIES		; Number of retries for SD card detection
	ld (sdInitRetry),a
	
sdiLoop
	call spiInit			; Set SD interface to idle state

	ld b,RESET_CLK_COUNT		; Toggle clk 80 times
	ld a,SPI_IDLE			; Set CS and MOSI high

sdiReset
	out (SPI_PORT),a
	set SD_CLK,a			; Set CLK
	out (SPI_PORT),a
	nop
	res SD_CLK,a			; Clear CLK
	out (SPI_PORT),a
	djnz sdiReset

	ld a,SPI_IDLE			; Now turn CS off - puts SD card into SPI mode
	and SPI_CS1
	out (SPI_PORT),a

	ld hl,spiCMD0
	call sendSPICommand		; Should come back as 01 if card present
	cp 01h
	jr z,sdiReset2			; SD card detected
	ld a,(sdInitRetry)		; No SD card detected so load retry counter
	cp 0			
	jr z,sdiReset1			; No more retries left
	dec a
	ld (sdInitRetry),a		; Update the retry counter
	jr sdiLoop			; and try again
	
sdiReset1
	ld a,1				; Get no card detected error message
	call errorMsg

	scf				; set carry flag on exit
	ret

sdiReset2
	ld hl,spiCMD8
	call sendSPICommand
	cp 01
	jr nz,sdiCmd55			; Skip past if CMD8 not supported (older cards)
	ld b,4				; Dump 4 bytes of CMD8 status

sdiGet5Byte
	call readSPIByte
	djnz sdiGet5Byte

sdiCmd55
	call lDelay
	ld hl,spiCMD55
	call sendSPICommand
	ld hl,spiACMD41
	call sendSPICommand		; Expect to get 00; init'd. If not, init is in
					; progress
	cp 0
	jr z,sdiDone
	jr sdiCmd55			; Try again if not ready. Can take several 
					; cycles

sdiDone					; we are initialised!!
	scf				; clear carry flag on exit
	ccf
	ret

; ----------------------------------------------------------------------------
; writeFile
; Write a file to SD card at the specified slot
;
; Input:	A -- Slot number to write to (0-127)
;		BC -- Size of the block to write
;		DE -- Start address of memory block to write
;		HL -- Pointer to null terminated file name
; Output:	Carry flag set if file write failed, cleared if success
; Destroys:	A, BC, DE, HL
; ----------------------------------------------------------------------------
writeFile:
	push hl
	ld (paramStrPtr),hl		; Save the parameters passed in
	ld (fileStart),de
	ld (fileLength),bc
	ld (currSlot),a

	ld hl,(fileStart)		; Add the start address and ...
	adc hl,bc			; ... length together
	dec hl				; Subtract 1 from the end address
	ld (fileEnd),hl			; and store the end address

	pop hl				; Calculate the current sector for the
					; slot number given
	ld hl,64			; Get first FCB into buffer
	and 0F8h			; Determine the sector offset
	srl a
	srl a
	srl a
	add a,l
	ld (currSector),a

	ld a,(currSlot)			; Remove sector info from slot
	and 07h

	ld (fcbOffset),a
	ld hl,(currSector)
	ld (fcbToUpdate),hl		; where FCB's go, later

	ld hl,0000h			; calculate correct currSector for 
					; the write
	ld a,(currSector)		; selected by selectSlot
	ld b,a				; HL * 128 = page

	sub 64
	cp 0
	jr z,fixAADone
	ld de,1024

fixAA
	add hl,de
	djnz fixAA

fixAADone
	ld a,(fcbOffset)		; calculate offset
	ld b,a
	cp 0
	jr z,fixADone
	ld de,128

fixA
	add hl,de
	djnz fixA

fixADone
	ld de,128			; add final offset
	add hl,de

	ld (currSector),hl
	ld (startSector),hl

	ld hl,(fileStart)		; transfer default into working area
	ld (memPos),hl

	ld hl,0
	ld (numSectors),hl

blockToSD
	ld bc,512
	ld hl,(fileLength)
	or a
	sbc hl,bc
	add hl,bc
	jr nc,mBlk2
	ld b,h
	ld c,l

mBlk2	
	ld de,sdBuff			; RAM > Buff
	ld hl,(memPos)
	ldir

; prep done, now save
	call writeSdSector
	ret c

; next sector calculations
	ld hl,(numSectors)		; count how many written
	inc hl
	ld (numSectors),hl

	ld hl,(fileLength)		; decrease count by length
	ld bc,512
	or a
	sbc hl,bc

	jr z,writeDone			; 0 bytes left
	jp m,writeDone			; we went negative, so done

	ld (fileLength),hl		; size of next block

nextblock
	ld hl,currSector		; next sector
	inc (hl)

	ld hl,(memPos)			; next RAM block
	ld bc,512
	add hl,bc
	ld (memPos),hl
	jr blockToSD

writeDone
	ld hl,(fcbToUpdate)		; get correct sector
	ld (currSector),hl
	call readSdSector

	call calcOffset

	ld hl,(paramStrPtr)		; See if we need to update the filename
	ld a,h
	or l
	jr z,fnDefault			; Use default filename


	push iy
	push iy
	pop de
	ld bc,DESC_SIZE
	ldir
	pop iy

fnDefault
	ld hl,(fileStart)		; update start
	ld (iy+FCB_START_ADDR),l
	ld (iy+FCB_START_ADDR+1),h

; ******************* Need to check this!
	ld hl,(fileEnd)
	ld bc,(fileStart)
	or a
	sbc hl,bc
	inc hl				; +1 for start byte
	ld (iy+FCB_LENGTH),l		; update length
	ld (iy+FCB_LENGTH+1),h		; update length

	xor a				; not expand
	ld (iy+FCB_EXPAND),a

	ld hl,0
	ld (iy+FCB_START_SECT),l	; update start sector MSW
	ld (iy+FCB_START_SECT+1),h	; update start sector MSW
	ld hl,(startSector)
	ld (iy+FCB_START_SECT+2),l	; update start sector LSW
	ld (iy+FCB_START_SECT+3),h	; update start sector LSW

	ld hl,(numSectors)
	ld (iy+FCB_SECT_COUNT),l	; update number of sectors
	ld (iy+FCB_SECT_COUNT+1),h	; update number of sectors

	; push iy				; put in the timestamp if RTC exists
	; ld b,0
	; ld c,FCB_RTC
	; add iy,bc
	; call addTimeStamp
	; pop iy

	call writeSdSector		; save change
	ret c
	call spiInit

	ret

; ----------------------------------------------------------------------------
; readFile
; Reads a file at the specified slot and loads it at the start address
; specified in the file to that RAM address.
;
; Input:	A -- Slot number to read from (0-127)
; Output:	HL -- Contains pointer to error message if read failed
; 		Carry flag set if file read failed, cleared if success
; Destroys:	A, BC, DE, HL
; ----------------------------------------------------------------------------
readFile:
	ld (currSlot),a			; Save the slot number
	call sdInit			; Initialise the SD card
	jp nc,readfCont			; Card detected
	ld a,1
	call errorMsg

	ret

readfCont
	call isFormatted		; SD present and formatted?
	jp nc,readfCont1		; Card formatted
	ld a,2
	call errorMsg

	ret

readfCont1
	ld hl,64			; Determine the FCB sector
	ld a,(currSlot)
	and 0F8h
	srl a
	srl a
	srl a
	add a,l
	ld l,a
	ld (currSector),hl

	call readSdSector

	ld a,(currSlot)			; Remove sector info from slot
	and 07h				; A = old style slot (0-7)
					; currSlot = new style slot (0-127)
					; currSector = FCB sector

	ld (fcbOffset),a
	call calcOffset			; sets up IY register

	ld l,(iy+FCB_START_ADDR)	; Start in memory, FFFF = no file
	ld h,(iy+FCB_START_ADDR+1)	; Start in memory, FFFF = no file

	ld de,0ffffh			; 16-bit CP
	or a
	sbc hl,de
	add hl,de
	jr nz,fValid

	ld b,01				; error if selecting empty slot
	scf
	ret

fValid
	ld (addrStart),hl
	ld (memPos),hl

	ld l,(iy+FCB_LENGTH)		; Memory length
	ld h,(iy+FCB_LENGTH+1)		; Memory length
	ld (memBlockSize),hl

	ld l,(iy+FCB_START_SECT+2)	; start sector
	ld h,(iy+FCB_START_SECT+3)	; start sector
	ld (currSector),hl

	ld l,(iy+FCB_SECT_COUNT)	; now many sectors to load
	ld h,(iy+FCB_SECT_COUNT+1)	; now many sectors to load
	ld (numSectors),hl

; prep done, now load

blockFromSD
	call readSdSector		; get block

	ld bc,512
	ld hl,(memBlockSize)
	or a
	sbc hl,bc
	add hl,bc
	jr nc,mBlk
	ld b,h
	ld c,l

mBlk
	ld de,(memPos)			; copy to memory
	ld hl,sdBuff
	ldir

	ld hl,(numSectors)
	dec hl
	ld (numSectors),hl

	ld a,h				; 0 left to go?
	or l
	jr z,loadDone

	ld hl,(currSector)		; next sector
	inc hl
	ld (currSector),hl

	ld hl,(memBlockSize)		; decrease count by length
	ld bc,512
	or a
	sbc hl,bc
	ld (memBlockSize),hl		; if there's a block theres a transfer....

	ld hl,(memPos)			; next memory location
	ld bc,512
	add hl,bc
	ld (memPos),hl

	jr blockFromSD

loadDone
	call spiInit

	ret

; ----------------------------------------------------------------------------
; deleteFile
; Deletes a file at the specified slot.
;
; Input:	A -- Slot number to be deleted from (0-127)
; Output:	Carry flag set if file delete failed, cleared if success
; Destroys:	A, BC, DE, HL
; ----------------------------------------------------------------------------
deleteFile:
	ld (currSlot),a			; Save the slot number

	call readSlotFCB		; Get the file details for the slot

	push iy				; Copy the default FCB block
	pop de
	ld hl,fcbFormat
	ld bc,fcbFormatLen
	ldir

	call writeSdSector		; Write the sector back to the SD
	
	call spiInit

	ret

; ----------------------------------------------------------------------------
; renameFile
; Renames a file at the specified slot.
;
; Input:	A -- Slot number for file to be renamed from (0-127)
;		HL -- Pointer to ASCII string containing the new filename
; Output:	None
; Destroys:	A, BC, DE, HL, IY
; ----------------------------------------------------------------------------
renameFile:
	push hl
	ld (currSlot),a			; Save the slot number
	call readSlotFCB		; Get the file details for the slot

	push iy				; Update the filename
	pop de
	pop hl
	ld bc,DESC_SIZE
	ldir

	call writeSdSector		; Write the sector back to the SD
	
	call spiInit

	ret

; ----------------------------------------------------------------------------
; selectDisk
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
	cp 0				; Is the disk >= 0?
	jr nc,selectDiskValid
	jr selectDiskInv		; No, then not a valid disk number

selectDiskValid
	cp 8				; Is the disk < 8 (0-7)
	jr c,selectDiskExit
	jr selectDiskInv		; No, then not a valid disk number

selectDiskInv
	ld hl,(diskOffset)		; Load the current disk back into A
	ld a,h

	scf				; Return error
	ret

selectDiskExit
	ld h,a
	ld l,0
	ld (diskOffset),hl		; Update the new disk offset

	scf				; Return success
	ccf
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
	ld e,1				; 1 = don't print a digit

	ld l,a
	ld a,0
	ld h,a

	ld bc,-100
	call daNum1
	ld c,-10
	call daNum1
	ld c,-1

daNum1
	ld a,'0'-1

daNum2
	inc a
	add hl,bc
	jr c,daNum2
	sbc hl,bc

	ld d,a				; backup a
	ld a,e
	or a
	ld a,d				; restore it in case
	jr z,daProut			; if E flag 0, all ok, print any value

	;cp '0'				; no test if <>0
	;ret z				; if a 0, do nothing (leading zero)

	ld e,0				; clear flag & print it

daProut
	ld (ix),a
	inc ix
	ld a,' '
	ld (ix),a
	ret

; -----------------------------------------------------------------------------
; decimal
; converts HL to decimal
; Input:	HL -- Number to convert
;		IX -- Memory location to store result
; Output:	None
; Destroys:	A, BC, DE, HL, IX
; -----------------------------------------------------------------------------
decimal:
	ld e,1				; 1 = don't print a digit

	ld bc,-10000
	call Num1
	ld bc,-1000
	call Num1
	ld bc,-100
	call Num1
	ld c,-10
	call Num1
	ld c,-1

Num1
	ld a,'0'-1

Num2
	inc a
	add hl,bc
	jr c,Num2
	sbc hl,bc

	ld d,a				; backup a
	ld a,e
	or a
	ld a,d				; restore it in case
	jr z,prout			; if E flag 0, all ok, print any value

	cp '0'				; no test if <>0
	ret z				; if a 0, do nothing (leading zero)

	ld e,0				; clear flag & print it

prout
	ld (ix),a
	inc ix

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
	push bc
	push de

	ld de,sdBuff+05h
	ld b,8

nfLoop
	ld a,(byteBuff)
	push af
	push bc
	call aToDecString
	pop bc
	pop af
	inc a
	ld (byteBuff),a

	ld hl,64-3
	add hl,de
	ex de,hl

	djnz nfLoop

	pop de
	pop bc

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
	ld a,(sdCIDInit)		; Check to see if we have already got
					; the CID info
	xor a
	jr z,getCID1			; we haven't so go get the CID info

	ld hl,sdCIDRegister		; Return pointer to the CID register
					; in hl
	ret

getCID1
	ld hl,spiCMD10
	call sendSPICommand		; Check command worked (=0)
	cp 0
	ret nz

	ld bc,16			; How many bytes of data we need to get
	call readSPIBlock

	ld b,15
	ld de,sdCIDRegister
	ld hl,sdBuff

getCID2
	ld a,(hl)			; Copy CID register from buffer to var
	ld (de),a 
	inc de
	inc hl
	djnz getCID2
	
	ld hl,sdCIDRegister		; Return pointer to the CID register
					; in hl
	
	ld a,1				; Record we have got the CID info.
	ld (sdCIDInit),a

	call spiInit

	ret

; ----------------------------------------------------------------------------
; getFileDir
; Get the file directory information for a file
; A = Slot number
; Returns HL = File dir contents
; ----------------------------------------------------------------------------
getFileDir:
	ld (fcbOffset),a		; Get the FCB associated with this slot
	call calcOffset

	push iy
	pop hl
	ld de,fcbDescription
	ld bc,FCB_END + 1
	ldir

	ld hl,fcbDescription		; Get the filename from the FCB
	ld de,dirStrBuff + DIR_DESC	; and store it in the dir buffer
	ld bc,DESC_SIZE
	ldir

	ld hl,(fcbStartAddress)		; Get the start address

	ld de,0ffffh			; If it is FFFFH then this is an empty
	or a				; slot
	sbc hl,de
	add hl,de
	jp z,gfNotFound			; This is an empty slot

	ld hl,(fcbStartAddress)		; Get the start address
	ld de,dirStrBuff + DIR_START
	call hlToString

	ld a,'H'			; Append the trailing hex symbol
	ld (de),a

	ld hl,(fcbLength)		; Get the file length
	ld de,dirStrBuff + DIR_LENGTH
	call hlToString

	ld a,'H'			; Append the trailing hex symbol
	ld (de),a

	ld hl,dirStrBuff + DIR_END	; Append a null the end of the buffer
	ld a,0
	ld (hl),a

	scf				; clear carry flag, file found
	ccf

gfExit
	ld hl,dirStrBuff		; Return the directory entry

	ret

gfNotFound
	scf				; Set carry flag - slot is empty
	jr gfExit

; ----------------------------------------------------------------------------
; getFileExt
; Returns 3 character file extension
;
; Input:	A -- File extension code
; Output:	HL -- Pointer to string containing file extension
;		      Returns 3 digit file extension if no mapping exists
; Destroys:	A, BC, HL, IX
; ----------------------------------------------------------------------------
getFileExt:
	push af
	ld a,(extMax)
	ld b,a
	pop af
	cp b
	jr c,extValid			; Check for a valid file ext code

	ld ix,decimalBuff
	call decimalA

	ld hl,decimalBuff

	ret

extValid
	ld hl,extTable			; Get the base to the file ext table
	sla a				; multiple code by 2 for correct index
	ld b,0
	ld c,a
	adc hl,bc			; Calculate the offset for the message

	push hl
	pop ix
	ld h,(ix+1)			; Update HL with pointer to message
	ld l,(ix+0)

	ret

; ----------------------------------------------------------------------------
; getMDT
; Read the cards manufacturing date and return a pointer to a 7 character,
; null terminated string containing the manufacturing date as ASCII text in
; the form of mm/yyyy.
;
; Input:	None.
; Output:	HL -- Pointer to null terminated manufacturing date string.
; Destroys:	A, BC, DE, HL
; ----------------------------------------------------------------------------
getMDT:
	call getCID			; Get the SD card hw info

	ld a,(sdcidMDT+1)
	and 0fh
	cp 0ah
	jr c,gm1
	add a,06h

gm1
	ld de,paramStrBuff
	call aToString

	ld a,'/'
	ld (de),a

	ld a,(sdcidMDT)
	ld h,a
	ld a,(sdcidMDT + 1)
	ld l,a
	rl h
	rl h
	rl h
	rl h
	ld a,h
	and 0f0h
	ld b,a
	rr l
	rr l
	rr l
	rr l
	ld a,l
	and 0fh
	add a,b

	ld hl,2000
	ld b,0
	ld c,a
	add hl,bc
	
	ld ix,numStrBuff
	call decimal

	ld hl,numStrBuff
	ld de,paramStrBuff + 3
	ld bc,4
	ldir

	ld hl,paramStrBuff + 7
	ld a,0				; Add terminating null
	ld (hl),a

	ld hl,paramStrBuff

	ret				; and return.

; ----------------------------------------------------------------------------
; getMID
; Returns the Manufacturer ID for the SD card as an ASCII 2 digit number
;
; Input:	None
; Output:	HL -- Pointer to MID string 
; Destroys:	A, BC, DE, HL
; ----------------------------------------------------------------------------
getMID:
	call getCID

	ld a,(sdcidMID)
	
	ld de,numStrBuff
	call aToString

	ld a,0
	ld (de),a
	ld hl,numStrBuff

	ret

; ----------------------------------------------------------------------------
; getOID
; Returns the OEM ID for the SD card as an ASCII 4 digit number
;
; Input:	None
; Output:	HL -- Pointer to OID string 
; Destroys:	A, BC, DE, HL
; ----------------------------------------------------------------------------
getOID:
	call getCID

	ld hl,(sdcidOID)
	ld de,numStrBuff
	call hlToString

	ld a,0
	ld (de),a
	ld hl,numStrBuff

	ret

; ----------------------------------------------------------------------------
; getPRN
; Read the cards revision number and return a pointer to a 5 character, null
; terminated string containing the Part Revision Number as ASCII text.
;
; Input:	None.
; Output:	HL -- Pointer to null terminated part revision number string.
; Destroys:	A, BC, DE, HL
; ----------------------------------------------------------------------------
getPRN:
	call getCID			; Get the SD card hw info

	ld a,(sdcidPRN)			; Convert major number
	and 0f0h
	rr	a
	rr	a
	rr	a
	rr	a
	ld de,paramStrBuff
	call aToString

	ld a,'.'			; Add a decimal point
	ld (de),a

	ld a,(sdcidPRN)			; Convert minor number
	and 0fh
	ld de,paramStrBuff + 3
	call aToString

	ld a,0				; Add terminating null
	ld (de),a

	ld hl,paramStrBuff

	ret				; and return.

; ----------------------------------------------------------------------------
; getPSN
; Read the cards serial number and return a pointer to an 8 character, null
; terminated string containing the Part Serial Number as ASCII text.
;
; Input:	None.
; Output:	HL -- Pointer to null terminated part serial number string.
; Destroys:	A, HL, IX, IY
; ----------------------------------------------------------------------------
getPSN:
	call getCID			; Get the SD card hw info

	ld hl,(sdcidPSN)
	ld de,paramStrBuff
	call hlToString
	
	ld hl,(sdcidPSN + 2)
	call hlToString
	
	ld a,0				; Add terminating null
	ld (de),a

	ld hl,paramStrBuff

	ret				; and return.

; ----------------------------------------------------------------------------
; getVolLabel
; Gets the current disks volume label.
;
; Input:	None.
; Output:	HL -- Pointer to null terminated disk volume label.
; Destroys:	A, HL, IX, IY
; ----------------------------------------------------------------------------
getVolLabel:
	ld bc,00h
	ld (currSector),bc		; Save the sector number
	call readSdSector		; Go read the sector

	ld hl,sdBuff+6			; Start of volume label
	ld de,paramStrBuff
	ld bc,20
	ldir

	ld a,0				; Add terminating null
	ld (de),a

	ld hl,paramStrBuff

	ret				; and return.

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
	call spiInit

	ld hl,0				; fetch sector
	ld (currSector),hl
	call readSdSector

	call spiInit

	ld hl,sdFormat			; "MEMSDS"
	ld de,sdBuff
	ld b,6

ifCp
	ld a,(de)			; Check to see if the first 6 bytes of
	ld c,a				; the MBR contains "MEMSDS"
	ld a,(hl)
	cp c
	jr nz,ifCpFail
	inc de
	inc hl
	djnz ifCp
	
	scf
	ccf				; Successful so clear carry flag 
	ret

ifCpFail
	ld a,3				; Card not formatted error
	call errorMsg

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
	call getCardType

	cp 0c0h
	jr z,isSDHCOK

	ld a,2				; Get no card detected error message
	call errorMsg

	scf				; Not an SDHC card so return carry set
	ret

isSDHCOK
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
lDelay:
	push af
	push de

	ld de,0c000h

lInner
	dec de
	ld a,d
	or e
	jr nz, lInner

	pop de
	pop af

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
	ld hl,spiCMD17			; load up our variable
	ld de,spiCMD17var
	ld bc,6
	ldir

	ld bc,(diskOffset)
	ld (spiCMD17var+1),bc		; put our sector # MSW here

	ld hl,(currSector)
	ld a,h				; swap byte order
	ld h,l
	ld l,a
	ld (spiCMD17var+3),hl		; put our sector # LSW here

	ld hl,spiCMD17var		; write command
	call sendSPICommand		; check command worked (=0)
	cp 0
	jr z,rssCont
	scf				; Error so set carry flag
	jr rssEnd

rssCont
	ld bc,514
	call readSPIBlock
	scf
	ccf				; No error so clear carry flag

rssEnd
	ret

; ----------------------------------------------------------------------------
; readSlotFCB
; Reads the FCB for the slot and returns the ASCII directory entry
; Assumes the SD card has already been initialised and is valid
;
; Input:	A -- Slot number (0-127).
; Output:	HL -- Pointer to ASCII version of slot directory entry
;		IY -- Pointer to FCB buffer
; Destroys:	A, BC, DE, HL
; ----------------------------------------------------------------------------
readSlotFCB:
	ld hl,64			; Get first FCB into buffer
	ld (currSlot),a			; Save the slot number
	and 0F8h			; Determine the sector offset
	srl a
	srl a
	srl a
	add a,l
	ld (currSector),a

	ld a,(currSlot)			; Remove sector info from slot
	and 07h
	ld (slotOffset),a

	call readSdSector		; Get the FCB sector for the slot
	ret c				; Error has occured so bail out

	xor a

	ld hl,dirStrBuff		; Clear the directory buffer
	ld a,' '
	ld b,DIR_END

rsLoop
	ld (hl),a
	inc hl
	djnz rsLoop

	ld a,(currSlot)			; Save slot number to dir buffer
	ld l,a
	ld h,0
	ld ix,decimalBuff
	call decimalA
	
	ld hl,decimalBuff
	ld de,dirStrBuff + DIR_SLOT

rsLoop1
	ld a,(hl)
	ld (de),a
	cp ' '
	jr z,rsLoop2
	inc de
	inc hl
	jr rsLoop1
	
rsLoop2
	ld a,(slotOffset)		; Restore the slot offset in the sector 
	call getFileDir			; Get the rest of the dir contents

	call spiInit

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
	ld hl,sdBuff

waitToken
	call spiRdb
	cp 0ffh				; ffh == not ready yet
	jr z,waitToken
; todo = 0000xxxx = error token; handle this
; todo, add timeout
	cp 0feh				; feh == start token. We discard this.
	jr nz,waitToken

blockLoopR				; Load in all the bytes
	call spiRdb
	ld (hl),a
	inc hl
	dec bc
	ld a,b
	or c
	jr nz, blockLoopR

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
	push bc
	push de
	ld b,32				; Wait up to 32 tries, but should
					; need 1-2

readLoop
	call spiRdb			; Get value in A
	cp 0ffh
	jr nz,result
	djnz readLoop

result
	pop de
	pop bc

	ret

; ----------------------------------------------------------------------------
; sendSPICommand
; 
; Input:	HL -- 6 byte command
; Output:	A -- Response code
; Destroys:	A
; ----------------------------------------------------------------------------
sendSPICommand:
	push bc
	push de
	push hl
	ld b,6

sendSPIByte
	ld c,(hl)
	call spiWrb
	inc hl
	djnz sendSPIByte
	call readSPIByte
	pop hl
	pop de
	pop bc

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
	ld ix,sdBuff			; get CRC16
	ld de,512
	call crc16
	ld a,h
	ld (sdBuff+512),a		; and save CRC16
	ld a,l
	ld (sdBuff+513),a

	ld hl,spiCMD24			; load up our variable
	ld de,spiCMD24var
	ld bc,6
	ldir

	ld bc,(diskOffset)
	ld (spiCMD24var+1),bc		; put our sector # MSW here

	ld hl,(currSector)
	ld a,h				; swap byte order
	ld h,l
	ld l,a
	ld (spiCMD24var+3),hl		; put our sector # LSW here

	ld hl,spiCMD24var		; write command
	call sendSPICommand		; check command worked (=0)
	cp 0
	jp z,writeSdBlock		; No error
	call spiInit

	scf				; Set carry flag as error and return
	ret

writeSdBlock
	call writeSPIBlock
	cp 05h				; check write worked
	jp z,writeSdBlockOK		; No error
	scf				; Set carry flag as error
	ret

writeSdBlockOK
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
	push bc
	push de
	ld hl,sdBuff
	ld de,514			; #bytes to write

sendToken
	ld c,0feh			; send start block token
	call spiWrb

blockLoopW				; load in all the bytes incl. CRC16
	ld c,(hl)
	call spiWrb
	inc hl
	dec de
	ld a,d
	or e
	jr nz, blockLoopW

	call readSPIByte		; get the write response token
	ld c,a				; save result into C

waitDone
	call spiRdb			; 00 = busy - wait for card to finish
	cp 00h
	jr z,waitDone

	ld a,c				; restore result to A register
	and 1fh				; return code 05 = success
	pop de
	pop bc

	ret

; ----------------------------------------------------------------------------
; Error Handling Routines
; ----------------------------------------------------------------------------

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
	push af
	ld a,(errMax)
	ld b,a
	pop af
	cp b
	jr c,errorValid			; Check for a valid error code
	ld hl,errInvalidCode		; No, then report invalid code

	scf				; Return error in carry flag
	ret

errorValid
	ld hl,errTable			; Get the base to the error table
	sla a				; multiple code by 2 for correct index
	ld b,0
	ld c,a
	adc hl,bc			; Calculate the offset for the message

	push hl
	pop ix
	ld h,(ix+1)			; Update HL with pointer to message
	ld l,(ix+0)

	scf				; Return success
	ccf
	ret

; ----------------------------------------------------------------------------
; SPI Routines
; ----------------------------------------------------------------------------

; SPI port bits out
;
; bit 0 - MOSI
; bit 1 - CLK
; bit 2 - CS1
;
; SPI port bits in
;
; bit 6 - Card Detect (not used)
; bit 7 - MISO
;
; ----------------------------------------------------------------------------
; SPI initialization code
; call once at start of code, and again to return SPI to idle
;
; idle state == xxxx x101  ===  CS high, CLK low, MOSI high
; ----------------------------------------------------------------------------
spiInit:
	push af
	ld a,SPI_IDLE	; Set idle state
	out (SPI_PORT),a
	pop af
	ret

; ----------------------------------------------------------------------------
; Routine to transmit one byte to the SPI bus
;
; C = data byte to write
;
; no results returned, no registers modified
; ----------------------------------------------------------------------------
spiWrb:
	push af
	push bc
	ld b,8			; 8 BITS

wbit
	ld a,SPI_IDLE		; starting point
	and SPI_CS1		; add in the CS pin
	bit 7,c
	jr nz, no
	res 0,a

no
	out (SPI_PORT),a		; set data bit
;	set 1,a			; set CLK
	or 02h
	out (SPI_PORT),a
	nop
;	res 1,a			; clear CLK
	and 0fdh
	out (SPI_PORT),a
	rlc c			; next bit
	djnz wbit

	pop bc
	pop af
	ret

; ----------------------------------------------------------------------------
; Routine to read one byte from the SPI bus
;
; returns result in A
; no other registers modified
; ----------------------------------------------------------------------------
spiRdb:
	push bc
	push de

	ld e,0		; result
	ld b,8		; 8 bits

rbit
	ld a,SPI_IDLE
	and SPI_CS1	; CS bit

	out (SPI_PORT),a	; set CS
	nop

	or 02h
;	set 1,a		; set CLK
	out (SPI_PORT),a

	ld c,a		; backup a
	in a,(SPI_PORT)	; bit d7
	rla		; bit 7 -> carry
	rl e		; carry -> E bit 0
	ld a,c		; restore a

	and 0fdh
;	res 1,a		; clear CLK
	out (SPI_PORT),a

	djnz rbit

	ld a,e

	pop de
	pop bc
	ret

; ----------------------------------------------------------------------------
; Constants
; ----------------------------------------------------------------------------
RESET_CLK_COUNT	.equ 80
SD_INIT_RETRIES	.equ 10
SD_CLK		.equ 1
DESC_SIZE	.equ 20

; FCB offsets
FCB_START_ADDR	.equ 20
FCB_LENGTH	.equ 22
FCB_EXPAND	.equ 24
FCB_RTC		.equ 25
FCB_START_SECT	.equ 32
FCB_SECT_COUNT	.equ 36
FCB_TYPE	.equ 38
FCB_END		.equ 39

; Date/time offsets
OFS_SECOND	.equ 0
OFS_MINUTE	.equ 1
OFS_HOUR	.equ 2
OFS_DATE	.equ 3
OFS_MONTH	.equ 4
OFS_DAY		.equ 5
OFS_YEAR	.equ 6

; Directory string offsets
DIR_SLOT	.equ 0
DIR_DESC	.equ 5
DIR_START	.equ 25
DIR_LENGTH	.equ 31
DIR_END		.equ 38

; SPI
SPI_PORT	.equ 0fdh	; IO port our SPI "controller" lives on
SPI_IDLE	.equ 05h	; Idle state
SPI_CS1		.equ 0fbh	; CS line


; ----------------------------------------------------------------------------
; Data and variables
; ----------------------------------------------------------------------------

; ---------------------------- Strings
sdFormat	.db "MEMSDS"			; Signature
sdVolLabel	.db "Mem SDS Disk        "	; Volume Label
		.db 00,00,01,01,01,01,00	; 1am 1/1/2023
		.db 16				; directory Sectors
sdFormatLen	.equ $-sdFormat

fcbFormat	.db "SLOT 000            "	; name
		.dw 0ffffh			; start, ffff = no file
		.dw 0000h			; length
		.db 00,00,01,01,01,01,00	; 1am 1/1/2023
		.dw 0000h			; start sector # (32 bits)
		.dw 0000h
		.dw 0000h			; length in sectors
fcbFormatLen	.equ $-fcbFormat
fcbFormatSpc	.equ 64-fcbFormatLen

; ---------------------------- Error codes
; Maximum of 256 error codes. String not to exceed 20 characters

errMax		.db 4				; Number of error messages
errTable	.dw err00			; Pointer to error message 0...
		.dw err01
		.dw err02
		.dw err03

err00		.db "Fatal error",0		; Error message 0...
err01		.db "No card detected",0
err02		.db "Not an SDHC card",0
err03		.db "Disk not formatted",0

errInvalidCode	.db "Invalid error code",0

; ---------------------------- File extension codes
; Maximum of 255 file extension codes. String not to exceed 3 characters

extMax		.db 5				; Number of file extensions
extTable	.dw ext00			; Pointer to file extension 0...
		.dw ext01
		.dw ext02
		.dw ext03
		.dw ext04

ext00		.db "BIN"			; File extension 0...
ext01		.db "TXT"
ext02		.db "DAT"
ext03		.db "BAS"
ext04		.db "ASM"

; ---------------------------- SPI commands
spiCMD0		.db 40h,0,0,0,0,95h	; Reset			R1
spiCMD8		.db 48h,0,0,1,0aah,87h	; Send_if_cond		R7
spiCMD9		.db 49h,0,0,1,0aah,87h	; Send_CSD		R1
spiCMD10	.db 4ah,0,0,0,0,1h	; Send_CID		R1
spiCMD16	.db 50h,0,0,2,0,1h	; Set sector size	R1
spiCMD17	.db 51h,0,0,0,0,1h	; Read single block	R1
spiCMD24	.db 58h,0,0,0,0,1h	; Write single block	R1
spiCMD55	.db 77h,0,0,0,0,1h	; APP_CMD		R1
spiCMD58	.db 7ah,0,0,0,0,1h	; READ_OCR		R3
spiACMD41	.db 69h,40h,0,0,0,1h	; Send_OP_COND		R1

SD_API_END	.equ $

		.end