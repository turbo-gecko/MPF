;---------------------------------------------------------------------
; string.asm
;
; Collection of functions for manipulation of strings.
;
; v1.0 - 28th July 2024
;	 Initial version.
;---------------------------------------------------------------------

;---------------------------------------------------------------------
; Constants
;---------------------------------------------------------------------


; ----------------------------------------------------------------------------
; asciiDecToNum
; Reads the decimal ASCII digit in A and converts it to a number.
;
; Input:	A -- Single ASCII digit
; Output:	A -- Number represented by ASCII character
;		Carry flag is set on error and A set to 0
; Destroys:	A
; ----------------------------------------------------------------------------

asciiDecToNum:
	sub '0'				; Test for ASCII decimal digit
	cp 10
	jr nc,_adtnInvalid		; Error if >= 10

	scf
	ccf				; Clear the carry flag as success
	ret

_adtnInvalid
	ld a,0				; Return A as 0
	scf				; Set carry flag as error
	ret

; ----------------------------------------------------------------------------
; asciiHexToNum
; Reads the hex ASCII digit in A and converts it to a number.
;
; Input:	A -- Single ASCII digit
; Output:	A -- Number represented by ASCII character
;		Carry flag is set on error and A set to 0
; Destroys:	A, BC
; ----------------------------------------------------------------------------
asciiHexToNum:
	ld b,a				; Save ascii number

	sub '0'				; Test for ASCII decimal digit
	cp 10
	jr nc,_ahtnCheckUC		; Error if >= 10
	jr _ahtnDone

_ahtnCheckUC
	ld a,b				; Restore ascii number
	sub 'A'				; Test for ASCII hex digit
	cp 6
	jr nc,_ahtnCheckLC		; Error if >= F
	add a,0ah
	jr _ahtnDone

_ahtnCheckLC
	ld a,b				; Restore ascii number
	sub 'a'				; Test for ASCII hex digit
	cp 6
	jr nc,_ahtnInvalid		; Error if >= f
	add a,0ah

_ahtnDone
	scf
	ccf				; Clear the carry flag as success
	ret

_ahtnInvalid
	ld a,0				; Return A as 0
	scf				; Set carry flag as error
	ret

; ----------------------------------------------------------------------------
; aToDecString
; Converts A to decimal ASCII string
;
; Input:	A -- Number to convert
;		DE -- Pointer to destination string
; Output:	DE -- Pointer to byte after the string
; Destroys:	A, BC, DE
; ----------------------------------------------------------------------------
aToDecString:
	ld l,a
	ld a,0
	ld h,a

	ld bc,-100
	call _atds1
	ld c,-10
	call _atds1
	ld c,-1

_atds1
	ld a,'0'-1

_atds2
	inc a
	add hl,bc
	jr c,_atds2
	sbc hl,bc

_atds3
	ld (de),a
	inc de
	ld a,' '
	ld (de),a
	ret

; ----------------------------------------------------------------------------
; aToNibble
; Converts A to hex ASCII nibble
;
; Input:	A -- Number to convert
; Output:	A -- ASCII char equivalent
; Destroys:	None
; ----------------------------------------------------------------------------
aToNibble:	
	and 0fh				; Just in case...
	add a,'0'			; If we have a digit we are done here.
	cp '9' + 1			; Is the result > 9?
	jr c, _atnDone
	add a,'A'-'0'-$a		; Take care of A-F

_atnDone
	ret

; ----------------------------------------------------------------------------
; aToString
; Converts A to hex ASCII string
;
; Input:	A -- Number to convert
;		DE -- Pointer to destination string
; Output:	DE -- Pointer to byte after the string
; Destroys:	A, DE
; ----------------------------------------------------------------------------
aToString:
	push af
	and 0f0h			; Mask off high order nibble
	sra a				; Move to the lower nibble
	sra a
	sra a
	sra a
	call aToNibble			; Convert to ASCII
	ld (de),a			; Update the string
	inc de

	pop af
	and 0fh				; Mask off low order nibble
	call aToNibble			; Convert to ASCII
	ld (de),a			; Update the string
	inc de

	ld a,0
	ld (de),a

	ret

; ----------------------------------------------------------------------------
; hlToString
; Converts HL to hex ASCII string
;
; Input:	HL -- Number to convert
;		DE -- Pointer to destination string
; Output:	DE -- Pointer to byte after the string
; Destroys:	A, DE
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

	ld a,0
	ld (de),a

	ret

; ----------------------------------------------------------------------------
; hlX10
; Multiplies HL x10.
;
; Input:	HL -- Number to be multiplied by 10
; Output:	HL -- Number multiplied by 10
; Destroys:	BC, HL
; ----------------------------------------------------------------------------
hlX10:
	push bc

	push hl
	pop bc

	add hl,hl
	add hl,hl
	add hl,hl
	add hl,bc
	add hl,bc

	pop bc

	ret

; ----------------------------------------------------------------------------
; strCompare
; Compares two strings
;
; Input:	DE -- Pointer to string 1
;		HL -- Pointer to string 2
;		B -- Number of bytes to compare
; Output:	Clears carry flag on success, sets carry flag on fail
; Destroys:	A, DE, HL
; ----------------------------------------------------------------------------
strCompare:
	ld a,(de)			; Get string 2 char
	sub (hl)			; Get string 1 char and subtract it
	cp 0
	jr nz,_scFail			; They are not the same...
	inc de				; Get ready for next char
	inc hl
	djnz strCompare			; More chars to process...

	scf
	ccf
	ret

_scFail
	scf
	ret

; ----------------------------------------------------------------------------
; strDecToNum
; Reads the decimal string pointed to by HL and returns the number in BC.
;
; Input:	HL -- Pointer to null terminated ASCII string
; Output:	BC -- Number represented by ASCII string
;		Carry flag is set on error and BC set to 0
; Destroys:	A, BC, DE, HL
; ----------------------------------------------------------------------------
strDecToNum:
	push hl
	ld de,0

_stnLoop
	ld a,(hl)			; determine the end of the string
	cp 0				; Check for the null character
	jr z,_stnConvert		; End of string found
	inc hl				; Otherwise go to the next character
	inc d
	inc e
	ld a,e
	cp 6				; If there is more than 5 chars + null
	jr nc,_stnInvalid		; then number is too big
	jr _stnLoop

_stnConvert
	ld bc,0				; take the LSD and add it to BC
	dec hl
	ld a,(hl)
	push de
	call asciiDecToNum
	jr c,_stnInvalid

	ld c,a
	pop de
	dec e
	jr z,_stnDone

_stnDigit
	dec hl				; take the next digit x10 add to BC
	ld a,(hl)
	push de
	call asciiDecToNum

	jr c,_stnInvalid

	pop de
	push hl
	ld h,0
	ld l,a
	push de
_stnMult
	ld a,d
	cp e
	jr z,_stnMultSkip
	call hlX10
	dec d
	jr _stnMult

_stnMultSkip
	add hl,bc
	push hl
	pop bc
	pop de
	pop hl

	dec e
	jr z,_stnDone

	jr _stnDigit

_stnInvalid
	pop hl
	ld bc,0				; Clear the number
	scf				; Set carry flag as error
	ret

_stnDone
	pop hl
	scf
	ccf				; Clear carry flag as success
	ret

; ----------------------------------------------------------------------------
; strHexToNum
; Reads the hex string pointed to by HL and returns the number in BC.
;
; Input:	HL -- Pointer to null terminated ASCII string
; Output:	BC -- Number represented by ASCII string
;		Carry flag is set on error and BC set to 0
; Destroys:	A, BC, DE, HL
; ----------------------------------------------------------------------------
strHexToNum:
	push hl
	ld de,0				; Reset loop counter
	ld bc,0				; Clear returned value

_sthLoop
	ld a,(hl)			; determine the end of the string
	cp 0				; Check for the null character
	jr z,_sthConvert		; End of string found
	inc hl				; Otherwise go to the next character
	inc e
	ld a,e
	cp 5				; If there is more than 4 chars + null
	jr c,_sthLoop			; then number is too big
	pop hl
	jr _sthInvalid

_sthConvert
	pop de				; Copy hex string pointer to DE
	ld hl,0

_sthAddDigits
	ld a,(de)
	call asciiHexToNum		; Convert the char to a num
	jr c,_sthInvalid		; If not a valid char, exit
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add a,l
	ld l,a

	inc de
	ld a,(de)			; Get the next byte in the string
	cp 0h				; Is it null? (end of string)
	jr z,_sthDone
	jr _sthAddDigits

_sthInvalid
	ld bc,0				; Clear the number

	scf				; Set carry flag as error
	ret

_sthDone
	push hl				; Restore the number to BC
	pop bc

	scf
	ccf				; Clear carry flag as success
	ret

; ----------------------------------------------------------------------------
; strSize
; Returns number of chars in a string, excluding the null
;
; Input:	HL -- Pointer to string
; Output:	BC -- Number of bytes in the string
; Destroys:	A, BC, HL
; ----------------------------------------------------------------------------
strSize:
	ld bc,0				; Clear the byte counter

_sszLoop
	ld a,(hl)			; Get string character
	cp 0
	jr z,_sszDone			; Is it a null?
	inc hl				; Set up for next character in the string
	inc bc				; Increment the byte count
	jr _sszLoop

_sszDone
	scf
	ret

