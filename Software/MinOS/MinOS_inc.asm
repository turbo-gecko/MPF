; ----------------------------------------------------------------------------
; MinOS_inc.asm
; Version: 1.0
; Last updated: 04/08/2024
;
; Include file for the MPF-1 MinOS
; ----------------------------------------------------------------------------

; ----------------------------
; Constants
; ----------------------------

; MPF-1 API Calls
#ifdef MPF-1
_HEX7		.equ	0689h		; Convert a hex digit to 7 seg display format
_HEX7SG		.equ	0678h		; Convert 2 hex digits to 7 seg display format
_RAMCHECK	.equ	05f6h		; Check if the given address is in RAM
_SCAN		.equ	05feh		; Scan keyboard and display until a new key-in
_SCAN1		.equ	0624h		; Scan keyboard and display one cycle
_TONE		.equ	05e4h		; Generate sound
_TONE1K		.equ	05deh		; Generate sound at 1kHz
_TONE2K		.equ	05e2h		; Generate sound at 2kHz

BEEP_LENGTH	.equ	80h
#endif

; Terminal
CURSOR		.equ '>'

; ----------------------------

introMsg1	.db "MinOS - Mini OS for Z80 systems",0
introMsg2	.db "Type '?' for help, press <ESC> to abort command entry",0

helpMsg		.db "Command help",13,10
		.db "del    - Deletes a slot",13,10
		.db "dir    - Directory listing",13,10
		.db "disk   - Change selected disk",13,10
		.db "format - Format disk on SD card",13,10
		.db "hwinfo - Displays SD card hardware information",13,10
		.db "load   - Load slot from the SD card",13,10
		.db "mem    - Display the contents of a block of memory",13,10
		.db "quit   - Quit program",13,10
		.db "ren    - Rename a slot",13,10
		.db "save   - Save memory to the SD card",13,10
		.db "sdinfo - Displays disk information",13,10
		.db "sector - Display the contents of a 512 byte SD sector",13,10
		.db "ver    - Display version information",13,10
		.db "vol    - Update the current disks volume label",13,10
		.db "?      - Displays this help text",13,10
		.db 0

cmdDel		.db "del",0
cmdDir		.db "dir",0
cmdDisk		.db "disk",0
cmdFormat	.db "format",0
cmdHwInfo	.db "hwinfo",0
cmdSdInfo	.db "sdinfo",0
cmdLoad		.db "load",0
cmdMem		.db "mem",0
cmdQuit		.db "quit",0
cmdRen		.db "ren",0
cmdSave		.db "save",0
cmdSector	.db "sector",0
cmdVer		.db "ver",0
cmdVol		.db "vol",0
cmdHelp		.db "?",0

cmdDev1		.db "d1",0
cmdDev2		.db "d2",0
cmdDev3		.db "d3",0
cmdDev4		.db "d4",0

cmdInvalidMsg	.db "Not a valid command",0

dirHeaderMsg	.db "Slot "
		.db "Description         "
		.db "Start "
		.db "Length ",0

cidMIDMsg	.db "MID           : ",0
cidOIDMsg	.db "OID           : ",0
cidPNMMsg	.db "Card Name     : ",0
cidPRVMsg	.db "Revision      : ",0
cidPSNMsg	.db "Serial Number : ",0
cidMDTMsg	.db "Date (M/Y)    : ",0

cardCapacity	.db "Maximum Files : ",0
diskLabel	.db "Disk Label    : ",0

getFileNameMsg	.db "Filename      : ",0
getNewVolMsg	.db "Enter new volume : ",0
memMsg		.db "Mem location (hex) : ",0
memBlockMsg	.db "Block size (hex)   : ",0
selectSlotMsg	.db "Select slot   : ",0
sectorMsg	.db "Sector        : ",0
sectorHdr	.db "       "
		.db "00 01 02 03 04 05 06 07  "
		.db "08 09 0A 0B 0C 0D 0E 0F   "
		.db "0123456789ABCDEF"

anyKeyQuitMsg	.db "Any other key quits",0
badParamMsg	.db "Bad Parameters!!",0
blkEndMsg	.db "End address   : ",0
blkStartMsg	.db "Start address : ",0
curDiskMsg1	.db "Disk ",0
curDiskMsg2	.db " is active",0
delSureMsg	.db "Press <D> to delete",0
formatMsg	.db "Formatting Disk ",0
formatOkStr	.db "Format Completed",0
formatSureMsg1	.db "Press <F> to format",0
loadingMsg	.db "Loading file:",0
noFileMsg	.db "(Empty Slot)",0
ruSureMsg	.db "Are you sure?",0
saveOkMsg	.db "File save complete! ",0
sdErrorStr	.db "SD Card Error ",0
selDiskMsg	.db "Select disk (0-7) ",0
selectMsg	.db "File List        :",0
selSlotMsg	.db "Select slot      :",0

startAddr	.db "Start ",0

wordStr		.db "    ",0

; ----------------------------------------------------------------------------
;		.org 0e000h

blockOffset	.block 2
blockSize	.block 2
cmdLineBuff	.block 80
fileNameBuff	.block 20
lineOffset	.block 2
sdErrorStrNum	.block 3
selectMsgPtr	.block 2
slotNumber	.block 2
transferEnd	.block 2
transferLength	.block 2
transferStart	.block 2
wordStrBuff	.block 5


; ----------------------------------------------------------------------------
; sd data
; ----------------------------------------------------------------------------
cidBufferPtr	.dw			; Pointer to the CID buffer

sdInitRetry	.db 0			; Keeps track of init retry counter
sdCIDInit	.db 0			; if 0, the CID info of the SD card
					; has not been retrieved, or a new
					; retrieval is requested.

sdBuff		.block 512+2		; 512b + CRC16

addrStart	.block 2
byteBuff	.block 5
currSector	.block 2
currSlot	.block 1
decimalBuff	.block 7
dirStrBuff	.block DIR_END + 1	
diskOffset	.block 2
fcbOffset	.block 1
fcbToUpdate	.block 2
fileEnd		.block 2
fileLength	.block 2
fileStart	.block 2
memBlockSize	.block 2
memPos		.block 2
numSectors	.block 2
numStrBuff	.block 6
paramStrPtr	.block 2
paramStrBuff	.block 21		; 20 char + null paramater string 
					; buffer
spiCMD17var	.block 6
spiCMD24var	.block 6
slotOffset	.block 1
startSector	.block 2

; ---------------------------- SD CID register
sdCIDRegister
sdcidMID	.block 1		; Manufacturer ID
sdcidOID	.block 2		; OEM/Application ID
sdcidPNM	.block 5		; Product name
sdcidPRN	.block 1		; Product revision
sdcidPSN	.block 4		; Product serial number
sdcidMDT	.block 2		; Manufacturing date
sdcidCRC	.block 1		; CRC7

; ---------------------------- FCB data structure
; This is the raw FCB data for a file, able to be individually referenced
fcbDescription	.block 20
fcbStartAddress .block 2
fcbLength	.block 2
fcbExpand	.block 1
fcbDateTime	.block 7
fcbStartCector	.block 4
fcbSectorCount	.block 2
fcbFileType	.block 1

; ------------------------------------------------------------- ;
; If at this point in the listing file, the address is greater  ;
; than FD00H then this program will overwrite the MinSD memory  ;
; area and will not be compatible with MinSD.                    ;
; ------------------------------------------------------------- ;
