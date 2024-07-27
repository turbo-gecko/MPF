# SD Card memory storage system - Mem-SDS

The Mem-SDS is a minimal block storage sytem for use with an SD card, that is used for the basic functionality of saving/loading copies of memory to/from an SD card. This is not a 'file' system in the traditional sense and has no capabilities for recognising different file types. There are numerous solutions already available for use as a traditional file system.

Note 1: This code is written for "type 02" or SDHC cards.
Note 2: Whilst there are many similarities to the TEC-FS for the TEC-1G, the 2 formats are not compatible with each other.

## Basic Features
- Maximum of 64k of memory stored as a memory image in a 'slot' on a disk.
- Supports up to 128 slots per virtual disk.
- Up to 8 virtual disks per SD card.
- Save & load any contiguous area of memory.
- Up to 20 character, free form text description.

## Disk Structure
The disk structure is designed to keep minimal compatability with windows computers, such that if the SD Card is plugged into a PC, nothing "bad" will happen to either the PC or the data. At this stage, inserting the SD card will prompt Windows to format the SD - simply choose cancel.

| Sector  | Purpose  |
| ------- | -------- |
| 0       | MBR      |
| 1..63   | not used |
| 64..79  | FCB      |
| 80..127 | not used |
| 128     | file #1  |
| 256     | file #2  |
| 384     | file #3  |
| 512     | File n   |

## MBR Structure
The signature is used to verify that the virtual disk on the SD Card is formatted as a Mem-SDS disk.

| Offset | Length | Field              | Type   | Value                   |
| ------ | ------ | ------------------ | ------ | ----------------------- |
| 0      | 6      | signature          | string | "MEMSDS"                |
| 6      | 20     | volume label       | ASCIIZ | "Mem SDS Disk        "  |
| 26     | 7      | date & time        | DS1302 | 00,00,01,01,01,01,00    |
| 33     | 1      | filename sectors   | binary | 16                      |
| 34     | 412    | spare              | binary | all 00                  |
| 446    | 64     | partiton table     | binary | all 00                  |
| 510    | 2      | signature          | binary | 55 AA                   |
|        | 512    | total bytes        |        |                         |

## FCB Structure
An FCB is a File Control Block - used to keep track of each slot's attributes.

A start address of FFFF indicates the file is not in use.

Table Version is to be incremented as new FCB parameters are added, so future software can identify the save version accordingly.

The expand byte is for future use - indicates if the EXPAND memory is what has been saved. An Expand save would be 32k; TEC bank 2/Expand=0 followed by TEC bank 2/Expand=1

| Offset | Length | File FCB entry   | Type   | Default Value           |
| ------ | ------ | ---------------- | ------ | ----------------------- |
| 0      | 20     | Filename         | ASCIIZ | "SLOT 000            "  |
| 20     | 2      | start address    | binary | FFFFh                   |
| 22     | 2      | length           | binary | 0000h                   |
| 24     | 1      | reserved         | binary | 0                       |
| 25     | 7      | date & time      | DS1302 | 00,00,01,01,01,01,00    |
| 32     | 4      | start SD Sector  | binary | 00000000                |
| 36     | 2      | \# of SD Sectors | binary | 0000                    |
| 38     | 1      | reserved         | binary | 0                       |
| 39     | 24     | spare            | binary | all 00                  |
| 63     | 1      | table version    | binary | 00                      |
|        | 64     | total bytes      |        |                         |


## DateTime Structure
Follows the DS1302 regster set. All times are always saved and read in 24 hour format. All values are stored in BCD format.

| Offset | Length | Field              | Type   | Default Value        |
| ------ | ------ | ------------------ | ------ | -------------------- |
| 26     | 7      | date & time        | DS1302 | 00,00,01,01,01,01,00 |

| Offset | Length | Field     | Type   | Value                   |
| ------ | ------ | ----------| ------ | ----------------------- |
| 26     | 1      | second    | byte   | 00-59                   |
| 27     | 1      | minute    | byte   | 00-59                   |
| 28     | 1      | hour      | byte   | 00-23 (0100 hours, 1am) |
| 29     | 1      | date      | byte   | 01-31                   |
| 30     | 1      | month     | byte   | 01-12 (01 January)      |
| 31     | 1      | day       | byte   | 01-07 (01-07 Mon-Sun)   |
| 32     | 1      | year      | byte   | 00-99 (20xx)            |

----

## The Math

For each disk:

512 bytes per sector - SD Cards (and virtually all block based storage media) all support this sector size by default.

1 MBR sector

64 bytes per FCB Entry; 512/64 = 8 FCBs per sector

128 files per device

128/8 = 16 FCB sectors required

64k per file (maximum)

64k/512 = 128 sectors per file (maximum)

63+48=111 spare sectors

total storage capacity required: 1 + 63 + 16 + 48 + (128*128) = 16512 sectors needed

** just over 8Mb of space per disk required **

