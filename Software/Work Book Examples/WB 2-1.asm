	.org	1800h

LOOP:
	ld	c, 0
	ld	hl, 0c0h
	call	TONE
	ld	c,0c0h
	ld	hl,100h
	call	TONE
	jr	LOOP

TONE	.equ	05e4h

	.end
		