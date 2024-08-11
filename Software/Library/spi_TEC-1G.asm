; ----------------------------------------------------------------------------
; spi_TEC-1G.asm
; Version: 1.0
; Last updated: 11/08/2024
;
; Hardware SPI driver specifically for the TEC-1G Micro SD Card & General
; Input/Output Kit.
; ----------------------------------------------------------------------------

; ----------------------------------------------------------------------------
; SPI Ports
SPI_PORT_IN	.equ 0fdh		; IO port for MISO
SPI_PORT_OUT	.equ 0fdh		; IO port for MOSI, CLK and CS

; ----------------------------------------------------------------------------
; SPI port pins are fixed for this module. Do not change the pin designations.
SPI_MISO	.equ 7			; Pin 7
SPI_MOSI	.equ 0			; Pin 0
SPI_CLK		.equ 1			; Pin 1
SPI_CS		.equ 2			; Pin 2

; ----------------------------------------------------------------------------
; SD card constants
RESET_CLK_COUNT	.equ 80
SD_INIT_RETRIES	.equ 10

; ----------------------------------------------------------------------------
; spiIdle
; Set the SPI to the idle state.
; call once at start of code, and again to return SPI to idle
;
; idle state = CS high, CLK low, MOSI high
;
; Input:	None
; Output:	None
; Destroys:	None
; ----------------------------------------------------------------------------
spiIdle:
	push af

	xor a				; Clear A register
	set SPI_CS,a			; CS = high
	set SPI_MOSI,a			; MOSI = high
	out (SPI_PORT_OUT),a		; Set the pins

	pop af

	ret

; ----------------------------------------------------------------------------
; spiInit
; Initialises the hardware port(s) for the SPI bus
;
; Input:	None
; Output:	None
; Destroys:	None
; ----------------------------------------------------------------------------
spiInit:
	ret				; No initialisation required.

; ----------------------------------------------------------------------------
; spiRdb
; Reads one byte from the SPI bus and returns the result in A
;
; Input:	None
; Output:	A -- Byte read from SPI
; Destroys:	A
; ----------------------------------------------------------------------------
spiRdb:
	push bc
	push de

	ld e,0				; Clear the result
	ld b,8				; 8 bits to read

	xor a				; Clear A register
	res SPI_CS,a			; CS = low
	set SPI_MOSI,a			; MOSI = high

	out (SPI_PORT_OUT),a		; CS active low
	nop

_srBit:
	set SPI_CLK,a			; Set CLK
	out (SPI_PORT_OUT),a

	ld c,a				; Backup a
	in a,(SPI_PORT_IN)		; Bit d7
	rla				; Bit 7 -> carry
	rl e				; Carry -> E bit 0
	ld a,c				; Restore a

	res SPI_CLK,a			; Clear CLK
	out (SPI_PORT_OUT),a

	djnz _srBit

	ld a,e

	pop de
	pop bc
	ret

; ----------------------------------------------------------------------------
; spiReset
; Routine to reset the SPI bus for use with an SD card
;
; Input:	None
; Output:	None
; Destroys:	A
; ----------------------------------------------------------------------------
spiReset:
	call spiIdle			; Set SD interface to idle state

	ld b,RESET_CLK_COUNT		; Toggle clk 80 times

_spiToggle:
	out (SPI_PORT_OUT),a
	set SPI_CLK,a			; Set CLK
	out (SPI_PORT_OUT),a
	nop
	res SPI_CLK,a			; Clear CLK
	out (SPI_PORT_OUT),a
	djnz _spiToggle

	call spiIdle

	ret

; ----------------------------------------------------------------------------
; spiWrb
; Transmit one byte to the SPI bus
;
; Input:	C -- Byte to send
; Output:	None
; Destroys:	None
; ----------------------------------------------------------------------------
spiWrb:
	push af
	push bc
	ld b,8				; 8 bits to send

_swBit:
	xor a				; Clear A register
	res SPI_CS,a			; CS = low
	set SPI_MOSI,a			; MOSI = high
	bit 7,c				; Check to see if the next bit is a 1
	jr nz,_swBitSend
	res SPI_MOSI,a			; No, set the MOSI pin low

_swBitSend:
	out (SPI_PORT_OUT),a		; Setup data bit
	set SPI_CLK,a			; Set CLK
	out (SPI_PORT_OUT),a
	nop
	res SPI_CLK,a			; Clear CLK
	out (SPI_PORT_OUT),a
	rlc c				; Get next bit
	djnz _swBit

	pop bc
	pop af
	ret

