	.org	1800h
RINGBK	ld	a,20		; 20Hz freq shift rate
				; so that 1 sec has 20 loops
RING	ex	AF,AF'		; Save to A'
	ld	c,211
	ld	hl,8
	call	TONE		; 320Hz, 25mSec
	ld	c,140
	ld	hl,12
	call	TONE		; 480Hz, 25mSec
	ex	af,af'		; Retrieve from A'
	dec	a		; Decrement 1 count
	jr	nz,RING
;
	ld	bc,50000
	call	DELAY		; Silent, 2 sec
	jr	RINGBK
; Delay subroutine: (BC) * 40 micro-sec
; based on the 1.79MHz system clock
DELAY	ex	(sp),hl		; 19 states
	ex	(sp),hl		; 19
	cpi			; 16
	ret	PO		; 5
	jr	DELAY		; 12
;
;
TONE	.equ	05e4h
	.end
