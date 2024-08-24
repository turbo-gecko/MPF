; Display internal position code
	.org	1800h
	ld	ix,OUTBF
LOOP	call	SCAN1
	jr	c,LOOP
	ld	hl,OUTBF
	call	HEX7SEG
	jr	LOOP

	.org	1900h
OUTBF	.db	0
	.db	0
	.db	0
	.db	0
	.db	0
	.db	0

SCAN1	.equ	0624h
HEX7SEG	.equ	0678h

	.end