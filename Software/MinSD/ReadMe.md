# MinSD

MinSD is a stripped down SD card memory image loader, designed to fit into the U7 option ROM.

The program loads a program from a slot on the SD card into memory, without having to download the file over the serial port, or key in from the keyboard.

The main use case is for loading MinOS to enable full use of the Mem-SDS SD card storage system. In this capacity, MinSD is performing the role of a boot-strap program for MinOS, however it is also a quick way to load other programs from any of the first 10 slots of the virtual disk 0.

MinSD should be burned to an EPROM and placed in the U7 ROM socket.
It occupies less than 1K of memory in the ROM and uses less than 1K of RAM starting from F000H.

The file U7-Utils.bin at https://github.com/turbo-gecko/MPF/tree/main/Software/Option%20ROM is a binary file ready for burning into a 2732 EPROM. The programs in the ROM include:
- 2000H - Hexload program for downloading hex files to the MPF-1
- 2222H - RAM Finder that displays the memory locations wehere RAM is found.
- 2400H - MinSD program described on this page.

Note: Additional RAM is required for the program, and it has been designed to make use memory in the upper 32K of RAM. This requires the use of a 32K to 64K RAM board to be fitted to the MPF-1 usually via the 40 pin Z80 bus header.

## Basic Features
- Able to load any of the first 10 slots (0-9) of virtual disk 0 on a Mem-SDS SD card into memory.
- Uses the 7 segment display and key pad for the UI
- Displays the load start address on a successful load.
- Displays an 'Empty' message if an empty slot is chosen.
- Displays error messages for no card, wrong card type and not formatted card.

## Instructions
- Press **ADDR** and enter **2400**
- Press **GO**
- There will be activity on the SD card port LEDs (if fitted) for approximately 4 seconds
- Providing there is a Mem-SDS formatted disk in the SD card slot, the message **LoAd-n** will appear which is prompting for the slot number to load from.
- Press any of the **0** to **9** keys to begin loading the memory image from the corresponding slot.
- There will be more activity on the SD card port LEDs (if fitted) for a length of time proportional to the size of the memory image being loaded.
- If the load is successful, the starting address will be displayed.
- Press any key to exit the program.
