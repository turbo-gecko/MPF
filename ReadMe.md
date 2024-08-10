# MPF

The MicroProfessor MPF-1 is one of the original Z80 trainers. It was a trainer that I suspect a lot of original Z80 coders first learned how to program the Z80, and it was my first introduction to programming the Z80. There is a multitude of information about the MPF-1 on the 'net so won't repeat it here.

With a more recent desire to go back and re-learn the Z80, I have managed to get hold of a couple of MPF=1's to relieve the experience. In hindsight. I can see just how limited the MPF-1 actually is. Part of it's issues for me are:
- Getting software on and off of the MPF-1 is via the keyboard or cassette tape.
- An incredibly tiny amount of RAM. Ideal for teaching the basics but not much else.
- Not a lot of options exist for expanding the capabilities of the MPF-1.

This repo is for the hardware and software I have developed for the MPF-1 (and other clones) that help overcome these drawbacks.

## How to expand the MPF-1
The following section descibes how to expand the capabilities of the MPF-1 to make use modern conveniences like serial download, SD card storage etc.

![MPF-1 with expansion](https://github.com/turbo-gecko/MPF/blob/main/MPF-1%20with%20RCBus.jpg)

A non-negotiable goal though, is to provide expandability without modification to the original kit. The MPF-1 is after all, a piece of vintage computer equipment, and to physically modify it would take away from it's value as a piece of history. The following expansions make use of the Z80 CPU bus that is the top left 2x20 pin header connector.

The expansion bus of choice that works very well with the MPF-1 is the retro modern RCBus by Small Computer Central, and the RC2014 bus. An adapter card is required to connect the MPF-1 to the expansion bus and the designs are included in the Z80 Bus to RCBus folder.

### Basic expansion bus
A basic expansion bus will require as a minimum:
- RCBus backplane. The one in the photo is an SC112 https://smallcomputercentral.com/sc112-modular-backplane-rc2014/
- A power supply for the backplane. The one in the photo is an SC142 that has been modified to switch the incoming 9VDC to the MPF-1. This allows a single switch to power on/off the complete system. https://smallcomputercentral.com/sc142-power-module-rc2014/
- 40 pin ribbon cable to connect the MPF-1 to the backplane via the adapter.

This provides the necessary backplane, power and connectivity to expand the MPF-1.

### Adding additional memory
The MPF-1 comes with 2K of RAM fitted from 1800H to 1FFFH. This is insufficient for use with an expansion bus so the first card that should be optained is a memory expansion card with a minimum of 32K such as:
- The 64K RAM module at https://z80kits.com/shop/64k-ram-module/. This is the module that is fitted in the backplane in the photo's. It has been configured to provide RAM from 4000H through to FFFFH, an additional 48K!
- Another module that I have experimented with is the Paged RAM module at https://smallcomputercentral.com/sc150-paged-ram-module-rc2014/. This can provide 32K from 8000H to FFFFH.

### High speed serial
The main way to enter programs into the MPF-1 is via the keypad as machine code. Whilst it is how the MPF-1 was envisaged to be used, it is a painfully slow and error-prone way of transferring programs to the MPF-1.

The expansion bus allows a serial card to be added and along with a hex download program, can make downloading hex files to the MPF-1 very easy and straightforward. The serial card in the photo's is an ACIA single serial card. https://smallcomputercentral.com/sc139-serial-68b50-module-rc2014/

### SD card storage
The only way to load and save programs with the MPF-1 is via audio files, traditionally on tape. Whilst there are modern ways around this, it is very slow, and you would need a program to convert compiled programs to an audio format.

To store and load files using an SD card only requires an I/O card and an Adafruit style SD card adapter. The I/O card in the photo is an SC129 https://smallcomputercentral.com/sc129-digital-i-o-rc2014/.

### Putting it all together
In the Software/Option ROM/ folder https://github.com/turbo-gecko/MPF/tree/main/Software/Option%20ROM is a binary file of an EPROM image that has the following software ready to run:
- 2000H - Hex download program.
- 2222H - Memory finder program.
- 2400H - Mini SD card reader program for loading files from slots 0-9 on the first SD carc virtual disk.

Burn the binary image to a 2732 EPROM and place it in the U7 socket on the MPF-1.

### Configuration

#### Serial
The software has been designed to work with an ACIA serial card only (more in the works) at I/O address C8H. The hex load and SD card programs are designed to use the serial card at 115kbps with RTS/CTS handshaking. There is further information on the serial card at https://github.com/turbo-gecko/MPF/tree/main/Software/Hex%20Load

#### SD Card
The I/O card should be configured to use address FDH.

Pin configurations as follows:
| I/O | Pin | Description |
| --- | --- | ----------- |
| In  |  7  | MISO        |
| Out |  0  | MOSI        |
| Out |  1  | CLK         |
| Out |  2  | CS          |

Make sure that the SD card module is designed to run off 5VDC and has the 3V3 reg on board to drive the SD card correctly.

![Expansion Bus](https://github.com/turbo-gecko/MPF/blob/main/RCBus-1.jpg)

### Using the expansion cards
Once you have everything up and running, including the U7 ROM, you can try using the hex load program at 2000H to download the 'HELPUS' example (helpus.hex) from https://github.com/turbo-gecko/MPF/tree/main/Software/Work%20Book%20Examples. Download the hex file and run the program at 1800H.


### Troubleshooting
- Start with the backplane, power supply and ribbon cable first. Make sure that when both the backplane and the MPF-1 is powered on, the MPF-1 works as normal.
- Power off the system, add the expansion cards one at a time, power back on and confirm the MPF-1 is working. If it isn't check
  - The ribbon cable is connected correctly. Pin 1 on the MPF-1 is at the top, Pin 1 on the adapter card is towards the 45 degree angle on the PCB. (See photo for details)
  - The expansion card is seated correctly in the backplane.
  
