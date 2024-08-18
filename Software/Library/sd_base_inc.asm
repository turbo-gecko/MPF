; ----------------------------------------------------------------------------
; sd_base_vars.asm
; Common variables used by SD libraries.
;
; v1.0 - 17th August 2024
; ----------------------------------------------------------------------------

; ----------------------------------------------------------------------------
; Constants
; ----------------------------------------------------------------------------
SD_CLK		.equ	1
DESC_SIZE	.equ	20

; FCB offsets
FCB_START_ADDR	.equ	20
FCB_LENGTH	.equ	22
FCB_EXPAND	.equ	24
FCB_RTC		.equ	25
FCB_START_SECT	.equ	32
FCB_SECT_COUNT	.equ	36
FCB_TYPE	.equ	38
FCB_END		.equ	39

; Directory string offsets
DIR_SLOT	.equ	0
DIR_DESC	.equ	5
DIR_START	.equ	25
DIR_LENGTH	.equ	31
DIR_END		.equ	38

ERR_NO_CARD	.equ	1
ERR_NO_SDHC	.equ	2
ERR_NO_FORMAT	.equ	3

ORG_SAVE_INC:	.equ	$		; Save the current program address

; ----------------------------------------------------------------------------
; Program variables
; ----------------------------------------------------------------------------
		.org 	0fd00H

sdBuff		.block	512+2		; 512b + CRC16

addrStart	.block	2
byteBuff	.block	5
currSector	.block	2
currSlot	.block	1
decimalBuff	.block	7
dirStrBuff	.block	DIR_END + 1	
diskOffset	.block	2
dispBuff	.block	6
fcbOffset	.block	1
fcbToUpdate	.block	2
fileEnd		.block	2
fileLength	.block	2
fileNameBuff	.block	20
fileStart	.block	2
memBlockSize	.block	2
memPos		.block	2
numSectors	.block	2
numStrBuff	.block	6
paramStrPtr	.block	2
paramStrBuff	.block	21		; 20 char + null paramater string 
					; buffer
sdCIDInit	.block	1		; if 0, the CID info of the SD card
					; has not been retrieved, or a new
					; retrieval is requested.
sdInitRetry	.block	1		; Keeps track of init retry counter
selectMsgPtr	.block	2
slotNumber	.block	2
slotOffset	.block	1
spiCMD17var	.block	6
spiCMD24var	.block	6
startSector	.block	2
uiEnabled	.block	1
wordStrBuff	.block	5

; ---------------------------- SD CID register
sdCIDRegister
sdcidMID	.block	1		; Manufacturer ID
sdcidOID	.block	2		; OEM/Application ID
sdcidPNM	.block	5		; Product name
sdcidPRN	.block	1		; Product revision
sdcidPSN	.block	4		; Product serial number
sdcidMDT	.block	2		; Manufacturing date
sdcidCRC	.block	1		; CRC7

; ---------------------------- FCB data structure
; This is the raw FCB data for a file, able to be individually referenced
fcbDescription	.block	20
fcbStartAddress .block 2
fcbLength	.block 2
fcbExpand	.block 1
fcbDateTime	.block 7
fcbStartSector	.block 4
fcbSectorCount	.block 2
fcbFileType	.block 1

SD_INC_EOD	.equ	$		; Save end of data address

		.org	ORG_SAVE_INC	; Restore current program address
