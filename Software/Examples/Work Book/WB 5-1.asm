	.org    1800h

	ld	hl, BLANK
	push	hl
	ld      ix, HELP
LOOP:
	ex	(sp), ix
	ld	b,50
HELFSEG:
	call    SCAN1
	djnz	HELFSEG
	jr	LOOP
    
	.org    1820h
HELP:
	.db     0aeh
	.db     0b5h
	.db     01fh
	.db     085h
	.db     08fh
	.db     037h
BLANK:
	.db	0
	.db	0
	.db	0
	.db	0
	.db	0
	.db	0

SCAN1	.equ    0624h

	.end            
                                    