# SD Card API

The Card API is for use with the following IO devices:
- Generic IO card _(Library\spi_IO.asm)_
- Z80 PIO _(Library\spi_Z80PIO.asm)_
- TEC-1G I/O SD card module _(Library\spi_TEC-1G.asm)_

Support for the various flavours of SD card is as follows:
- Early SDSC cards (up to 2GB) are **NOT** supported.
- SDHC cards (4GB to 32GB) are supported.
- SDXC cards (64GB to 2TB) are **NOT** supported.

The SD card is formatted with a unique Mem-SDS file system that comprises of up to 128 'slots' or files with can each be of up to 64kB in size. The API also supports up to 8 virtual disks per SD card. Refer to Mem_SDS.md for further details.

This API supports the formatting and file handling API's to manage the card itself, the files on the cards, and the selection of virtual disks.

The API calls are:
- sdInit #1 - Initialise communications to the SD card and checks for a compatible SD card
- getCardType #2 - Gets the type of SD card i.e., SDSC or SDHC.
- selectDisk #3 - Selects one of the virtual disks (0-7).
- readSlotFCB #4 - Gets a files directory entry.
- readFile #5 - Load a file from the SD card into RAM.
- writeFile #6 - Write a file to SD card at the specified slot.
- sdFormatCard #7 - Formats the SD card.

## sdInit #1
```
Initialise communications to the SD card and checks for a compatible SD card

Input:	 	None
Output: 	HL -- Error string if not no card detected
		Carry flag set if no card detected
Destroys: 	A, BC, HL
```

## getCardType#2
```
Check and return whether the card is SDSC or SDHC

Input:		None.
Output:		A -- 80h = SDSC, C0h = SDHC
		Carry flag set if no card detected
Destroys:	A
```

## selectDisk#3
```
Sets the global disk offset to match the requested disk. In the event of an
invalid disk number being selected, the disk will remain unchanged and the
disk number in use will be returned in A.

Input:		A -- Disk number (0-7)
Output:		A -- Disk number set, carry set on invalid disk, cleared on
		     success.
Destroys:	A
```

## readSlotFCB#4
```
Reads the FCB for the slot and returns the ASCII directory entry.
Assumes the SD card has already been initialised and is valid.

Input:		A -- Slot number (0-127).
Output:		HL -- Pointer to ASCII version of slot directory entry
		IY -- Pointer to FCB buffer
Destroys:	A, BC, DE, HL
```

## readFile#5
```
Reads a file at the specified slot and loads it at the start address
specified in the file to that RAM address.

Input:		A -- Slot number to read from (0-127)
Output:		HL -- Contains pointer to error message if read failed
		Carry flag set if file read failed, cleared if success
Destroys:	A, BC, DE, HL
```

## writeFile#6
```
Write a file to SD card at the specified slot.
Input:		A -- Slot number to write to (0-127)
		BC -- Size of the block to write
		DE -- Start address of memory block to write
		IX -- Pointer to null terminated file name
Output:		Carry flag set if file write failed, cleared if success
Destroys:	A, BC, DE, HL, IX
```

## sdFormatCard#7
```
Formats the SD card with Mem-SDS.

Input:		None.
Output:		None.
Destroys:	A, BC, DE, HL
```

