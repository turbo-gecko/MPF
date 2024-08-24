; Flash 'HELPUS'
	.org	1800h
	ld	hl,BLANK
	push	hl
	ld	ix,HELP
LOOP	ex	(sp),ix
	ld	b,50
HELFSEG	call	SCAN1
	djnz	HELFSEG
	jr	LOOP

	.org	1820h
HELP
	.db	0aeh		; 'S'
	.db	0b5h		; 'U'
	.db	01fh		; 'P'
	.db	085h		; 'L'
	.db	08fh		; 'E'
	.db	037h		; 'H'

BLANK	.db	0
	.db	0
	.db	0
	.db	0
	.db	0
	.db	0

SCAN1	.equ	0624h

	.end
			