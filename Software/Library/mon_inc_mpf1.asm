; ----------------------------------------------------------------------------
; mon_inc_mpf1.asm
; MPF-1 specific definitions
;
; v1.0 - 24th August 2024
; ----------------------------------------------------------------------------

HEX7		.equ	0689h		; Convert a hexadecimal digit into the
					; 7-segment display format
HEX7SG		.equ	0678h		; Convert two hexadecimal digits into
					; 7-segment display format
RAMCHK		.equ	05f6h		; Check if the given address is in RAM
SCAN		.equ	05feh		; Scan keyboard and display until a
					; new key-in
SCAN1		.equ	0624h		; Scan keyboard and display one cycle
TONE		.equ	05e4h		; Generate sound
TONE1K		.equ	05deh		; Generate sound at 1KHz
TONE2K		.equ	05e2h		; Generate sound at 2KHz
