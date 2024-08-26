;---------------------------------------------------------------------
; Port LED Count Up - Example program that demonstrates outputting to
; a port all bit patterns from 0 to 255 then restarts.
;
; v1.0 - 13th August 2024
;---------------------------------------------------------------------

;---------------------------------------------------------------------
; Constants
;---------------------------------------------------------------------
DELAY_COUNT	.equ	1800h

PORT_1		.equ	40h
PORT_2		.equ	0fdh

;---------------------------------------------------------------------
; Main program
;---------------------------------------------------------------------

		.org 1800h		; Where to load the program in memory

MAIN:
		xor a			; Start from 00h
LOOP:
		out (PORT_1),a		; Light the LEDs
		out (PORT_2),a		; Light the LEDs

		call DELAY		; Wait for a bit...

		inc a			; Set up for the next count
		jr LOOP			; Start over again.

;---------------------------------------------------------------------
; Functions
;---------------------------------------------------------------------

DELAY:
		push af			; Save A as we are using A in main
		ld bc,DELAY_COUNT	; Setup the number of times to loop

DELAY_LOOP
		dec bc			; Count down by 1
		ld a,b			; Check to see if B is 0
		and a
		jr nz,DELAY_LOOP	; If we haven't reached 0 then go again

		pop af			; Restore A

		ret

		.end