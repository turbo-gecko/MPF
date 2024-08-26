	.org	1800h
START:
	ld	ix,BLANK
	call	SCAN		;Display blank, return when any
				;Key is pressed. A register,
				;Contains the key-code.
	ld	hl,FREQTAB	;Base address of frequency table.

;After routine SCAN, A contains the code of the key pressed.
;Use this code as table offset. The desired
;frequency is stored in address HL+A.

	add	a,l		;Add A to HL.
	ld	l,a
	ld	a,11000000b

HALF_PERIOD:
	out	(DIGIT),a	;Output tone signal to TONE-OUT.
				;Activate all 6 columns of
				;the Keyboard matrix.
	ld	b,(hl)		;Get the frequency from FREQTAB.
				;HL has been calculated in
				;previous instructions.
DELAY:	nop
	nop
	nop
	djnz	DELAY		;Loop B times.
	xor	80h		;Complement bit 7 of A.
				;This bit will be output to TONE.
	ld	c,a		;Store A in C
	in	a,(KIN)		;Check if this key is released.
				;All 6 columns have been activated.
				;If any key is pressed, the
				;corres-ponding matrix row
				;input must be at low.
	or	11000000b	;Mask out bit 6 (tape input)
				;and bit 7 (User's K) of register A.
	inc	a		;If A is 11111111, increase
				;A by one will make A zero
				;Zero flag is changed here.
	ld	a,c		;Restore A. from register C.
	jr	z,START		;If all keys are released, re-start.
				;Otherwise, continue this frequency.
	jr	HALF_PERIOD

FREQTAB:
	.db	0b2h		;Key 0
	.db	0a8h		;Key 1
	.db	096h		;Key 2
	.db	085h		;Key 3
	.db	07eh		;Key 4
	.db	070h		;Key 5
	.db	064h		;Key 6
	.db	059h		;Key 7
	.db	054h		;Key 8
	.db	04ah		;Key 9
	.db	042h		;Key A
	.db	03eh		;key B
	.db	037h 		;Key C
	.db	031h 		;Key D
	.db	02ch 		;Key E
	.db	029h 		;Key F

BLANK	.equ 	07a5h
SCAN	.equ	05feh
DIGIT	.equ	2
KIN	.equ	0
	.end
