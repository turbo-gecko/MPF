;---------------------------------------------------------------------
; RAM Finder Program - Tests each byte in memory to see if it is
; writeable or not. It is used to determine which areas of the 64K Z80
; memory map are populated with R/W memory.
;
; - Start address is assumed to be 0x0000 for the test.
; - The test skips over the part of memory where the program is loaded.
; - Requires an ACIA serial card for output.
;
; v1.0 - 1st May 2024
;---------------------------------------------------------------------

#define		ROM_LOAD		; Used when loading the program
					; into a ROM

;---------------------------------------------------------------------
; Constants
;---------------------------------------------------------------------
CR		.equ	0dh
LF		.equ	0ah

#ifdef ROM_LOAD
		.org 2222h		; ROM load
#else
		.org 1800h		; Where to load the program in memory
#endif

START:
		call AC_INIT		; Initialise serial port
		ld hl,MSG_INTRO		; Display message for start of program
		call AC_TX_STRING

		ld hl, 0000h		; Start of Memory
		ld de, 0FFFFh		; End of Memory (assuming 64K RAM,
					; adjust if needed)
		xor a
		ld (RAM_FOUND), a	; Clear the ram found flag

MAIN:
#ifndef ROM_LOAD
		push hl			; Save the current memory location
		ld bc, START		; Check to see if we are at the memory
		sbc hl, bc		; locations where the program is
		jr nz, MAIN_0		; loaded.
		pop hl
		ld hl, PROG_END		; If so, skip to the address after 
		push hl			; the program

		ld a, (RAM_FOUND)	; Check to see if we have found RAM at 
					; the previous location.
		cp 0h
		jp nz, MAIN_1		; No, then continue as normal
		ld hl, START
		call NEW_RAM_LOC	; Yes, display the new RAM location
		
MAIN_0:
		pop hl			; Restore the memory location
#endif
		ld a, (hl)		; Save the original memory content
		ld b, a
		ld (hl), 55h		; Write first test pattern 0x55
		ld a, (hl)		; Read back the value
		cp 55h			; Compare it with 0x55
		jp nz, ERROR		; Jump to ERROR if not equal
		ld (hl), 0AAh		; Write second test pattern 0xAA
		ld a, (hl)		; Read back the value
		cp 0AAh			; Compare it with 0xAA
		jp nz, ERROR		; Jump to ERROR if not equal
		ld a, b			; Restore the original memory content
		ld (hl), a
		ld a, (RAM_FOUND)	; Check to see if we have found RAM at 
					; the previous location.
		cp 0h
		jp nz, MAIN_1		; No, then continue as normal
		call NEW_RAM_LOC	; Yes, display the new RAM location

MAIN_1:
		inc hl			; Increment HL to test the next memory 	
					; location
		ld a, l			; Check if we've wrapped around to 0
		or h			; OR L and H to see if both are zero
		jp nz, MAIN		; Continue loop if HL not wrapped around 
					; to 0
		jp FINISH		; If finished, jump to finish routine

NEW_RAM_LOC:
		push hl			; Save HL register
		ld hl,MSG_RAM		; Display message for RAM found
		call AC_TX_STRING
		pop hl			; Restore HL register
		ld a,h
		push hl
		call BYTE_2_ASCII
		pop hl
		ld a,l
		push hl
		call BYTE_2_ASCII
		ld a, ':'
		call AC_TX_CHAR
		pop hl

		ld a, 55h
		ld (RAM_FOUND), a	; Write non-zero value to RAM_FOUND
		ret

ERROR:
		ld a, (RAM_FOUND)	; Check to see if we did not find RAM at 
					; the previous location.
		cp 0h
		jr z, MAIN_1		; Still no RAM so go again

		call RAM_BLK_END

		ld (RAM_FOUND),a	; And write zero to RAM_FOUND

		jp MAIN_1

RAM_BLK_END:
		dec hl
		ld a,h
		push hl
		call BYTE_2_ASCII
		pop hl
		ld a,l
		push hl
		call BYTE_2_ASCII
		ld hl, MSG_CRLF
		call AC_TX_STRING
		xor a			; Clear A
		pop hl			; Restore HL register
		inc hl

		ret

FINISH:
		call RAM_BLK_END
		ld hl,MSG_END		; Display message for end of program
		call AC_TX_STRING
		rst 00h			; All done

BYTE_2_ASCII:
		push bc			; Save BC register pair
		ld b, a			; Copy A to B for second nibble 
					; processing
		and 0Fh			; Isolate high nibble of A
		call NIBBLE_2_ASCII	; Do the lower nibble conversion
		ld c, a
		push bc
		ld a, b			; Retrieve original byte for low nibble 
					; processing
		srl a			; Shift right four times to get low 
					; nibble
		srl a
		srl a
		srl a
		call NIBBLE_2_ASCII	; Do the upper nibble conversion
		call AC_TX_CHAR		; Print out the upper nibble
		pop bc
		ld a, c
		call AC_TX_CHAR		; Print out the lower nibble
		pop bc			; Restore BC register pair

		ret

NIBBLE_2_ASCII:
		add a, 30h		; Correct for digits
		cp 3ah			; Return if it was a 0 - 9
		ret m
		add a, 7		; Otherwise correct for A - F

		ret

#include "acia.asm"

MSG_CRLF	.db CR, LF, 0
MSG_END		.db CR, LF, "RAM finder complete", CR, LF, 0
MSG_INTRO	.db CR, LF, "RAM Finder", CR, LF, "==========", CR, LF, 0
MSG_NO_RAM	.db "NOT RAM - ", 0
MSG_RAM		.db "RAM - ", 0

#ifdef ROM_LOAD
PROG_END
		.org 1800h
RAM_FOUND	.db 0
#else
RAM_FOUND	.db 0
PROG_END
#endif

		.end