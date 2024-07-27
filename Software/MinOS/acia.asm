;---------------------------------------------------------------------
; MC6850 ACIA library
;
; A would like to acknowledge the project at
; https://github.com/bazsimarkus/Simple-6850-UART-System-with-Arduino/blob/master
; which	helped guide me	on the register	usage and how the MC6850 can
; be initialised.
;
; The code has been written to use registers only (except for the test
; code)	to enable usage	in a ROM.
;
; v1.3 - 27th July 2024
;	 Added acia agnostic function names.
; v1.2 - 21st July 2024
;	 Refactored the style of the code.
;	 Added acTxLine - Send a string with a CR/LF.
; v1.1 - 10th April 2024
;	 Added RTS signalling for HW flow control
; v1.0 - 7th April 2024
;---------------------------------------------------------------------

;---------------------------------------------------------------------
; Compiler directives
;---------------------------------------------------------------------
; Enables testing of the library. Remove comment to enable a simple
; loopback routine for testing if you are sending/receiving data from
; the MC6850.
;#define TEST_EN

;---------------------------------------------------------------------
; Constants
;---------------------------------------------------------------------
;==================
; MC6850 Addressing
; AC_P_BASE can	be changed to suit the addressing for the MC6850 as
; per the hardware implementation of the target	system.
AC_P_BASE	.equ	0c8h		; Base address for the control and data	ports

AC_P_CONT	.equ	AC_P_BASE
AC_P_DATA	.equ	AC_P_BASE + 1

;============================
; MC6850 Control Register (W)
; Baud rate selection	  **
AC_CLK1		.equ	00000000b	; CLK/1
AC_CLK16	.equ	00000001b	; CLK/16
AC_CLK64	.equ	00000010b	; CLK/64
AC_RESET	.equ	00000011b	; Master Reset

; Mode selection ***
AC_7E2		.equ	00000000b	; 7 data bits, even parity, 2 stop bits
AC_7O2		.equ	00000100b	; 7 data bits, odd parity, 2 stop bits
AC_7E1		.equ	00001000b	; 7 data bits, even parity, 1 stop bit
AC_7O1		.equ	00001100b	; 7 data bits, odd parity, 1 stop bit
AC_8N2		.equ	00010000b	; 8 data bits, no parity, 2 stop bits
AC_8N1		.equ	00010100b	; 8 data bits, no parity, 1 stop bit
AC_8E1		.equ	00011000b	; 8 data bits, even parity, 1 stop bit
AC_8O1		.equ	00011100b	; 8 data bits, odd parity, 1 stop bit

; Tx interrupt	**
AC_LR_DI	.equ	00000000b	; Output /RTS=low and disable Tx Interrupt
AC_LR_EI	.equ	00100000b	; Output /RTS=low and enable Tx	Interrupt
AC_HR_DI	.equ	01000000b	; Output /RTS=high and disable Tx Interrupt
AC_LR_DI_BR	.equ	01100000b	; Output /RTS=low and disable Tx Interrupt, and	send a Break

; Rx interrupt	*
AC_RI_DIS	.equ	00000000b	; Disable on buffer full/buffer	overrun
AC_RI_EN	.equ	10000000b	; Enable on buffer full/buffer overrun

;===========================
; MC6850 Status	Register (R)
; Status register
AC_SR_RD	.equ	0		; 00000001b Receive Data (0=No data, 1=Data can	be read)
AC_SR_TD	.equ	1		; 00000010b Transmit Data (0=Busy, 1=Ready/Empty, Data can be written)
AC_SR_DCD	.equ	2		; 00000100b /DCD level
AC_SR_CTS	.equ	3		; 00001000b /CTS level
AC_SR_FE	.equ	4		; 00010000b Receive Framing Error (1=Error)
AC_SR_OE	.equ	5		; 00100000b Receive Overun Error (1=Error)
AC_SR_PE	.equ	6		; 01000000b Receive Parity Error (1=Error)
AC_SR_IF	.equ	7		; 10000000b Interrupt Flag (see	Control	Bits 5-7) (IRQ pin is not connected)

;---------------------------------------------------------------------
; The following	parameters are the defaults for	normal usage:
;
; AC_CLK64 + AC_8N1 + AC_LR_DI + AC_RI_DIS
;
; For a	7.3728 MHz clk,	this equates to	115,200	bps. This requires
; the comms program to insert inter character delays otherwise it can
; overwhelms a <4 MHz Z80.
; For a	2.4576 MHz clk,	this equates to	38,400 bps which seems to be
; about	the max	for a <4 MHz Z80 without needing inter character
; delays.

;---------------------------------------------------------------------
; Test routine for the library
;---------------------------------------------------------------------
#ifdef TEST_EN
AC_LED_PORT	.equ	00h		; Debugging LED port

		.org	1800h

acMain:
		call acInit		; Initialise the ACIA

		ld c,AC_P_CONT		; Get the current ACIA status...
		in a,(c)

		ld hl,CR_LF		; Send a CR/LF to start	a new line
		call acTxStr

		ld hl,MSG_START		; Send test start
		call acTxStr

		ld hl,CR_LF		; Terminate with another CR/LF
		call acTxStr

acMain_1
		call acRxChar		; Perform loopback test...

		push af
		cp 1bh			; Escape key to	quit
		jr z,acMain_2

		ld c,AC_P_CONT		; Get ACIA status
		in a,(c)
		ld c,AC_LED_PORT
		out (c),a

		pop af
		call acTxChar

		jr acMain_1

acMain_2
		ld hl,CR_LF		; Send a CR/LF to start	a new line
		call acTxStr

		ld hl,MSG_END		; Send test complete
		call acTxStr

		ld hl,CR_LF		; Terminate with another CR/LF
		call acTxStr

		rst	00h

CR_LF		.db	0dh, 0ah, 0
MSG_END		.db	"ACIA loopback test complete.",0
MSG_START	.db	"ACIA loopback test. Press <Esc> to quit.",0

#endif

;---------------------------------------------------------------------
; acInit
; Initialises the ACIA to CLK/1, 8n1 and interrupts disabled
;
; Input:	None
; Output:	None
; Destroys:	A, C, DE
;---------------------------------------------------------------------
acInit:
SER_INIT:
		ld c,AC_P_CONT		; Reset	the ACIA
		ld a,AC_RESET
		out (c),a

		ld de,0100h		; Add delay for reset to take effect

acInit_1
		dec de
		ld a,d
		cp 0
		jr nz,acInit_1
		ld a,e
		cp 0
		jr nz,acInit_1

		ld c,AC_P_CONT		; Set up the ACIA configuration
		ld a,AC_CLK64 + AC_8N1 + AC_LR_DI + AC_RI_DIS
		out (c),a

		ret

;---------------------------------------------------------------------
; acRtsHigh
; Sets the RTS line to logic 1 to signal stop sending data
;
; Input:	None
; Output:	A - contains the character received
; Destroys:	A, C
;---------------------------------------------------------------------
acRtsHigh:
SER_RTS_HIGH:
		ld c,AC_P_CONT		; Set up the ACIA configuration
		ld a,AC_CLK64 + AC_8N1 + AC_HR_DI + AC_RI_DIS
		out (c),a

		ret

;---------------------------------------------------------------------
; acRtsLow
; Sets the RTS line to logic 0 to signal ready to receive data
;
; Input:	None
; Output:	A - contains the character received
; Destroys:	A, C
;---------------------------------------------------------------------
acRtsLow:
SER_RTS_LOW:
		ld c,AC_P_CONT		; Set up the ACIA configuration
		ld a,AC_CLK64 + AC_8N1 + AC_LR_DI + AC_RI_DIS
		out (c),a

		ret

;---------------------------------------------------------------------
; acRxChar
; Receives a character - uses RTS HW flow control to limit how fast
; the characters are received. As the ACIA has no buffer, the HW
; flow control is used at the start and	end of receiving every
; character.
;
; Input:	None
; Output:	A - contains the character received
; Destroys:	A, C, HL
;---------------------------------------------------------------------
acRxChar:
SER_RX_CHAR:
		call acRtsLow		; Other computer can now to send

		ld c,AC_P_CONT		; Get ACIA status

acRxChar_1
		in a,(c)	
		bit AC_SR_RD,a
		jr z,acRxChar_1		; Loop until a character is received

		ld c,AC_P_DATA		; Get byte from the RX port
		in a,(c)
		ld l,a

		call acRtsHigh		; Stop other computer from sending
		ld a,l

		ret

;---------------------------------------------------------------------
; acTxChar
; Transmits a character
;
; Input:	A -contains the character to be sent
; Output:	None
; Destroys:	A, BC
;---------------------------------------------------------------------
acTxChar:
SER_TX_CHAR:
		push af
		ld c,AC_P_CONT		; Get ACIA status

acTxChar_1
		in a,(c)
		bit AC_SR_TD,a		; Check to see if the ACIA is ready to accept data
		jr z,acTxChar_1

		ld c,AC_P_DATA		; Queue the data for sending
		pop af
		out (c),a

		ret

;---------------------------------------------------------------------
; acTxLine
; Transmits a string and terminates with a CR/LF
;
; Input:	HL - pointer to the null terminated string to be sent
; Output:	None
; Destroys:	A, C, HL
;---------------------------------------------------------------------
acTxLine:
SER_TX_LINE:
		ld a,(hl)		; Get the character from the string
		cp 0
		jr z,acTxLine_1		; Reached the end of the string
		call acTxChar
		inc hl
		jr acTxLine

acTxLine_1
		ld a,0dh		; Carriage return
		call acTxChar
		ld a,0ah		; Line feed
		call acTxChar

		ret

;---------------------------------------------------------------------
; acTxStr
; Transmits a string
;
; Input:	HL - pointer to the null terminated string to be sent
; Output:	None
; Destroys:	A, C, HL
;---------------------------------------------------------------------
acTxStr:
SER_TX_STRING:
		ld a,(hl)		; Get the character from the string
		cp 0
		jr z,acTxStr_1		; Reached the end of the string
		call acTxChar
		inc hl
		jr acTxStr

acTxStr_1
		ret

		.end
