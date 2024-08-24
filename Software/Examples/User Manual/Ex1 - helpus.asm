; Display 'HELPUS', HALT when [STEP] is pressed
	.org	1800h
	ld	ix,HELP
DISP
	call	SCAN
	cp	13h		; Key - Step
	jr	nz,DISP
	halt

	.org	1820h
HELP
	.db	0aeh		; 'S'
	.db	0b5h		; 'U'
	.db	01fh		; 'P'
	.db	085h		; 'L'
	.db	08fh		; 'E'
	.db	037h		; 'H'
	
SCAN	.equ	05feh

	.end
			