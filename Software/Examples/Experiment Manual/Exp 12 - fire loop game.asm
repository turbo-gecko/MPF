;
; Segment Illuminates one by one until key-step is pushed
; Any other key will resume looping again.
;
	.org	1800H
INI	ld	hl,TABLE
	ld	ix,OUTBF
LOOP	call	CLRBF		; Clear display buffer
	ld	e,(hl)		; Get the DIGIT-select data
	inc	e		; Test REPEAT code: FF
	jr	z,INI		; If yes, go to INI
	dec	e		; Otherwise, get back E
	ld	d,0		; Use E as an offset to
	add	ix,de		; Calculate the location of
				; the selected digit.
	inc	hl
	ld	a,(hl)		; Get display PATTERN
	ld	(ix),a		; Put in display buffer
	ld	ix,OUTBF
	ld	b,SPEED
;
; The following 4 instruction display the pattern
; for B times (can be adjusted in the above SPEED)
;
LIGHT	call	SCAN1
	jr	c,NSCAN
	ld	c,a		; Key pressed, save key-code in C
				; Note that, reg C will not be
				; Changed until next key input
NSCAN	djnz	LIGHT
;
	ld	a,c
	cp	10H		; Test KEY-STEP of SCAN1
	jr	z,STOP		; If yes, decrement HL to get
				; the same data for display
				; Then it locks like STOP.
	inc	hl		; Otherwise, get next pattern
	inc	hl
STOP	dec	hl
	jr	LOOP
;
;
CLRBF:
	ld	b,6
CLR	ld	(ix),0
	inc	ix
	djnz	CLR
	ld	de,-6		; Get original IX
	add	ix,de
	ret
;
; The 1st byte indicates which DIGIT is to be seleced
; The 2nd byte indicates what PATTERN to be displayed
;
TABLE	.db	5
	.db	SEG_A
	.db	4
	.db	SEG_A
	.db	3
	.db	SEG_A
	.db	2
	.db	SEG_A
	.db	1
	.db	SEG_A
	.db	0
	.db	SEG_A
	.db	0
	.db	SEG_B
	.db	0
	.db	SEG_C
	.db	0
	.db	SEG_D
	.db	1
	.db	SEG_D
	.db	2
	.db	SEG_D
	.db	3
	.db	SEG_D
	.db	4
	.db	SEG_D
	.db	5
	.db	SEG_D
	.db	5
	.db	SEG_E
	.db	5
	.db	SEG_F
	.db	0FFH
;
	.org	1900H
OUTBF	.ds	6
;
SPEED	.equ	3
SEG_A	.equ	08H
SEG_B	.equ	10H
SEG_C	.equ	20H
SEG_D	.equ	80H
SEG_E	.equ	01H
SEG_F	.equ	04H
SCAN1	.equ	0624H
	.end
