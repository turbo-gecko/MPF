# MPF-1 ROM
The file mpf-1.asm is a line accurate reproduction of the source code listed in MPSL.pdf (MPF-I monitor program source listing (DOC.NO.:M1002-8412A)).

Compilation of this file has been done with TASM and it generates both a line accurate listing file and a 100% binary duplicate
of the ROM in my MPF-1.

There are some minor differences in formatting and style, and some of the comments have been corrected for spelling and grammer.

I have posted this asm file, as the contents of the source code has already been published in the above MPSL.pdf document. 
If this is in violation of the wishes of the owner (Multitech Industrial Corp.) then it will be immediately removed on notification.
Research would indicate that Flite Electronics Ltd is the current owner of the IP for the MPF-1. (flite.co.uk).

# MPF-1-MOD ROM
This is designed to be used with the U7 option ROM at https://github.com/turbo-gecko/MPF/tree/main/Software/Option%20ROM

## v1.0
- Removed redundant tape read/write code.
- Relocated RST00 code to free up access to RST08, 10, 18, and 20. This allows use of the RST calls for use by the user.
  - RST 08H is a jump to 2FF0H in the option ROM
  - RST 10H is a jump to 2FF4H in the option ROM
  - RST 18H is a jump to 2FF8H in the option ROM
  - RST 20H is a jump to 2FFCH in the option ROM
- TAPE RD calls 2000H in the option ROM. This is where the hex load program resides.
- TAPE WR calls 2400H in the option ROM. This is where the SD loader program resides.
