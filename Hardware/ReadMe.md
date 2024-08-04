# Hardware Stuff

## Bezel - 3D Printer files
Bezel for the 7 segment display to hold the red filter lens in place.

## Z80 Bus to RCBus
Adapter card to enable the use of an RCBus or RC2014 style backplane to extend the Z80 bus of the MPF-1.

## How to expand the MPF-1
The following section descibes how to expand the capabilities of the MPF-1 to make use modern conveniences like serial download, SD card storage etc.

A non-negotiable goal though, is to provide expandability without modification to the original kit. The MPF-1 is after all, a piece of vintage computer equipment, and to physically modify it would take away from it's value as a piece of history. The following expansions make use of the Z80 CPU bus that is the top left 2x20 pin header connector.

The expansion bus of choice that works very well with the MPF-1 is the retro modern RCBus by Small Computer Central, and the RC2014 bus. An adapter card is required to connect the MPF-1 to the expansion bus and the designs are included in the Z80 Bus to RCBus folder.

### Basic expansion bus
A basic expansion bus will require as a minimum:
- RCBus backplane. The one in the photo is an SC112 https://smallcomputercentral.com/sc112-modular-backplane-rc2014/
- A power supply for the backplane. The one in the photo is an SC142 that has been modified to switch the incoming 9VDC to the MPF-1. This allows a single switch to power on/off the complete system. https://smallcomputercentral.com/sc142-power-module-rc2014/
- 40 pin ribbon cable to connect the MPF-1 to the backplane via the adapter.

This provides the necessary backplane, power and connectivity to expand the MPF-1.

### Adding additional memory
The MPF-1 comes with a tiny amount of RAM fitted from 1800H to 1FFFH.

## Troubleshooting
One of my MPF-1's was DOA when I got it. It turned out that the 4.7uF C6 had died in a short circuited state.
Replacement with an equivalent got it up and running again.

I wonder if I should replace all of the tantalum's on the board...?
