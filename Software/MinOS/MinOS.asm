; ----------------------------------------------------------------------------
; MinOS.asm
; Version: 0.4
; Last updated: 28/07/2024
;
; Minimal OS for the MPF-1 trainer.
;
; Requires:
;	- Acia serial board such as the SC-139 from Small Computer Central
;	- 32K RAM/FRAM from 8000H to FFFFH
;
; ----------------------------------------------------------------------------
; Recommended memory usage:
; - Program code at C000h for general usage
; - Program variables at E000h
; ----------------------------------------------------------------------------

	.org 0c000h			; Start of code in RAM

	call spiInit

	call SER_INIT			; Enable the serial port

	call sendCrLf

	ld hl,introMsg1			; Display intro messages
	call SER_TX_LINE

	ld hl,introMsg2
	call SER_TX_LINE

	ld a,0				; Select disk 0
	call selectDisk

mainLoop:
	call sendCursor			; Display cursor
	call getLine			; Get command

	jr c,mainEscape			; If <ESC> pressed, don't process 
					; command

	call sendCrLf
	call commandMenu		; Process command

	jr mainLoop			; Go again

mainEscape:
	call sendCrLf
	jr mainLoop

; ----------------------------
; App version info
; ----------------------------
swVerMsg	.db "Version 0.4",0
swInfoMsg	.db "Prototype build",0

; ----------------------------------------------------------------------------
; INCLUDE libraries
; ----------------------------------------------------------------------------

; ----------------------------------------------------------------------------
#include "string.asm"
#include "acia.asm"
#include "MinOS_sd.asm"

; ============================================================================
; App functions
; ============================================================================

; ----------------------------------------------------------------------------
; checkSD
; Checks to see if we have a valid SD card
;
; Input:	None
; Output:	Carry flag set on error, cleared on success
; Destroys:	None
; ----------------------------------------------------------------------------
checkSD:
	call sdInit			; Initialise the SD card
	jr nc,_checkSDOK
	call sdErrMsg			; Display error message

	scf
	ret				; Return error

_checkSDOK:
	scf
	ccf
	ret				; Return success

; ----------------------------------------------------------------------------
; checkSDHC
; Checks to see if we have an SDHC card
;
; Input:	None
; Output:	Carry flag set on error, cleared on success
; Destroys:	None
; ----------------------------------------------------------------------------
checkSDHC:
	call checkSD			; Initialise and check for an SD card
	jr nc,_checkSDHCOK1

	scf
	ret				; Return error

_checkSDHCOK1:
	call isSDHC			; Check for an SDHC card
	jr nc,_checkSDHCOK2
	call sdErrMsg			; Display error message if not

	scf
	ret				; Return error

_checkSDHCOK2:
	scf
	ccf
	ret				; Return success

; ----------------------------------------------------------------------------
; commandMenu
; Processes the command entered at the command line prompt.
;
; Input:	HL -- Pointer to null terminated ASCII string in cmdLineBuff
; Output:	None
; Destroys:	A, BC, DE, HL
; ----------------------------------------------------------------------------

commandMenu:
	ld hl,cmdLineBuff		; 'del' command
	ld de,cmdDel
	ld b,3
	call strCompare
	jp nc,doCmdDel

	ld hl,cmdLineBuff		; 'dir' command
	ld de,cmdDir
	ld b,3
	call strCompare
	jp nc,doCmdDir

	ld hl,cmdLineBuff		; 'disk' command
	ld de,cmdDisk
	ld b,4
	call strCompare
	jp nc,doCmdDisk

	ld hl,cmdLineBuff		; 'format' command
	ld de,cmdFormat
	ld b,6
	call strCompare
	jp nc,doCmdFormat

	ld hl,cmdLineBuff		; 'hwinfo' command
	ld de,cmdHwInfo
	ld b,6
	call strCompare
	jp nc,doCmdHwInfo

	ld hl,cmdLineBuff		; 'load' command
	ld de,cmdLoad
	ld b,4
	call strCompare
	jp nc,doCmdLoad

	ld hl,cmdLineBuff		; 'mem' command
	ld de,cmdMem
	ld b,3
	call strCompare
	jp nc,doCmdMem

	ld hl,cmdLineBuff		; 'quit' command
	ld de,cmdQuit
	ld b,4
	call strCompare
	jp nc,doCmdQuit

	ld hl,cmdLineBuff		; 'ren' command
	ld de,cmdRen
	ld b,3
	call strCompare
	jp nc,doCmdRen

	ld hl,cmdLineBuff		; 'save' command
	ld de,cmdSave
	ld b,4
	call strCompare
	jp nc,doCmdSave

	ld hl,cmdLineBuff		; 'sdinfo' command
	ld de,cmdSdInfo
	ld b,6
	call strCompare
	jp nc,doCmdInfo

	ld hl,cmdLineBuff		; 'sector' command
	ld de,cmdSector
	ld b,6
	call strCompare
	jp nc,doCmdSector

	ld hl,cmdLineBuff		; 'ver' command
	ld de,cmdVer
	ld b,3
	call strCompare
	jp nc,doCmdVersion

	ld hl,cmdLineBuff		; 'vol' command
	ld de,cmdVol
	ld b,3
	call strCompare
	jp nc,doCmdVolume

	ld hl,cmdLineBuff		; '?' command
	ld de,cmdHelp
	ld b,1
	call strCompare
	jp nc,doCmdHelp

	ld hl,cmdLineBuff		; 'd1' command
	ld de,cmdDev1
	ld b,2
	call strCompare
	jp nc,doCmdDev1

	ld hl,cmdLineBuff		; 'd2' command
	ld de,cmdDev2
	ld b,2
	call strCompare
	jp nc,doCmdDev2

	ld hl,cmdLineBuff		; 'd3' command
	ld de,cmdDev3
	ld b,2
	call strCompare
	jp nc,doCmdDev3

	ld hl,cmdLineBuff		; 'd4' command
	ld de,cmdDev4
	ld b,2
	call strCompare
	jp nc,doCmdDev4

	ld hl,cmdInvalidMsg		; Must be an invalid command...
	call SER_TX_LINE

	scf
	ccf
	ret				; ...but don't quit

; ----------------------------------------------------------------------------
; doCmdDel
; Deletes a file from the SD card.
;
; Input:	None
; Output:	None
; Destroys:	A, BC, DE, HL, IY
; ----------------------------------------------------------------------------
doCmdDel:
	call checkSDHC			; Check that it is an SDHC card
	ret c

	call validateFormat		; SD present and formatted?
	ret c

	ld hl,selSlotMsg		; Prompt for slot number
	ld (selectMsgPtr),hl

	call selectSlot			; Get slot number
	jp c,_dclQuit		; Bail out if invalid slot number

	ld a,c				; Update slot number
	ld (slotNumber),a

	call deleteFile			; Delete the file

	call sendCrLf

	scf
	ccf
	ret

; ----------------------------------------------------------------------------
; doCmdDir
; Displays the list of files stored on the SD card. It does not print out
; file information for empty slots.
;
; Input:	None
; Output:	None
; Destroys:	A, BC, HL
; ----------------------------------------------------------------------------
doCmdDir:
	call checkSDHC			; Check that it is an SDHC card
	ret c

	call validateFormat
	ret c				; Bail if bad SD

	call getVolLabel		; Display the volume label
	call SER_TX_LINE

	ld hl,dirHeaderMsg		; Display the directory header line
	call SER_TX_LINE

	ld hl,0				; Start with slot 0
	ld (slotNumber),hl

_dcdiNextSlot:
	ld a,l
	call readSlotFCB		; Get the file info
	jr c,_dcdiMainLoop		; If the slot is an empty file then skip slot

	ld a,13				; Otherwise send a carriage return
	call SER_TX_CHAR

	call SER_TX_LINE		; And display the file details

_dcdiMainLoop:
	ld hl,(slotNumber)		; Move to the next slot
	inc hl
	ld a,l
	cp 128				; Check to see if we have iterated through all
	jr z,_dcdiDone			; 128 slots
	ld (slotNumber),hl

	ld a,l				; And display . as a progress bar for every 4th
	and 03h				; slot
	cp 0
	jr nz,_dcdiNextSlot

	ld a,'.'
	call SER_TX_CHAR
	
	jr _dcdiNextSlot			; Go again

_dcdiDone:
	call sendCrLf			; Dir listing is complete so time to exit cmd

	scf
	ccf
	ret				; Successful command execution

; ----------------------------------------------------------------------------
; doCmdDisk
; Prompts for and changes to selected disk.
;
; Input:	None
; Output:	None
; Destroys:	Any
; ----------------------------------------------------------------------------
doCmdDisk:
	call checkSDHC			; Check that it is an SDHC card
	ret c				; Bail if no card

	ld hl,curDiskMsg1		; Display the current disk in use
	call SER_TX_STRING

	ld a,0ffh
	call selectDisk

	ld de,wordStrBuff
	call aToString

	ld a,0
	ld (de),a

	ld hl,wordStrBuff
	call SER_TX_STRING

	ld hl,curDiskMsg2
	call SER_TX_LINE

	ld hl,selDiskMsg		; Display select disk prompt
	call SER_TX_STRING

	call getLine			; Get disk number
	jr nc,_dcdkCont1
	ld hl,badParamMsg
	call SER_TX_LINE
	ld a,0ffh
	scf
	ret

_dcdkCont1:
	call sendCrLf

	call strDecToNum		; Make sure it is a valid number
	jr nc,_dcdkCont2		; Yes, then continue
	ld hl,badParamMsg		; No, then tell the user and abort
	call SER_TX_LINE
	ld a,0ffh

	scf				; Set carry flag as an error state
	ret

_dcdkCont2:
	call selectDisk

	scf
	ccf
	ret

; ----------------------------------------------------------------------------
; doCmdFormat
; Formats the SD card.
;
; Input:	None
; Output:	None
; Destroys:	A, BC, HL
; ----------------------------------------------------------------------------
doCmdFormat:
	call checkSDHC			; Check that it is an SDHC card
	ret c

	ld hl, ruSureMsg		; Display 'Are you sure messages'
	call SER_TX_LINE
	ld hl, formatSureMsg1
	call SER_TX_LINE
	ld hl, anyKeyQuitMsg
	call SER_TX_LINE

	call SER_RX_CHAR
	cp 'F'				; Check for F key pressed
	jp z, _dcftFormatSD		; Go ahead and format

	scf
	ccf
	ret				; Otherwise we don't want to format

_dcftFormatSD:
	call sendCrLf			; Clear the line
	ld hl,formatMsg
	call SER_TX_LINE

	call sdFormatCard		; Format the SD card
	ret c

	ld hl,formatOkStr		; And display format ok message
	call SER_TX_LINE

	scf
	ccf
	ret

; ----------------------------------------------------------------------------
; doCmdHelp
; Displays the help message
;
; Input:	None
; Output:	None
; Destroys:	HL
; ----------------------------------------------------------------------------
doCmdHelp:
	ld hl,helpMsg
	call SER_TX_LINE

	scf
	ccf
	ret

; ----------------------------------------------------------------------------
; doCmdHwInfo
; Displays the SD card hardware information.
;
; Input:	None
; Output:	None
; Destroys:	A, BC, HL
; ----------------------------------------------------------------------------
doCmdHwInfo:
	call checkSD			; Initialise the SD card
	ret c

	call getCID			; get the SD card hw info
	jp nz,sdError
	
	ld hl,cidMIDMsg			; Display Manufacturer ID message
	call SER_TX_STRING

	call getMID			; Get the MID
	call SER_TX_LINE
	
	ld hl,cidOIDMsg			; Display OEM ID message
	call SER_TX_STRING

	call getOID			; Get the OID
	call SER_TX_LINE
	
	ld hl,cidPNMMsg			; Display part name message
	call SER_TX_STRING
	
	call getPNM			; PNM - product name (see SD card Spec)
	call SER_TX_LINE

	ld hl,cidPRVMsg			; Display part revision number message
	call SER_TX_STRING

	call getPRN			; Get the part revision number
	call SER_TX_LINE

	ld hl,cidPSNMsg			; Display part serial number
	call SER_TX_STRING
	
	call getPSN			; Get the part serial Number
	call SER_TX_LINE

	ld hl,cidMDTMsg			; Display manufacturing date
	call SER_TX_STRING

	call getMDT
	call SER_TX_LINE

	scf
	ccf
	ret

; ----------------------------------------------------------------------------
; doCmdInfo
; Displays the SD card formatting info
;
; Input:	None
; Output:	None
; Destroys:	A, BC, HL, IX
; ----------------------------------------------------------------------------
doCmdInfo:
	call checkSDHC			; Check that it is an SDHC card
	ret c

	call validateFormat
	ret c

	ld hl,diskLabel			; Get the disk volume label
	call SER_TX_STRING

	call getVolLabel
	call SER_TX_LINE

	ld hl,cardCapacity		; Show maximum files message
	call SER_TX_STRING

	call getMaxFiles		; Get the maximum number of files that
					; will fit on the SD card.
	ld l,a
	ld h,0
	ld ix,decimalBuff
	call decimal
	xor a				; Null terminate result
	ld (ix),a	
	ld hl,decimalBuff		; Display the max files
	call SER_TX_LINE

	scf
	ccf
	ret

; ----------------------------------------------------------------------------
; doCmdLoad
; Loads a file from the SD card and copies the file contents to RAM.
;
; Input:	None
; Output:	None
; Destroys:	A, BC, DE, HL, IY
; ----------------------------------------------------------------------------
doCmdLoad:
	call checkSDHC			; Check that it is an SDHC card
	ret c

	call validateFormat		; SD present and formatted?
	ret c

;	ld hl,setLoadSlot		; Prompt for slot number
;	ld (selectMsgPtr),hl

	call selectSlot			; Get slot number
	jp c,_dclQuit			; Bail out if invalid slot number

	push af
	ld a,c				; Update slot number
	ld (slotNumber),a
	pop af

	ld (fcbOffset),a		; Calculate offset in the FCB
	call calcOffset			; sets up IY register

	ld l,(iy+FCB_START_ADDR)	; Start in memory, FFFF = no file
	ld h,(iy+FCB_START_ADDR+1)	; Start in memory, FFFF = no file

	ld de,0ffffh			; 16-bit CP
	or a
	sbc hl,de
	add hl,de
	jr nz,_dclValid			; Continue if valid load address

	ld hl,noFileMsg			; Error if selecting empty slot
	call SER_TX_LINE

	scf
	ccf
	ret

_dclValid:
	push bc
	push hl
	push iy

	call sendCrLf

	ld a,(slotNumber)
	call readSlotFCB		; Get the file info
	call SER_TX_LINE

;	ld hl,loadingMsg
	pop iy
	pop hl
	pop bc

	ld a,(slotNumber)		; Go read the file and transfer to RAM
	call readFile

	scf
	ccf
	ret

_dclQuit:
	ld hl,badParamMsg		; Display bad parameter message...
	call SER_TX_LINE

	scf
	ccf
	ret				; ...and quit

; ----------------------------------------------------------------------------
; doCmdMem
; Prompts for a memory location and displays the hex dump for 512 bytes from
; that location
;
; Input:	None
; Output:	None
; Destroys:	A, BC, HL
; ----------------------------------------------------------------------------
doCmdMem:
	ld hl,memMsg
	call SER_TX_STRING

	call getLine			; Get memory location
	jr nc,_dcmCont1
	ld hl,badParamMsg
	call SER_TX_LINE
	ld a,0ffh
	jr _dcmError

_dcmCont1:
	call sendCrLf

	call strHexToNum		; Make sure it is valid memory
	jr nc,_dcmCont2			; Yes, then continue
	ld hl,badParamMsg		; No, then tell the user and abort
	call SER_TX_LINE
	ld a,0ffh
	jr _dcmError

_dcmCont2:
	push bc				; Save memory location

	ld hl,memBlockMsg
	call SER_TX_STRING

	call getLine			; Get block size
	jr nc,_dcmCont3
	ld hl,badParamMsg
	call SER_TX_LINE
	ld a,0ffh
	jr _dcmError

_dcmCont3:
	call sendCrLf

	call strHexToNum		; Make sure it is a valid block size
	jr nc,_dcmCont4			; Yes, then continue
	ld hl,badParamMsg		; No, then tell the user and abort
	call SER_TX_LINE
	ld a,0ffh
	jr _dcmError

_dcmCont4:
	ld a,b
	add a,c
	cp 0
	jr z,_dcmError

	pop iy
	call showBlock

	scf
	ccf
	ret

_dcmError:
	pop iy

	scf				; Set carry flag as an error state
	ret

; ----------------------------------------------------------------------------
; doCmdQuit
; Quits the program!
;
; Input:	None
; Output:	None
; Destroys:	None
; ----------------------------------------------------------------------------
doCmdQuit:
	call beep
	rst 00h

	ret 				; We want to quit the program

; ----------------------------------------------------------------------------
; doCmdRen
; Renames a file on the SD card.
;
; Input:	None
; Output:	None
; Destroys:	A, BC, DE, HL, IY
; ----------------------------------------------------------------------------
doCmdRen:
	call checkSDHC			; Check that it is an SDHC card
	ret c

	call validateFormat		; SD present and formatted?
	ret c

	ld hl,selSlotMsg		; Prompt for slot number
	ld (selectMsgPtr),hl

	call selectSlot			; Get slot number
	jp c,_dclQuit		; Bail out if invalid slot number

	ld a,c				; Update slot number
	ld (slotNumber),a

	call sendCrLf

	ld hl,getFileNameMsg		; Prompt for filename
	call SER_TX_STRING

	call getLine			; Get filename
	jr nc,_dcrCont1			; Check for valid filename length
	
	scf
	ccf
	ret

_dcrCont1:
	push bc

	ld a,c				; Get the number of chars in the string
	cp DESC_SIZE			; If it is more than 20 chars then
	ret nc				; the string is too long

	ld de,fileNameBuff		; Clear the file name buffer
	ld a,' '
	ld b,DESC_SIZE

_dcrCont2:
	ld (de),a
	inc de
	djnz _dcrCont2

	ld de,fileNameBuff
	pop bc
	ldir

	ld de,fileNameBuff
	ex de,hl

	ld a,(slotNumber)

	call renameFile

	call sendCrLf

	scf
	ccf
	ret

; ----------------------------------------------------------------------------
; doCmdSave
; Saves a block of RAM as a file to the SD card.
;
; Input:	None
; Output:	None
; Destroys:	A, BC, DE, HL
; ----------------------------------------------------------------------------
doCmdSave:
	call checkSDHC			; Check that it is an SDHC card
	ret c

	call validateFormat		; SD present and formatted?
	ret c

	ld hl,4000h			; Default save parameters
	ld (transferStart),hl
	ld hl,7fffh
	ld (transferEnd),hl

_dcsGetAddr:
	ld hl,blkStartMsg		; Get start address message
	call SER_TX_STRING

	call getLine			; Get the address
	call sendCrLf
	call strHexToNum		; and covert to a number
	jr c,_dcsGetAddr		; Carry indicates an error so go again
	ld (transferStart),hl

	ld hl,blkEndMsg			; Get end address
	call SER_TX_STRING

	call getLine			; Get the address
	call sendCrLf
	call strHexToNum		; and covert to a number
	jr c,_dcsGetAddr		; Carry indicates an error so go again
	ld (transferEnd),hl

	ld hl,(transferEnd)		; Validate parameters
	ld bc,(transferStart)
	or a				; 16-bit CP
	sbc hl,bc
	add hl,bc
	jp z,_dcsBadParam		; Retry if equal
	jp c,_dcsBadParam		; Retry if end<start

	sbc hl,bc			; Fix up subtraction
;	inc hl				; +1 start address itself counts
	ld (transferLength),hl		; Parameters set

	call selectSlot			; Prompt for and get slot number
	jp c,_dcsQuit

	ld a,c				; Update slot number
	ld (slotNumber),a

	call sendCrLf

	ld hl,getFileNameMsg		; Prompt for filename
	call SER_TX_STRING

	call getLine			; Get filename
	jr nc,_dcsCont1			; Check for valid filename

	call sendCrLf

	jp _dcsQuit

_dcsCont1:
	push bc

	ld a,c				; Get the number of chars in the string
	cp DESC_SIZE			; If it is more than 20 chars then
	ret nc				; the string is too long

	ld de,fileNameBuff		; Clear the file name buffer
	ld a,' '
	ld b,DESC_SIZE

_dcsCont2:
	ld (de),a
	inc de
	djnz _dcsCont2

	ld de,fileNameBuff
	pop bc
	ldir

	ld de,fileNameBuff
	ex de,hl

	push hl
	call sendCrLf
	pop hl

	ld de,(transferStart)		; Set up parameters for writing the file
	ld bc,(transferLength)
	ld a,(slotNumber)

	call writeFile			; ...and do it

	ld hl,saveOkMsg
	call SER_TX_LINE

	scf
	ccf
	ret				; Successful command execution

_dcsQuit:
	ld hl,badParamMsg		; Display bad parameter message...
	call SER_TX_LINE

	scf
	ccf
	ret				; ...and quit

_dcsBadParam:
	ld hl,badParamMsg		; Display bad parameter...
	call SER_TX_LINE

	jp doCmdSave			; ...and try again

; ----------------------------------------------------------------------------
; doCmdSector
; Prompts for a sector number and displays the hex dump for that sector
;
; Input:	None
; Output:	None
; Destroys:	A, BC, HL
; ----------------------------------------------------------------------------
doCmdSector:
	call checkSD			; Initialise the SD card
	ret c

	ld hl,sectorMsg
	call SER_TX_STRING

	call getLine			; Get sector number
	jr nc,_dcstCont1
	ld hl,badParamMsg
	call SER_TX_LINE
	ld a,0ffh
	scf
	ret

_dcstCont1:
	call sendCrLf

	call strDecToNum		; Make sure it is a valid number
	jr nc,_dcstCont2		; Yes, then continue
	ld hl,badParamMsg		; No, then tell the user and abort
	call SER_TX_LINE
	ld a,0ffh

	scf				; Set carry flag as an error state
	ret

_dcstCont2:
	call showSector

	scf
	ccf
	ret

; ----------------------------------------------------------------------------
; doCmdVersion
; Display the software version information
;
; Input:	None
; Output:	None
; Destroys:	HL
; ----------------------------------------------------------------------------
doCmdVersion:
	ld hl,swVerMsg			; Display sw version info
	call SER_TX_LINE
	
	ld hl,swInfoMsg			; Display sw build type
	call SER_TX_LINE

	scf
	ccf
	ret				; Successful command execution

; ----------------------------------------------------------------------------
; doCmdVolume
; Display the current disk volume label
;
; Input:	None
; Output:	None
; Destroys:	HL
; ----------------------------------------------------------------------------
doCmdVolume:
	call getVolLabel		; Get the volume label
	call SER_TX_LINE

	ld hl,getNewVolMsg		; Prompt for a new volume label
	call SER_TX_STRING

	call getLine
	ret c				; Return on error
	call sendCrLf

	call writeVolLabel		; Write the new label

	scf
	ccf
	ret				; Successful command execution

; ----------------------------------------------------------------------------
; getAddress
; Retrieves from serial port a 4 character ASCII hex number and returns the
; hex equivalent in HL
;
; Input:	None
; Output:	HL -- Hex equivalent of the 4 digit ASCII hex number
; Destroys:	A, BC, DE, HL
; ----------------------------------------------------------------------------
getAddress:
	ld de,paramStrBuff
	ld b,4

_gaLoop:
	call SER_RX_CHAR			; Get command

	ld (de),a
	inc de

	call SER_TX_CHAR			; Digit found, echo digit

	djnz _gaLoop

	call sendCrLf

	ld hl,0
	ld a,(paramStrBuff)

	ld d,a
	call hexToNum
	ret c
	add a,a
	add a,a
	add a,a
	add a,a
	ld h,a

	ld a,(paramStrBuff + 1)

	ld d,a
	call hexToNum
	ret c
	add a,h
	ld h,a

	ld a,(paramStrBuff + 2)

	ld d,a
	call hexToNum
	ret c
	sla a
	sla a
	sla a
	sla a
	ld l,a

	ld a,(paramStrBuff + 3)

	ld d,a
	call hexToNum
	ret c
	add a,l
	ld l,a

	scf
	ccf
	ret

hexToNum
	ld a,d
	sub '0'
	cp 10
	jr nc,upCase			; Test for upper case alpha char
	scf
	ccf
	ret

upCase
	ld a,d
	sub 'A'
	cp 7
	jr nc,lowCase			; Test for lower case alpha char
	add a,10
	scf
	ccf
	ret

lowCase
	ld a,d
	sub 'a'
	cp 7
	jr nc,invalidChar		; Must be an invalid char
	add a,10
	scf
	ccf
	ret

invalidChar
	ld hl,0ffffh			; Set hl to a known value
	scf				; Set carry flag as an error
	ret

; ----------------------------------------------------------------------------
; getLine
; Reads the serial port until a CR/LF or ESC is pressed.
; The returned string will not have the CR/LF or ESC as it will be replaced
; with a null character to terminate the string.
;
; Input:	None
; Output:	BC -- Number of characters entered, not including terminators
;		HL -- Pointer to null terminated ASCII string
;		Carry flag set on <Esc> key press or empty string
; Destroys:	A, BC, HL
; ----------------------------------------------------------------------------
getLine:
	ld hl,cmdLineBuff		; Point HL to the command line buffer

_glLoop:
	push hl
	call SER_RX_CHAR		; Get character from the serial port
	pop hl

	cp 8				; Backspace
	jp z,_glBackspace

	cp 10				; Line feed
	jp z,_glStringOK

	cp 13				; Carriage return
	jp z,_glStringOK

	cp 27				; Escape key
	jp z,_glEscape

	push af				; Display the character
	call SER_TX_CHAR
	pop af

	ld (hl),a			; Store the character
	inc hl
	jr _glLoop

_glBackspace:
	push hl
	ld de,cmdLineBuff
	sbc hl,de
	ld a,l
	pop hl
	or a
	jr z,_glLoop

	ld a,8				; Erase the character
	call SER_TX_CHAR

	ld a,' '
	call SER_TX_CHAR

	ld a,8
	call SER_TX_CHAR

	ld (hl),0			; Insert a null character
	dec hl
	jr _glLoop

_glStringOK:
	ld (hl),0			; Null terminate the string

	ld bc,cmdLineBuff
	sbc hl,bc
	push hl
	pop bc

	ld hl,cmdLineBuff		; Restore the string pointer

	ld a,c				; Check for empty string
	and a
	jr z,_glEscape

	scf
	ccf				; Indicate successful input
	ret

_glEscape:
	ld bc,0				; Clear character count
	ld (hl),0			; Null terminate empty string

	scf				; Indicate error/no input
	ret

; ----------------------------------------------------------------------------
; selectSlot
; Prompts user for a valid slot number between 0 and 127.
; 
; Input:	None
; Output:	A -- Old style slot number (0-7) or 0FFH = cancel
;		BC -- Slot number (0-127)
; 		Carry flag set if no card detected or invalid number
; Destroys:	A, BC, HL
; ----------------------------------------------------------------------------
selectSlot:
	ld hl,selectSlotMsg		; setup correct message
	call SER_TX_STRING
	
	call getLine			; Get slot number
	jr nc,_ssCont
	ld hl,badParamMsg
	call SER_TX_LINE
	ld a,0ffh
	scf
	ret

_ssCont:
	call strDecToNum		; Make sure it is a valid number
	jr nc,_ssCont1			; Yes, then continue
	ld hl,badParamMsg		; No, then tell the user and abort
	call SER_TX_LINE
	ld a,0ffh

	scf				; Set carry flag as an error state
	ret

_ssCont1:
	push bc
	ld a,c				; Validate slot number
	cp 128				; Check if greater than 127
	jr c,_ssCont2			; No, then continue
	ld hl,badParamMsg		; Yes, then tell the user and abort
	call SER_TX_LINE
	ld a,0ffh
	pop bc

	scf				; Set carry flag as an error state
	ret
	
_ssCont2:
	ld hl,64			; Get first FCB into buffer
	and 0F8h			; Determine the sector offset
	srl a
	srl a
	srl a
	add a,l
	ld (currSector),a

	call readSdSector		; Read the slot's sector into the buffer
	call spiInit

	pop bc
	ld a,c				; Fix A to old style slot number
	and 07h

	ret

; ----------------------------------------------------------------------------
; sendCrLf
; Sends a CR/LF pair to the serial port
;
; Input:	None
; Output:	None
; Destroys:	A, BC
; ----------------------------------------------------------------------------
sendCrLf:
	ld a, 13
	call SER_TX_CHAR

	ld a, 10
	call SER_TX_CHAR

	ret

; ----------------------------------------------------------------------------
; sendCursor
; Sends a cursor '>' character to the serial port
;
; Input:	None
; Output:	None
; Destroys:	A, BC
; ----------------------------------------------------------------------------
sendCursor:
	ld a, CURSOR
	call SER_TX_CHAR			; Display cursor

	ret

; ----------------------------------------------------------------------------
; showBlock
; Displays a 512 byte block
;
; Input:	BC - Size of the block to display
;		IY -- Pointer to 512 byte block of memory
; Output:	None
; Destroys:	A, BC, DE, HL, IY
; ----------------------------------------------------------------------------
showBlock:
	ld (blockSize),bc		; Store the block size

	ld hl,sectorHdr			; Set up the output line buffer with
	ld de,cmdLineBuff		; the header
	ld bc,74
	ldir

	ld de,0				; Initialise vars
	ld (blockOffset),de
	ld (lineOffset),de
	ld hl,cmdLineBuff

_sbkLoop:
	ld a,e				; Check to see if 16th byte
	and 0fh
	jr z,_sbkLoop2

	ld a,e				; Check to see if 8th byte
	and 07h
	jr nz,_sbkLoop1

	ld hl,(lineOffset)
	ld (hl),' '			; Print an extra space before the hex value
	inc hl
	ld (lineOffset),hl
	
_sbkLoop1:
	ld hl,(lineOffset)
	ld (hl),' '			; Print a space before the hex value
	inc hl
	ld (lineOffset),hl
	
	jr _sbkLoop3

_sbkLoop2:				; Routine looks at beginning of new line
	ld hl,cmdLineBuff		; Tidy up the tail of the current line
	ld a,74
	ld b,0
	ld c,a
	adc hl,bc
	ld (hl),0

	ld hl,cmdLineBuff
	call SER_TX_LINE		; Print the line

	ld hl,cmdLineBuff		; Clear the line... <-debug
	ld (hl),' '
	ld de,cmdLineBuff+1
	ld bc,73
	ldir

	ld hl,cmdLineBuff		; Reset HL to beginning of new output line
	ld (hl),'+'
	inc hl
	ld (lineOffset),hl

	ld hl,(blockOffset)		; Get the current block offset
	ld de,wordStrBuff		; Temporary buffer
	call hlToString			; Convert to string

	ld hl,wordStrBuff		; Point HL to the converted string
	ld de,(lineOffset)		; Point DE to the output line
	ld bc,4				; Copy 4 characters
	ldir

	ld hl,(lineOffset)		; Move up to the next place in the line
	inc hl
	inc hl
	inc hl
	inc hl

	ld a,':'			; Print a colon after the sector offset
	ld (hl),a
	inc hl

	ld a,' '			; Followed by a space
	ld (hl),a
	inc hl

	ld (lineOffset),hl

_sbkLoop3:
	ld a,(iy)			; Convert the current value to ASCII hex
	ld de,wordStrBuff
	call aToString

	ld hl,wordStrBuff		; Point HL to the converted string
	ld de,(lineOffset)		; Point DE to the offset in the output line
	ld bc,2				; Copy 2 characters
	ldir

	ld hl,(lineOffset)		; Move up to the next place in the line
	inc hl
	inc hl
	ld (lineOffset),hl

	ld a,(iy)			; Convert the current value to ASCII char
	cp 20h				; ASCII printable?, ' ' and up to...
	jr nc,_sbkLoop4
	ld a,'.'			; Not an ASCII printable char, change to '.'
	jr _sbkLoop5

_sbkLoop4:
	cp 7fh				; ...end of ASCII printable chars
	jr c,_sbkLoop5
	ld a,'.'			; Not an ASCII printable char, change to '.'

_sbkLoop5:
	push af				; Calculate where to put the char at the end
	ld de,(blockOffset)		; of the line
	ld a,e
	and 0fh
	add a,58

	ld b,0
	ld c,a
	ld hl,cmdLineBuff
	adc hl,bc
	pop af
	ld (hl),a			; Write the char to the line

_sbkLoop6:
	inc iy
	
	; *** This code doesn't do anything other than prevent a subtle bug when displaying
	; the last byte in the block. Removing this code brings the bug back !?! ***
	ld a,0fh
	call aToNibble
	; *** ----------

	ld de,(blockOffset)
	inc de
	ld (blockOffset),de

	ld hl,(blockSize)
	sbc hl,de			; End of the block?
	jr z,_sbkEnd
	jp _sbkLoop

_sbkEnd:
	ld hl,cmdLineBuff
	call SER_TX_LINE

	call sendCrLf

	scf
	ccf
	ret

; ----------------------------------------------------------------------------
; showSector
; Displays a 512 byte sector
;
; Input:	BC -- Sector number
; Output:	None
; Destroys:	A, BC, HL, IY
; ----------------------------------------------------------------------------
showSector:
	ld (currSector),bc		; Save the sector number

	call readSdSector		; Go read the sector

	ld iy,sdBuff			; Pointer to the sector data
	ld bc,512			; Size of a disk block
	call showBlock

	ret

; ----------------------------------------------------------------------------
; showTimeStamp
; Fetch timestamp from buffer and output to the serial port
;
; Input:	IY -- Base pointer to 7 byte timestamp block
; Output:	None
; Destroys:	A, BC, DE, HL
; ----------------------------------------------------------------------------
showTimeStamp:
	; ld h,(iy + OFS_DATE)		; Get the date values
	; ld l,(iy + OFS_MONTH)
	; ld e,(iy + OFS_YEAR)
	; ld d,20h
	
	; push iy
	; ld iy,paramStrBuff
	; ld b,formatDate			; Format the date values
	; ld c,_RTCAPI
	; rst 10h
	; pop iy
	
	; ld hl,paramStrBuff		; Output the date to the serial port
	; call SER_TX_STRING

	; ld a, ' '			; Print a space between date and time
	; call SER_TX_CHAR

	; ld b,formatTime
	; ld c,_RTCAPI

	; ld h,(iy + OFS_HOUR)		; Get the time values
	; ld l,(iy + OFS_MINUTE)
	; ld d,(iy + OFS_SECOND)
	
	; push iy
	; ld iy,paramStrBuff		; Format the time values
	; rst 10h
	; pop iy
	
	; ld hl,paramStrBuff		; Output the time to the serial port
	; call SER_TX_LINE

	ret

; ----------------------------------------------------------------------------
; validateFormat
; Checks to see if SD card is formatted by finding MBR signature
;
; Input:	None
; Output:	Carry flag set if not a valid MBR, clear if valid
; Destroys:	HL
; ----------------------------------------------------------------------------
validateFormat:
	call isFormatted		; Is the SD card formatted?
	jr nc,_vfOK
	call sdErrMsg			; Display error message

	scf
	ret				; Return error

_vfOK:
	scf
	ccf
	ret				; Return success

; ----------------------------------------------------------------------------
; beep
; Sends a beep tone to the speaker
;
; Input:	None
; Output:	Beep tone
; Destroys:	A, BC, DE, HL
; ----------------------------------------------------------------------------
beep:
	ld hl,BEEP_LENGTH
	call _TONE1K

	ret

; ----------------------------------------------------------------------------
; Error Handling Routines
; ----------------------------------------------------------------------------
sdErrMsg:
	call SER_TX_LINE
	call spiInit

	ret

sdError:
	ld de,sdErrorStrNum		; save error code
	call aToString
	xor a
	ld (de),a
	ld hl,sdErrorStr
	call SER_TX_LINE
	ld hl,sdErrorStrNum

sdErr2:	call SER_TX_LINE
	call spiInit
	halt
	ret

; ----------------------------------------------------------------------------
; doCmdDev1
; Developer command.
;
; Input:	None
; Output:	None
; Destroys:	Any
; ----------------------------------------------------------------------------
doCmdDev1:
	; call checkSDHC			; Check that it is an SDHC card
	; ret c				; Bail if no card

	ret

; ----------------------------------------------------------------------------
; doCmdDev2
; Developer command.
;
; Input:	None
; Output:	None
; Destroys:	Any
; ----------------------------------------------------------------------------
doCmdDev2:
	; call checkSDHC			; Check that it is an SDHC card
	; ret c				; Bail if no card

	ret

; ----------------------------------------------------------------------------
; doCmdDev3
; Developer command.
;
; Input:	None
; Output:	None
; Destroys:	Any
; ----------------------------------------------------------------------------
doCmdDev3:
	; call checkSDHC			; Check that it is an SDHC card
	; ret c				; Bail if no card

	ret

; ----------------------------------------------------------------------------
; doCmdDev1
; Developer command.
;
; Input:	None
; Output:	None
; Destroys:	Any
; ----------------------------------------------------------------------------
doCmdDev4:
	ret

SD_PROG_END:
#include "MinOS_inc.asm"

	.end

