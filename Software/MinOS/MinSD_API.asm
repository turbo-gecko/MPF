; ----------------------------------------------------------------------------
; MinSD_API.asm
; Version: 0.1
; Last updated: 27/07/2024
;
; Minimal SD card API for ROM usage. Will only support slot read to memory
; ----------------------------------------------------------------------------

; In any app that calls these api's, make sure that SD_DATA_END is set to a 
; valid RAM address. This can be done by using
;
; API_DATA_START	.equ $
;
; at the end of the data segment of the calling app.

;API_DATA_START	.equ 1000h	; Uncomment if testing file dependencies when
				; building standalone. This is normally left
				; commented out.
; ----------------------------------------------------------------------------
; INCLUDE libraries
; ----------------------------------------------------------------------------

#include	"spi_library.asm"

; ============================================================================
; Api calls
; ============================================================================
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
	
sdInitLoop
	call spiInit			; Set SD interface to idle state

	ld b,RESET_CLK_COUNT		; Toggle clk 80 times
	ld a,SPI_IDLE			; Set CS and MOSI high

sdReset
	out (SPI_PORT),a
	set SD_CLK,a			; Set CLK
	out (SPI_PORT),a
	nop
	res SD_CLK,a			; Clear CLK
	out (SPI_PORT),a
	djnz sdReset

	ld a,SPI_IDLE			; Now turn CS off - puts SD card into SPI mode
	and SPI_CS1
	out (SPI_PORT),a

	ld hl,spiCMD0
	call sendSPICommand		; Should come back as 01 if card present
	cp 01h
	jr z,sdReset2			; SD card detected
	ld a,(sdInitRetry)		; No SD card detected so load retry counter
	cp 0			
	jr z,sdReset1			; No more retries left
	dec a
	ld (sdInitRetry),a		; Update the retry counter
	jr sdInitLoop			; and try again
	
sdReset1
	ld a,ERR_NO_CARD		; Get no card detected error message
;	call errorMsg

	scf				; set carry flag on exit
	ret

sdReset2

; ----
; CMD8 - get status bits. CMD8 is in version 2.0+, of the SD spec.
; only SDHC cards support CMD8
; ----

	ld hl,spiCMD8
	call sendSPICommand
	cp 01
	jr nz,cmd8Done			; Skip past if CMD8 not supported (older cards)

cmd8OK
	ld b,4				; Dump 4 bytes of CMD8 status

get5Byte
	call readSPIByte
	djnz get5Byte

cmd8Done

;------
; ACMD41 - setup card state (needs CMD55 sent first to put it into ACMD mode)
;------
sendCMD55
	call lDelay
	ld hl,spiCMD55
	call sendSPICommand
	ld hl,spiACMD41
	call sendSPICommand		; Expect to get 00; init'd. If not, init is in
					; progress
	cp 0
	jr z, initDone
	jr sendCMD55			; Try again if not ready. Can take several 
					; cycles

initDone				; we are initialised!!
	scf				; clear carry flag on exit
	ccf
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
; readSlotFCB#5
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
; readFile#7
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
	ld a,ERR_NO_CARD

	ret

readfCont
	call isFormatted		; SD present and formatted?
	jp nc,readfCont1		; Card formatted
	ld a,ERR_NO_FORMAT

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

	ld l,(iy+FCB_START_ADDR)	; TEC start in memory, FFFF = no file
	ld h,(iy+FCB_START_ADDR+1)	; TEC start in memory, FFFF = no file

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

	ld l,(iy+FCB_LENGTH)		; TEC memory length
	ld h,(iy+FCB_LENGTH+1)		; TEC memory length
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
	ld de,(memPos)			; copy to TEC memory
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

	ld hl,(memPos)			; next TEC memory location
	ld bc,512
	add hl,bc
	ld (memPos),hl

	jr blockFromSD

loadDone
	call spiInit

	ret

; ----------------------------------------------------------------------------
; selectDisk#10
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
	push af
	push bc
	push de

	ld a,(fcbOffset)
	ld iy,sdBuff
	cp 0
	jr z,cFil
	ld b,a
	ld de,64

cOffset
	add iy,de
	djnz cOffset

cFil
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

crc16_read
	ld a,h
	xor (ix+0)
        ld h,a
        inc ix
        ld b,c

crc16_shift
        add hl,hl
        jr nc,crc16_noxor
        ld a,h
        xor 010h
        ld h,a
        ld a,l
    	xor 021h
        ld l,a

crc16_noxor
        djnz crc16_shift
        dec de
        ld a,d
        or e
        jr nz,crc16_read

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

	ld hl,sdFormat			; "TEC-1G"
	ld de,sdBuff
	ld b,6

ifCp	ld a,(de)			; Check to see if the first 6 bytes of
	ld c,a				; the MBR contains "TEC-1G"
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
	ld a,ERR_NO_FORMAT		; Card not formatted error

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

	ld a,ERR_NO_SDHC		; Get no card detected error message

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
lDelay:	push af
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

;#include mon3_includes.asm

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

ERR_NO_CARD	.equ 1
ERR_NO_SDHC	.equ 2
ERR_NO_FORMAT	.equ 3

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