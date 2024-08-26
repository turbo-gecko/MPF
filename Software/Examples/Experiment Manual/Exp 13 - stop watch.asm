	.org	1800h
	ld	ix,OUTBF	; initial display pointer
	ld	de,0		; initial SEC & 1/100 SEC in DE
LOOP	call	SCAN1		; display for 0.1 second
	jr	nc,LOOP		; if any key pressed, then NC
				; so looping the same pattern
	ld	a,e		; otherwise increment 1/100 SEC by 1
	add	a,1
	daa
	ld	e,a
	ld	a,d		; if carry, increment SEC again
	adc	a,0
	daa
	ld	d,a
	ld	a,e		; convert 1/100 SEC to display format
	ld	hl,OUTBF	; and put them into the display buffer
	call	HEX7SG
	ld	(hl),2		; put into display of '-'
	inc	hl
	ld	a,d		; convert SEC to display format
	call	HEX7SG		; and out them into display buffer
	ld	(hl),0		; put BLANK into MSD
	jr	LOOP

	.org	1900h
OUTBF	.ds	6
HEX7SG	.equ	0678h
SCAN1	.equ	0624h
	.end
