; ----------------------------------------------------------------------------
; MinSD.asm
; Version: 1.1
; Last updated: 31/07/2024
;
; Minimal SD Reader for the MPF-1 trainer.
; This is a cut down version of MinOS with just enough code to load a memory
; image from a slot into memory.
; The code fits in an EPROM to enable it to bootstrap MinOS or any other
; program as required.
;
; Requires:
;	- Acia serial board such as the SC-139 from Small Computer Central
;	- 32K RAM/FRAM from 8000H to FFFFH
;
; ----------------------------------------------------------------------------
; Recommended memory usage:
; - Program code:
;	2400h for general ROM usage
;	8000h for testing/RAM usage
; - Program variables at f000h
; ----------------------------------------------------------------------------

; ----------------------------
; Constants
; ----------------------------

; MPF-1 API Calls
_HEX7		.equ	0689h		; Convert a hex digit to 7 seg display format
_HEX7SG		.equ	0678h		; Convert 2 hex digits to 7 seg display format
_RAMCHECK	.equ	05f6h		; Check if the given address is in RAM
_SCAN		.equ	05feh		; Scan keyboard and display until a new key-in
_SCAN1		.equ	0624h		; Scan keyboard and display one cycle
_TONE		.equ	05e4h		; Generate sound
_TONE1K		.equ	05deh		; Generate sound at 1kHz
_TONE2K		.equ	05e2h		; Generate sound at 2kHz

; Misc
BEEP_LENGTH	.equ	80h

; ----------------------------------------------------------------------------

#define		ROM_LOAD		; Used when loading the program
					; into a ROM
#ifdef ROM_LOAD
		.org 2400h		; ROM load
#else
		.org 8000h		; RAM load
#endif

	call spiInit

	ld a,0				; Select disk 0
	call selectDisk

	call doCmdLoad			; Load the memory image

	ld de,(addrStart)		; Get the start address
	ld hl,dispBuff			; Set up the s7 display buffer

	ld (hl),a			; Blank last 2 digits
	inc hl
	ld (hl),a
	inc hl

	ld a,e
	call _HEX7SG			; Convert the first digit
	ld a,d
	call _HEX7SG			; Convert the second digit
	ld a,0				; Space character

	call beep			; Confirm load

	ld ix,dispBuff
	call _SCAN			; Display load address

	rst 00h				; Exit the program

; ============================================================================
; Include files
; ============================================================================
#include "MinSD_API.asm"

; ============================================================================
; App functions
; ============================================================================

; ----------------------------------------------------------------------------
; aToNibble
; Converts A to ASCII nibble
;
; Input:	A -- Number to convert
; Output:	A -- ASCII char equivalent
; Destroys:	None
; ----------------------------------------------------------------------------
aToNibble:	
	and	0fh		; Just in case...
	add	a,'0'		; If we have a digit we are done here.
	cp	'9' + 1		; Is the result > 9?
	jr	c, aToNibble_1
	add	a,'A'-'0'-$a	; Take care of A-F

aToNibble_1

	ret

; ----------------------------------------------------------------------------
; beep
; Sends a beep tone to the speaker
;
; Input:	None
; Output:	Beep tone
; Destroys:	A, BC, DE, HL
; ----------------------------------------------------------------------------
beep:
	ld hl,BEEP_LENGTH
	call _TONE1K

	ret

; ----------------------------------------------------------------------------
; checkSD
; Checks to see if we have a valid SD card
;
; Input:	None
; Output:	Carry flag set on error, cleared on success
; Destroys:	None
; ----------------------------------------------------------------------------
checkSD:
	call sdInit			; Initialise the SD card
	jr nc,checkSDOK
	call sdErrMsg			; Display error message

	scf
	ret				; Return error

checkSDOK
	scf
	ccf
	ret				; Return success

; ----------------------------------------------------------------------------
; checkSDHC
; Checks to see if we have an SDHC card
;
; Input:	None
; Output:	Carry flag set on error, cleared on success
; Destroys:	None
; ----------------------------------------------------------------------------
checkSDHC:
	call checkSD			; Initialise and check for an SD card
	jr nc,checkSDHCOK1

	scf
	ret				; Return error

checkSDHCOK1
	call isSDHC			; Check for an SDHC card
	jr nc,checkSDHCOK2
	call sdErrMsg			; Display error message if not

	scf
	ret				; Return error

checkSDHCOK2
	scf
	ccf
	ret				; Return success

; ----------------------------------------------------------------------------
; doCmdLoad
; Loads a file from the SD card and copies the file contents to RAM.
;
; Input:	None
; Output:	None
; Destroys:	A, BC, DE, HL, IY
; ----------------------------------------------------------------------------
doCmdLoad:
	call checkSDHC			; Check that it is an SDHC card
	ret c

	call validateFormat		; SD present and formatted?
	ret c

	call selectSlot			; Get slot number
	jp c,dclBadParamQuit		; Bail out if invalid slot number

	push af
	ld a,c				; Update slot number
	ld (slotNumber),a
	pop af

	ld (fcbOffset),a		; Calculate offset in the FCB
	call calcOffset			; sets up IY register

	ld l,(iy+FCB_START_ADDR)	; TEC start in memory, FFFF = no file
	ld h,(iy+FCB_START_ADDR+1)	; TEC start in memory, FFFF = no file

	ld de,0ffffh			; 16-bit CP
	or a
	sbc hl,de
	add hl,de
	jr nz,lfValid			; Continue if valid load address

	call beep			; Long error beeps
	call beep
	call beep
	call beep
	call beep

	ld ix,s7EmptyMsg		; Setup empty message
	call _SCAN			; Loop until key is pressed

	rst 00h

	scf
	ccf
	ret

lfValid
	ld a,(slotNumber)		; Go read the file and transfer to RAM
	call readFile

	scf
	ccf
	ret

dclBadParamQuit
	call beep			; Long error beeps
	call beep
	call beep
	call beep
	call beep

	scf
	ret				; ...and quit

; ----------------------------------------------------------------------------
; hlToString
; Converts HL to ASCII string
;
; Input:	HL -- Number to convert
;		DE -- Pointer to destination string
; Output:	DE -- Pointer to byte after the string
; Destroys:	A
; ----------------------------------------------------------------------------
hlToString:
	ld a,h				; Get the high order byte
	and 0f0h			; Mask off high order nibble
	sra a				; Move to the lower nibble
	sra a
	sra a
	sra a
	call aToNibble			; Convert to ASCII
	ld (de),a			; Update the string
	inc de

	ld a,h				; Get the high order byte
	and 0fh				; Mask off low order nibble
	call aToNibble			; Convert to ASCII
	ld (de),a			; Update the string
	inc de

	ld a,l				; Get the low order byte
	and 0f0h			; Mask off high order nibble
	sra a				; Move to the lower nibble
	sra a
	sra a
	sra a
	call aToNibble			; Convert to ASCII
	ld (de),a			; Update the string
	inc de

	ld a,l				; Get the low order byte
	and 0fh				; Mask off low order nibble
	call aToNibble			; Convert to ASCII
	ld (de),a			; Update the string
	inc de

	ret

; ----------------------------------------------------------------------------
; Error Handling Routines
; ----------------------------------------------------------------------------
sdErrMsg:
	push af
	call spiInit
	pop af

	call _HEX7
	ld ix,s7ErrorMsg		; setup error message
	ld (ix),a			; Save error number
	call _SCAN			; Loop until key is pressed

	rst 00h

; ----------------------------------------------------------------------------
; selectSlot
; Prompts user for a valid slot number between 0 and 127.
; 
; Input:	None
; Output:	A -- Old style slot number (0-7) or 0FFH = cancel
;		BC -- Slot number (0-127)
; 		Carry flag set if no card detected or invalid number
; Destroys:	A, BC, HL
; ----------------------------------------------------------------------------
selectSlot:
	ld ix,s7LoadMsg			; setup load message

ssDisp
	call _SCAN			; Loop until 0-9 is pressed
	cp 0ah
	jr nc,ssDisp

	ld c,a

	push bc
	ld a,c				; Validate slot number
	cp 128				; Check if greater than 127
	jr c,ssCont2			; No, then continue
	; ld hl,badParamMsg		; Yes, then tell the user and abort
	; call acTxLine
	ld a,0ffh
	pop bc

	scf				; Set carry flag as an error state
	ret
	
ssCont2
	ld hl,64			; Get first FCB into buffer
	and 0F8h			; Determine the sector offset
	srl a
	srl a
	srl a
	add a,l
	ld (currSector),a

	call readSdSector		; Read the slot's sector into the buffer
	call spiInit

	pop bc
	ld a,c				; Fix A to old style slot number
	and 07h

	ret

; ----------------------------------------------------------------------------
; validateFormat
; Checks to see if SD card is formatted by finding MBR signature
;
; Input:	None
; Output:	Carry flag set if not a valid MBR, clear if valid
; Destroys:	HL
; ----------------------------------------------------------------------------
validateFormat:
	call isFormatted		; Is the SD card formatted?
	jr nc,vfOK
	call sdErrMsg			; Display error message

	scf
	ret				; Return error

vfOK
	scf
	ccf
	ret				; Return success

; ----------------------------------------------------------------------------
; Program data
; ----------------------------------------------------------------------------

s7EmptyMsg	.db 00h			; "Empty "
		.db 0b6h
		.db 87h
		.db 1fh
		.db 2bh
		.db 8fh

s7ErrorMsg	.db 00h			; "Error "
		.db 03h
		.db 0a3h
		.db 03h
		.db 03h
		.db 8fh

s7LoadMsg	.db 23h			; "LoAd-n"
		.db 02h
		.db 0b3h
		.db 03fh
		.db 0a3h
		.db 85h

; ----------------------------------------------------------------------------
; Program variables
; ----------------------------------------------------------------------------
		.org 0fd00H

sdBuff		.block 512+2		; 512b + CRC16

addrStart:	.block 2
byteBuff	.block 5
currSector	.block 2
currSlot	.block 1
decimalBuff	.block 7
dirStrBuff	.block DIR_END + 1	
diskOffset	.block 2
dispBuff	.block 6
fcbDescription	.block 20
fcbLength	.block 2
fcbOffset	.block 1
fcbStartAddress .block 2
memBlockSize:	.block 2
memPos:		.block 2
numSectors:	.block 2
paramStrBuff	.block 21		; 20 char + null paramater string 
					; buffer
sdCIDInit	.block 1		; if 0, the CID info of the SD card
					; has not been retrieved, or a new
					; retrieval is requested.
sdInitRetry	.block 1		; Keeps track of init retry counter
slotNumber	.block 2
slotOffset	.block 1
spiCMD17var	.block 6
spiCMD24var	.block 6

; ---------------------------- SD CID register
sdCIDRegister
sdcidMID	.block 1		; Manufacturer ID
sdcidOID	.block 2		; OEM/Application ID
sdcidPNM	.block 5		; Product name
sdcidPRN	.block 1		; Product revision
sdcidPSN	.block 4		; Product serial number
sdcidMDT	.block 2		; Manufacturing date
sdcidCRC	.block 1		; CRC7

		.end

