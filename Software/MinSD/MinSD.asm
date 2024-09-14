; ----------------------------------------------------------------------------
; MinSD.asm
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
; v1.1 - 17th August 2024
; ----------------------------------------------------------------------------
; Recommended memory usage:
; - Program code:
;	2400h for general ROM usage
;	8000h for testing/RAM usage
; - Program variables at fd00h
; ----------------------------------------------------------------------------

; ----------------------------------------------------------------------------
; Device specific defines. Uncomment any relevant devices as required.
; Only uncomment 1 of the #define's in each block.

; ----------------------------
; Block 1 - Z80 devices
; KS Wichet Z80 Microprocessor Kit
;#define		KSWICHIT
; MPF-1 - Microprofessor-1
#define		MPF-1

; ----------------------------
; Block 2 - Serial devices.
#define		ACIA

; ----------------------------
; Block 3 - SPI devices.
#define		GENERIC_IO
;#define TEC-1G_IO
;#define Z80_PIO

; ----------------------------------------------------------------------------

#define		ROM_LOAD		; Used when loading the program
					; into a ROM
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

; KS Wichit Z80 Kit LCD calls
#ifdef KSWICHIT
_INITLCD	.equ	0b64h
_PRINTCHAR	.equ	0cceh
_PRINTTEXT	.equ	0cc8h
_GOTOXY		.equ	0cc2h
#endif

; Misc
BEEP_LENGTH	.equ	80h

; ----------------------------------------------------------------------------
; Main program
;
; If using the mainNoUIEntry point...
; A  -- Disk
; BC -- Slot number to load.
; There will be no key entry, pauses or output to 7 segment display/LCD.
; ----------------------------------------------------------------------------
#ifdef ROM_LOAD
		.org 02400h		; ROM load
#else
		.org 04000h		; RAM load
#endif

main:
#ifdef KSWICHIT
	call	_INITLCD		; Initialise the LCD
	ld	hl,msgIntro		; Display intro message
	call	_PRINTTEXT
#endif
	ld	a,1			; Enable the UI
	ld	(uiEnabled),a

	ld	a,0			; Select disk 0
	jr	mainSelectDisk

mainNoUIEntry:
	push	bc			; Save slot number
	pop	hl
	ld	(slotNumber),hl
	push	af			; Save disk number

	ld	a,0			; Disable the UI
	ld	(uiEnabled),a

	pop	af			; Restore disk number

mainSelectDisk
	call	selectDisk
	jr	c,mainEnd		; Exit if invalid disk

	call	sdInit			; Initialisation the SD card

	call	doCmdLoad		; Load the memory image

	ld	de,(addrStart)		; Get the start address
	ld	hl,dispBuff		; Set up the s7 display buffer

	ld	(hl),a			; Blank last 2 digits
	inc	hl
	ld	(hl),a
	inc	hl

	ld	a,e
	call	_HEX7SG			; Convert the first digit
	ld	a,d
	call	_HEX7SG			; Convert the second digit
	ld	a,0			; Space character

	call	beep			; Confirm load

	ld	a,(uiEnabled)		; Is the UI enabled?
	and	a
	jr	z,mainEnd		; No

#ifdef KSWICHIT
	ld	hl,0100h		; Move to line 2
	call	_GOTOXY
	ld	hl,msgDone		; Display load complete message
	call	_PRINTTEXT
#endif
	ld	ix,dispBuff
	call	_SCAN			; Display load address

#ifdef KSWICHIT
	call	_INITLCD		; Initialise the LCD
#endif

mainEnd
	rst	00h			; Exit the program

; ============================================================================
; Include files
; ============================================================================
#include "..\\Library\\sd_base.asm"

; ============================================================================
; App functions
; ============================================================================

; ----------------------------------------------------------------------------
; beep
; Sends a beep tone to the speaker
;
; Input:	None
; Output:	Beep tone
; Destroys:	A, BC, DE, HL
; ----------------------------------------------------------------------------
beep:
	ld	hl,BEEP_LENGTH
	call	_TONE1K

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
	call	sdInit			; Initialise the SD card
	jr	nc,checkSDOK
	call	sdErrMsg		; Display error message

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
	call	checkSD			; Initialise and check for an SD card
	jr	nc,checkSDHCOK1

	scf
	ret				; Return error

checkSDHCOK1
	call	isSDHC			; Check for an SDHC card
	jr	nc,checkSDHCOK2
	call	sdErrMsg		; Display error message if not

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
	call	checkSDHC		; Check that it is an SDHC card
	ret	c

	call	validateFormat		; SD present and formatted?
	ret	c

	call	selectSlot		; Get slot number
	jp	c,dclBadParamQuit	; Bail out if invalid slot number

	push	af
	ld	a,c			; Update slot number
	ld	(slotNumber),a
	pop	af

	ld	(fcbOffset),a		; Calculate offset in the FCB
	call	calcOffset		; sets up IY register

	ld	l,(iy+FCB_START_ADDR)	; TEC start in memory, FFFF = no file
	ld	h,(iy+FCB_START_ADDR+1)	; TEC start in memory, FFFF = no file

	ld	de,0ffffh		; 16-bit CP
	or	a
	sbc	hl,de
	add	hl,de
	jr	nz,dclValid		; Continue if valid load address

	call	beep			; Long error beeps
	call	beep
	call	beep
	call	beep
	call	beep

	ld	ix,s7EmptyMsg		; Setup empty message
	call	_SCAN			; Loop until key is pressed

	rst	00h

	scf
	ccf
	ret

dclValid
	ld	a,(uiEnabled)		; Is the UI enabled?
	and	a
	jr	z,dclCont		; No

#ifdef KSWICHIT
	ld	hl,0100h		; Move to line 2
	call	_GOTOXY
	ld	hl,msgLoading		; Display loading message
	call	_PRINTTEXT
#endif

dclCont
	ld	a,(slotNumber)		; Go read the file and transfer to RAM
	call	readFile

	scf
	ccf
	ret

dclBadParamQuit
	call	beep			; Long error beeps
	call	beep
	call	beep
	call	beep
	call	beep

	scf
	ret				; ...and quit

; ----------------------------------------------------------------------------
; Error Handling Routines
; ----------------------------------------------------------------------------
sdErrMsg:
	push	af
	call	spiIdle
#ifdef KSWICHIT
	call	_INITLCD		; Initialise the LCD
#endif
	pop	af

	call	_HEX7
	ld	ix,s7ErrorMsg		; setup error message
	ld	(ix),a			; Save error number
	call	_SCAN			; Loop until key is pressed

	rst	00h

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
	ld	a,(uiEnabled)		; Is the UI enabled?
	and	a
	jr	nz,ssPrompt		; Yes

	ld	bc,(slotNumber)		; Restore the slot number
	jr	ssValidate

ssPrompt
#ifdef KSWICHIT
	ld	hl,0100h		; Move to line 2
	call	_GOTOXY
	ld	hl,msgSelect		; Display select slot message
	call	_PRINTTEXT
#endif
	ld	ix,s7LoadMsg		; setup load message

ssDisp
	call	_SCAN			; Loop until 0-9 is pressed
	cp	0ah
	jr	nc,ssDisp

	ld	c,a

ssValidate
	push	bc
	ld	a,c			; Validate slot number
	cp	128			; Check if greater than 127
	jr	c,ssCont2		; No, then continue
	ld	a,0ffh
	pop	bc

	scf				; Set carry flag as an error state
	ret
	
ssCont2
	ld	hl,64			; Get first FCB into buffer
	and	0F8h			; Determine the sector offset
	srl	a
	srl	a
	srl	a
	add	a,l
	ld	(currSector),a

	call	readSdSector		; Read the slot's sector into the buffer
	call	spiIdle

	pop	bc
	ld	a,c			; Fix A to old style slot number
	and	07h

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
	call	isFormatted		; Is the SD card formatted?
	jr	nc,vfOK
	call	sdErrMsg		; Display error message

	scf
	ret				; Return error

vfOK
	scf
	ccf
	ret				; Return success

; ----------------------------------------------------------------------------
; Program data
; ----------------------------------------------------------------------------
#ifdef KSWICHIT
msgDone		.db "Load completed  ",0
msgIntro	.db "SD Prog Loader  ",0
msgLoading	.db "Loading...      "
msgSelect	.db "Select Slot 0-9 ",0
#endif

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

#ifdef ROM_LOAD
		.org 2ff0h		; Launch point from RST 08h
	ret

		.org 2ff4h		; Launch point from RST 10h
	ret

		.org 2ff8h		; Launch point from RST 18h
	jp	rst18Entry

		.org 2ffch		; Launch point from RST 20h
	jp	rst20Entry
#endif
; ----------------------------------------------------------------------------
; Program variables
; ----------------------------------------------------------------------------

		.end

