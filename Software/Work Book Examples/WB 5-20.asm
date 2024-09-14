; Display 3 bytes in RAM to 6 Hexa-digits
	.org	1800h
	ld	de, BYTE0
	ld	hl, OUTBF
	ld	b, 3
LOOP:
	ld	a, (de)
	call	HEX7SG
	inc	de
	djnz	LOOP
; Conversion complete, break for check
	ld	ix, OUTBF
	call	SCAN
	halt
            
	.org	1900h
BYTE0	.db	10h
	.db	32h
	.db	54h
OUTBF	.ds	6
            
HEX7SG	.equ	0678h
SCAN	.equ	05feh

	.end            
                                    