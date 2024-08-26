	.org	1800h
;
START	ld	ix,SONG		;Initial SONG-TABLE pointer
FETCH	ld	a,(ix)		;Get note data
	add	a,a		;Each note data have 2 bytes
	jr	c,STOP		;STOP?
	JP	m,START		;REPEAT?
	ld	c,0		;Reset TONE-BIT (BIT-7 of C)
	bit	6,a		;REST?
	jr	nz,PLAY
	set	7,c		;Set ONTE-BIT
PLAY	and	3fh		;Mask out note data
	ld	hl,FRQTAB
	add	a,l
	ld	l,a		;Locate pointer in FRQTAB
	ld	e,(hl)		;Counts of loop per HALF-PERIOD delay
	inc	hl
	ld	d,(hl)		;Counts of HALF-PERIODS per UNIT-TIME
	inc	ix
	ld	h,(ix)		;Counts of UNIT-TIME for this note
	ld	a,0ffh

;The following loop runsfor one NOTE or REST:
;
TONE:
	ld	l,d
UNIT	out	(02h),a		;Bit 7 is NOTE-OUT
	ld	b,e
DELAY	nop			;delay loop B*25-5 states
	nop
	nop
	djnz	DELAY
	xor	c		;If C=80H then TONE-OUT.
				;If C=00H then REST.
	dec	l
	jr	nz,UNIT
	dec	h
	jr	nz,TONE

;The currentnote has ended, increment pointer next.
;
	inc	ix
	jr	FETCH
;
STOP	halt
;
FRQTAB: 
;
;1st byte: counts of delay loop per HALF-PERIOD.
;2nd byte: counts of HALF-PERIOD per UNIT-TIME.
;
;OCTAVE 3.
       .dw    18e1h		;CODE 00 , G
       .dw    1ad4h		;CODE 01 , #G
       .dw    1bc8h		;CODE 02 , A
       .dw    1dbdh		;CODE 03 , #A
       .dw    1eb2h		;CODE 04 , B
;OCTAVE 4
       .dw    20a8h		;CODE 05 , C
       .dw    229fh		;CODE 06 , #C
       .dw    2496h		;CODE 07 , D
       .dw    268dh		;CODE 08 , #D
       .dw    2985h		;CODE 09 , E
       .dw    2b7eh		;CODE OA , F
       .dw    2e77h		;CODE OB ,#F
       .dw    3170h		;CODE OC ,G
       .dw    336ah		;CODE OD ,#G
       .dw    3764h		;CODE OE , A
       .dw    3a5eh		;CODE OF , #A
       .dw    3d59h		;CODE 10 , B
;OCTAVE 5
       .dw    4154h		;CODE 11 , C
       .dw    454fh		;CODE 12 , #C
       .dw    494ah		;CODE 13 , D
       .dw    4d46h		;CODE 14 , #D
       .dw    5242h		;CODE 15 , E
       .dw    573eh		;CODE 16 , F
       .dw    5c3bh		;CODE 17 , #F
       .dw    6237h		;CODE 18 , G
       .dw    6734h		;CODE 19 , #G
       .dw    6e31h		;CODE 20 , A
       .dw    742eh		;CODE 21 , #A
       .dw    7b2ch		;CODE 1C , B
;OCTAVE 6
       .dw    8229h		;CODE 1D , C
       .dw    8a27h		;CODE lE , #C
       .dw    9225h		;CODE 1F , D
;
;1st byte, bit 7,6,5 & 4-0 STOP, REPEAT, REST & NOTE
;	   Code of STOP:     80H
;	   Code of REPEAT:   40H
;	   Code of REST:     20H
;2nd byte, NOTE LENGTH: counts of UNTI-TIME (N*0.077 sec)
;
;JINGLE BELL: (Truncated)
SONG	.org	1880h
	.db	9
	.db	4
	.db	9
	.db	4
	.db	9
	.db	6
	.db	20H		;REST
	.db	2
	.db	9
	.db	4
	.db	9
	.db	4
	.db	9
	.db	6
	.db	20H		;REST
	.db	2
	.db	9
	.db	4
	.db	0CH
	.db	4
	.db	5
	.db	4
	.db	7
	.db	4
	.db	9
	.db	8
	.db	20H		;REST
	.db	8
	.db	80H		;STOP
	.end

; The following data are codes of the song 'GREEN SLEEVES'. 
; The user can put them at the SONG-table, i.e. from 1880H.
; It will play until 'RS' key is pressed.


; 1880  07 08 OA	10 OC 08 OE 10	10 04 OE 04  OC 10 09 08
; 1890  05 10 07	04 09 04 OA 10	07 08 07 10  06 04 07 04
; 18A0  09 10 06	08 02 10 07 08	OA 10 OC 08  OE 10 10 04
; 18B0  OE 04 OC	10 09 08 05 10	07 04 09 04  OA 08 09 08

; 18C0  07 08 06	08 04 08 06 08	07 10 20 08  11 10 11 08
; 18D0  11 10 10	04 OE 04 OC 10	09 08 05 10  07 04 09 04
; 18E0  OA 10 07	08 07 10 06 04	07 04 09 10  06 08 02 10
; 18F0  20 08 11	10 11 08 11 10	10 04 OE 04  OC 10 09 08
; 1900  05 10 07	04 09 04 OA 08	09 08 07 08  06 08 04 08
; 1910  06 08 07	18 20 10 40
;The ending address  is 1916H.
