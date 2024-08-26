	.org	1800h
	di			; Disable interrupt, which affects timing
	ld	ix,OUTBF
;
; ONESEC loop takes 1 second to execute, it consists of 3
; subroutines & 1 additional delay process
;
ONESEC:
	ld	b,100		; 7
LOOP1	call	SCAN1
	djnz	LOOP1		; (17+17812+13)*100-5=1784195
	call	TMUPDT		; 17+258=275
	call	BFUPDT		; 17+914=931
LOOP2	nop
	djnz	LOOP2		; (4+13)*256-5=4347
	jr	ONESEC		; 12
;
; Time-buffer is updated here.
; Note that this routine takes the same time in any
; condition, 275 cycles.
;
TMUPDT:
	ld	hl,MAXTAB
	ld	de,SEC
	ld	b,3
	scf			; Set carry flag: force add 1
TMINC	ld	a,(de)
	adc	a,0
	daa
	ld	(de),a
	sub	(hl)		; Compare with data in MAXTAB
				; if the result is less than that,
				; the following loop will be null
				; delay, becuse of no carry propagation
				;
	jr	c,COMPL
	ld	(de),a
COMPL	ccf			; complement carry flag
	inc	hl
	inc	de
	djnz	TMINC
	ret
; Display buffer is updated here.
; It takes 914 cycles.
;
BFUPDT:
	ld	hl,OUTBF
	ld	de,SEC
	ld	b,3
PUTBF	ld	a,(de)
	call	HEX7SG
	inc	de
	djnz	PUTBF
	dec	hl
	dec	hl
	set	6,(hl)		; Set decimal point of hour
	dec	hl
	dec	hl
	dec	hl		; Set decimal point of MINUTE
	ret			; B-0 when, return
;
MAXTAB:
	.db	60h
	.db	60h
	.db	12h
;
	.org	1a00h
TMBF:
SEC	.ds	1
MIN	.ds	1
HOUR	.ds	1
;
OUTBF	.ds	6
;
SCAN1	.equ	624h
HEX7SG	.equ	66dh
	.end
