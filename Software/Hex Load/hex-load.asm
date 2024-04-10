;---------------------------------------------------------------------
; Intel hex load program that uses the MC6850 ACIA library
;
; This code is a reworking of the Intel hex loader routine in the Z80
; SBC monitor at http://www.vaxman.de/projects/tiny_z80/ by the author
; B. Ulmann
;
; The code has been tested using an SC139 Serial 68B50 Module (RC2014)
; (https://smallcomputercentral.com/sc139-serial-68b50-module-rc2014/)
; connected to the TEC-1G Z80 bus via a TEC-1G to RC2014 adapter as at
; https://github.com/turbo-gecko/TEC/tree/main/Hardware/Z80%20to%20RC%20Bus%20Adapter
;
; It has also been tested by burning an expansion ROM for the MPF-1
; using the same hardware as described above.
;
; Requires acia.asm. To use a different comms IC, replace the acia.asm
; library which the device specific libray.
;
; v1.1 - 10th April 2024
;        Added RTS signalling for HW flow control
; v1.0 - 7th April 2024
;---------------------------------------------------------------------

;---------------------------------------------------------------------
; Constants
;---------------------------------------------------------------------
CR          .equ    0dh
LF          .equ    0ah
SPACE       .equ    20h
ESC         .equ    1bh

;---------------------------------------------------------------------
; Main Program
;---------------------------------------------------------------------

            .org    02000h          ; MPF-1 Expansion ROM
            ;.org    04000h          ; TEC-1G User RAM
            ;.org    0bd00h          ; TEC-1G Expansion RAM/ROM/FRAM
            
MAIN:
            call    AC_INIT         ; Initialise the ACIA
            
            call    CRLF            ; Send a CR/LF to start a new line
            
            ld      hl,MSG_INTRO_1  ; Send intro messages...
            call    AC_TX_STRING
            
            ld      hl,MSG_INTRO_2
            call    AC_TX_STRING
            
LOAD_LOOP:
            call    AC_RX_CHAR      ; Get a single character
            cp      CR              ; Don't care about CR
            jr      z,LOAD_LOOP
            cp      LF              ; ...or LF
            jr      z,LOAD_LOOP
            cp      SPACE           ; ...or a space
            jr      z,LOAD_LOOP
            cp      ESC             ; Do care about <Esc>...
            jr      z,LOAD_QUIT     ; ...as it's time to quit
            call    TO_UPPER        ; Convert to upper case
            call    AC_TX_CHAR      ; Echo character
            cp      ':'             ; Is it a colon?
            jr      nz,LOAD_ERROR   ; No - then there is an error
            call    GET_BYTE        ; Yes - get record length into A
            ld      d,a             ; Length is now in D
            ld      e,0             ; Clear checksum
            call    LOAD_CHK        ; Compute checksum
            call    GET_WORD        ; Get load address into HL
            ld      a,h             ; Update checksum by this address
            call    LOAD_CHK
            ld      a,l
            call    LOAD_CHK
            call    GET_BYTE        ; Get the record type
            call    LOAD_CHK        ; Update checksum
            cp      1               ; Have we reached the EOF marker?
            jr      nz,LOAD_DATA    ; No - get some data
            call    GET_BYTE        ; Yes - EOF, read checksum data
            call    LOAD_CHK        ; Update our own checksum
            ld      a,e
            and     a               ; Is our checksum zero (as expected)?
            jr      z,LOAD_DONE     ; Yes - we are all done here

LOAD_CHK_ERR: 
            call    CRLF            ; No - print an error message
            ld      hl,MSG_ERROR_2
            call    AC_TX_STRING
            jr      LOAD_EXIT       ; And exit

LOAD_DATA:
            ld      a,d             ; Record length is now in A
            and     a               ; Did we process all bytes?
            jr      z,LOAD_EOL      ; Yes - process end of line
            call    GET_BYTE        ; Read two hex digits into A
            call    LOAD_CHK        ; Update checksum
            ld      (hl),a          ; Store byte into memory
            inc     hl              ; Increment pointer
            dec     d               ; Decrement remaining record length
            jr      LOAD_DATA       ; Get next byte

LOAD_EOL:
            call    GET_BYTE        ; Read the last byte in the line
            call    LOAD_CHK        ; Update checksum
            ld      a,e
            and     a               ; Is the checksum zero (as expected)?
            jr      nz,LOAD_CHK_ERR
            call    CRLF
            jr      LOAD_LOOP       ; Yes - read next line

LOAD_ERROR:
            ld      hl,MSG_ERROR_1
            call    AC_TX_STRING    ; Print error message

LOAD_EXIT:
            call    CRLF
            
            rst     00h
LOAD_QUIT:
            ld      hl,MSG_QUIT
            call    AC_TX_STRING    ; Print quit message
            call    LOAD_EXIT
            
            ret

LOAD_DONE:
            call    CRLF
            ld      hl,MSG_DONE
            call    AC_TX_STRING
            call    LOAD_EXIT

LOAD_CHK:
            ld      c,a             ; All in all compute E = E - A
            ld      a,e
            sub     c
            ld      e,a
            ld      a,c
             
            ret

;---------------------------------------------------------------------
; Send a CR/LF pair:
;---------------------------------------------------------------------
CRLF        ld      a,CR
            call    AC_TX_CHAR
            ld      a,LF
            call    AC_TX_CHAR
            
            ret

;---------------------------------------------------------------------
; Get a byte in hexadecimal notation. The result is returned in A. Since
; the routine get_nibble is used only valid characters are accepted - the 
; input routine only accepts characters 0-9a-f.
;---------------------------------------------------------------------
GET_BYTE:
            push    bc              ; Save contents of B (and C)
            call    GET_NIBBLE      ; Get upper nibble
            rlc     a
            rlc     a
            rlc     a
            rlc     a
            ld      b,a             ; Save upper four bits
            call    GET_NIBBLE      ; Get lower nibble
            or      b               ; Combine both nibbles
            pop     bc              ; Restore B (and C)
            ret

;---------------------------------------------------------------------
; Get a hexadecimal digit from the serial line. This routine blocks until
; a valid character (0-9a-f) has been entered. A valid digit will be echoed
; to the serial line interface. The lower 4 bits of A contain the value of 
; that particular digit.
;---------------------------------------------------------------------
GET_NIBBLE:
            call    AC_RX_CHAR      ; Read a character
            call    TO_UPPER        ; Convert to upper case
            call    IS_HEX          ; Was it a hex digit?
            jr      nc,GET_NIBBLE   ; No, get another character
            call    NIBBLE2VAL      ; Convert nibble to value
            call    PRINT_NIBBLE
            
            ret

;---------------------------------------------------------------------
; Get a word (16 bit) in hexadecimal notation. The result is returned in HL.
; Since the routines get_byte and therefore get_nibble are called, only valid
; characters (0-9a-f) are accepted.
;---------------------------------------------------------------------
GET_WORD:
            push    af
            call    GET_BYTE        ; Get the upper byte
            ld      h,a
            call    GET_BYTE        ; Get the lower byte
            ld      l,a
            pop     af
            ret

;---------------------------------------------------------------------
; is_hex checks a character stored in A for being a valid hexadecimal digit.
; A valid hexadecimal digit is denoted by a set C flag.
;---------------------------------------------------------------------
IS_HEX:
            cp      'F' + 1         ; Greater than 'F'?
            ret     nc              ; Yes
            cp      '0'             ; Less than '0'?
            jr      nc,IS_HEX_1     ; No, continue
            ccf                     ; Complement carry (i.e. clear it)
            ret
IS_HEX_1:
            cp      '9' + 1         ; Less or equal '9*?
            ret     c               ; Yes
            cp      'A'             ; Less than 'A'?
            jr      nc,IS_HEX_2     ; No, continue
            ccf                     ; Yes - clear carry and return
            ret
IS_HEX_2:
            scf                     ; Set carry
        
            ret

;---------------------------------------------------------------------
; nibble2val expects a hexadecimal digit (upper case!) in A and returns the
; corresponding value in A.
;---------------------------------------------------------------------
NIBBLE2VAL:
            cp      '9' + 1         ; Is it a digit (less or equal '9')?
            jr      c, NIBBLE2VAL_1 ; Yes
            sub     7               ; Adjust for A-F
NIBBLE2VAL_1:
            sub     '0'             ; Fold back to 0..15
            and     0fh             ; Only return lower 4 bits
            
            ret

;---------------------------------------------------------------------
; print_nibble prints a single hex nibble which is contained in the lower 
; four bits of A:
;---------------------------------------------------------------------
PRINT_NIBBLE:   
            push    af              ; We won't destroy the contents of A
            and     0fh             ; Just in case...
            add     a,'0'           ; If we have a digit we are done here.
            cp      '9' + 1         ; Is the result > 9?
            jr      c, PRINT_NIBBLE_1
            add     a,'A' - '0' - $a  ; Take care of A-F
PRINT_NIBBLE_1:
            call    AC_TX_CHAR      ; Print the nibble and
            pop     af              ; restore the original value of A
            
            ret

;---------------------------------------------------------------------
; Convert a single character contained in A to upper case:
;---------------------------------------------------------------------
TO_UPPER:
            cp      'a'             ; Nothing to do if not lower case
            ret     c
            cp      'z' + 1         ; > 'z'?
            ret     nc              ; Nothing to do, either
            and     5fh             ; Convert to upper case
            
            ret

#include    "acia.asm"

;---------------------------------------------------------------------
; RAM/ROM 'constants'
;---------------------------------------------------------------------

MSG_DONE    .db     "Transfer complete.", CR, LF, 0
MSG_ERROR_1 .db     " <-Syntax error!", CR, LF, 0
MSG_ERROR_2 .db     "Checksum error!", 0
MSG_INTRO_1 .db     "Intel hex file loader v1.1", CR, LF, 0
MSG_INTRO_2 .db     "Send file when ready. Press <Esc> to quit.", CR, LF, 0
MSG_QUIT    .db     "Quitting program.", CR, LF, 0
           
            .end
