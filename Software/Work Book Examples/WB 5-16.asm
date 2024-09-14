; Display internal code
	.org	1800h
	ld	ix, OUTBF
LOOP:
	call	SCAN
	ld	hl, OUTBF
	call	HEX7SG
	jr	LOOP
            
	.org	1900h
OUTBF:
	.db	0
	.db	0
	.db	0
	.db	0
	.db	0
	.db	0
            
SCAN	.equ	05feh
HEX7SG	.equ	0678h

	.end            
                                    