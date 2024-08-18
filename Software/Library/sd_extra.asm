; ----------------------------------------------------------------------------
; sd_extra.asm
; Additional SD card functions to sd_base.asm.
; This is mainly for non-ROM applications.
;
; v1.0 - 17th August 2024
; ----------------------------------------------------------------------------

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
	call _Num1
	ld bc,-1000
	call _Num1
	ld bc,-100
	call _Num1
	ld c,-10
	call _Num1
	ld c,-1

_Num1:
	ld a,'0'-1

_Num2:
	inc a
	add hl,bc
	jr c,_Num2
	sbc hl,bc

	ld d,a				; backup a
	ld a,e
	or a
	ld a,d				; restore it in case
	jr z,_prout			; if E flag 0, all ok, print any value

	cp '0'				; no test if <>0
	ret z				; if a 0, do nothing (leading zero)

	ld e,0				; clear flag & print it

_prout:
	ld (ix),a
	inc ix

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
	
;	call spiIdle

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
	jr z,_getPNM1			; OK, then continue
	pop de				; Restore registers
	pop bc

	scf				; Set carry flag
	ret nz				; and non-zero flag on return

_getPNM1:
	push hl				; Index to data in the CID buffer
	pop ix
	ld iy,paramStrBuff		; Index to the PNM string
	ld b,5				; PNM - Product name length (see SD card Spec)

_getPNM2:
	ld a,(ix+3)			; loop through the 5 bytes of PNM data
	ld (iy),a			; and copy to the string
	inc ix
	inc iy
	djnz _getPNM2

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
	jr z,_getMF1			; OK, then continue
	pop hl				; if not, restore registers
	pop de
	pop bc

	scf				; Return with carry flag set on error.
	ret nz				; and return

_getMF1:
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
	jr c,_gm1
	add a,06h

_gm1:
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
	
	call spiIdle

	ret

; ----------------------------------------------------------------------------
; writeVolLabel
; Writes a new volume label to the current disk.
;
; Input:	HL -- Pointer to null terminated disk volume label.
; Output:	None
; Destroys:	A, BC, DE, HL
; ----------------------------------------------------------------------------
writeVolLabel:
	push hl
	ld bc,00h
	ld (currSector),bc		; Save the sector number
	call readSdSector		; Go read the sector

	ld hl,sdBuff+VOL_LABEL_OFS	; Clear the current volume label
	ld a,' '
	ld (hl),a
	ld de,sdBuff+VOL_LABEL_OFS+1
	ld bc,VOL_LABEL_SIZE-1
	ldir

	pop hl
	ld de,sdBuff+VOL_LABEL_OFS	; Start of volume label
	ld bc,VOL_LABEL_SIZE		; Maximum number of characters to copy

_wvlLoop:
	ld a,(hl)
	cp 0h				; Check for the terminating null
	jr z,_wvlDone
	ld (de),a			; Store the character
	inc hl
	inc de
	djnz _wvlLoop			; Get the next character

_wvlDone:
	ld bc,00h
	ld (currSector),bc		; Write MBR sector
	call writeSdSector
	ret				; and return.

; ----------------------------------------------------------------------------
; Constants
; ----------------------------------------------------------------------------
VOL_LABEL_OFS	.equ	6		; Volume label offset in the MBR
VOL_LABEL_SIZE	.equ	20		; Maximum size of the volume label

; ----------------------------------------------------------------------------
; Data and variables
; ----------------------------------------------------------------------------

		.end