# Serial port and hex loader for MPF-1
The original MPF-1 has no serial port as the expectation at the time was for students to enter their code via the keypad, and to save and load programs via cassette tape.

I wanted to be able to use a serial port but not make modifications to a museum piece so I used the following to avoid making mods:
- The adapter I designed for use with the TEC-1G (![see here](https://github.com/turbo-gecko/TEC/tree/main/Hardware/Z80%20to%20RC%20Bus%20Adapter))
- The [SC139 – Serial 68B50 Module (RC2014)](https://smallcomputercentral.com/sc139-serial-68b50-module-rc2014/) by Stephen cousins at Small Computer Central
- A backplane card also by Stephen Cousins at Small Computer Central. Please note that the one I used in the photo is overkill. Something like the [SC147 - Modular Backplane (RC2014)](https://smallcomputercentral.com/sc147-modular-backplane-rc2014/) would be more suitable. Stephen also sells some good power modules for powering the backplane as there is no +5V available on the MPF-1 expansion header. 

Photo's of the hardware...

![Photo 1](https://github.com/turbo-gecko/MPF/blob/main/Software/Hex%20Load/20240411_175707.jpg)
![Photo 2](https://github.com/turbo-gecko/MPF/blob/main/Software/Hex%20Load/20240411_175727.jpg)

**acia.asm** is the device driver for the serial card. Note that the default port in the code is 0C8H. If you use a different port, AC_P_BASE will need to be changed accordingly. There is also a loopback test program that can be enabled to test the board on it's own. For the MPF-1, the .org address of 4000H would need to be changed to something like 1800H.
If the supplied 7.3728 MHz crystal is used as the clock for the SC-139, this will equate to 115,200 bps. I have used a 2.4576 MHz crystal on my SC-139 which equates to 38,400 bps which seems to be about the max for a <4 MHz Z80. Either way, the driver supports RTS signalling for RTS/CTS hardware flow control.

**hex-load.asm** is a simple Intel hex file loader that can be used to transfer Intel hex files via the ACIA card to the MPF-1. 
The hex-load.hex file is ready to be burned into an EPROM for the U7 socket. Once burned and installed, go to address 2000H and press 'GO'. On the serial terminal will be displayed...

    Intel hex file loader v1.1
    Send file when ready. Press <Esc> to quit.

From the serial terminal program, send a text file such as 'helpus.hex' from the Work Book Examples folder and the download will be echoed to the terminal. 

    :0C180000DD212018CDFE05FE1320F97636
    :06182000AEB51F858F37F5
    :00000001FF

When done, a 'Transfer complete' message will be display and the program will exit.

    Transfer complete.

Enjoy!
