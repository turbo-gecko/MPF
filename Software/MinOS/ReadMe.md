# MinOS - Minimal OS for the MPF-1 (and others)
MinOS is a simple serial console program that enables blocks of memory to be saved to an SD card, and read from an SD card. It is designed to sit at the top of memory from E000H. To do this, the memory and serial port expansion is required which is discussed at https://github.com/turbo-gecko/MPF/tree/main

The SD card memory storage system used by MinOS is described at https://github.com/turbo-gecko/MPF/blob/main/Software/Mem_SDS.md

This is a list of the commands available:
```
MinOS - Mini OS for Z80 systems
Type '?' for help, press <ESC> to abort command entry
>?
Command help
del    - Deletes a slot
dir    - Directory listing
disk   - Change selected disk
format - Format disk on SD card
hex    - Run the hex load program
hwinfo - Displays SD card hardware information
load   - Load slot from the SD card
mem    - Display the contents of a block of memory
quit   - Quit program
ren    - Rename a slot
run    - Run a program at a memory location
save   - Save memory to the SD card
sdinfo - Displays disk information
sector - Display the contents of a 512 byte SD sector
ver    - Display version information
vol    - Update the current disks volume label
?      - Displays this help text

>
```

MinOS is able to be configured for different trainers, serial cards and IO for the SD card. It is reasonably straight forward to add a new serial card or IO card by adding a new driver for the device and adding the options in MinOS.asm.

The hex file MinOS.hex is prebuilt for an ACIA serial card at 0C8H and and genral prupose IO card at 0FDH with 32K RAM expansion from 8000H to FFFFH.
