;
	.org	1800h
;
CTC0	.equ	40h
SCAN	.equ	05feh
START:
	ld	a,18h		; Loading the interrupt register
	ld	i,a
	ld	a,10110101b	; Loading the chnnel control
	out	(CTC0),a
	ld	a,020h		; Loading the constant register
	out	(CTC0),a
	ld	a,0a8h		; Loading the interrupt vector register
	out	(CTC0),a
	im	2		; Set interrupt mode 2
	ei
MAIN:
	ld	ix,DISP_BUFFER
	call	SCAN
	jr	MAIN
; ************************************************************
ADD_TIME_BUFFER:
	ld	de,TIME_BUFFER
	ld	a,(de)
	inc	a
	ld	(de),a
	cp	0dah		; Increment SEC only if the
	ld	b,4		; number of interrupts reaches
	ret	nz		; 218 (ie 0DAH).
	xor	a
	dec	b
	ld	(de),a
	inc	de
	ld	hl,MAX_TIME_TABLE
ATB1:
	ld	a,(de)
	add	a,1
	daa
	ld	(de),a
	sub	(hl)		; Compare A with data in MAX_TIME_TABLE
	ret	c
	ld	(de),a
	inc	hl		; If the result is less that, the
	inc	de
	djnz	ATB1		; following loop will be null.
	ret
SET_DISP_BUFFER:
	ld	hl,DISP_BUFFER	; Convert data in display buffer
	ld	de,SECOND	; to display format
	ld	b,3
SDB1:
	ld	a,(de)
	call	HEX7SG
	inc	de
	djnz	SDB1
	dec	hl
	dec	hl
	set	6,(hl)		; Set decimal point for hour
	dec	hl
	dec	hl
	set	6,(hl)
	ret
; ************************************************************
MAX_TIME_TABLE:
	.db	60h		; The maximal value of the time constant
	.db	60h		; e.g. the maximum of second is 60,
	.db	12h		; the maximum of hour is 12. (The use may change
	.org	18a8h		; 12 to 24 as he wished)
	.dw	INTERRUPT
INTERRUPT:			; Entry point of interrupt service
	push	af		; routine.
	push	bc
	push	de
	push	hl
	call	ADD_TIME_BUFFER
	ld	a,b
	cp	4
	call	nz,SET_DISP_BUFFER
	pop	hl
	pop	de
	pop	bc
	pop	af
	ei
	reti
HEX7SG	.equ	678h
	.org	1a00h

TIME_BUFFER:
	.db	0
SECOND
	.ds	1	; Locations for pressetting values.
MINUTE
	.ds	1
HOUR
	.ds	1
DISP_BUFFER:
	.ds	6
	.end
