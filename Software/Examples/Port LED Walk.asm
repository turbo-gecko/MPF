;---------------------------------------------------------------------
; Port LED Walk - Example program that demonstrates outputting to a
; a port a pattern that enables a single output pin that increases in
; position from bit 0 to bit 7 then restarts.
;
; v1.0 - 13th August 2024
;---------------------------------------------------------------------

;---------------------------------------------------------------------
; Constants
;---------------------------------------------------------------------
DELAY_COUNT	.equ	2000h

PORT_1		.equ	40h
;PORT_2		.equ	0fdh

;---------------------------------------------------------------------
; Main program
;---------------------------------------------------------------------

		.org 1800h		; Where to load the program in memory

MAIN:
		ld a,01h		; Set up for least significant bit
		ld b,8			; Number of bits to rotate
LOOP:
		out (PORT_1),a		; Light the LED
;		out (PORT_2),a		; Light the LED

		call DELAY		; Wait for a bit...

		sla a			; Set up for the next LED
		djnz LOOP		; Keep going until all LEDS lit
		jr MAIN			; Start over again.

;---------------------------------------------------------------------
; Functions
;---------------------------------------------------------------------

DELAY:
		push af			; Save A as we are using A in main
		push bc			; Save B as we are using B in main
		ld bc,DELAY_COUNT	; Setup the number of times to loop

DELAY_LOOP
		dec bc			; Count down by 1
		ld a,b			; Check to see if B is 0
		and a
		jr nz,DELAY_LOOP	; If we haven't reached 0 then go again

		pop bc			; Restore B
		pop af			; Restore A

		ret

		.end