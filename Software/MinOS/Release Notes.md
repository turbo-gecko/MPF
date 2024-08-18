# Release Notes for MinOS

## Known issues or limitations

## v1.5

- Fixed issue with disk number not being validated.
- Uses new sd libraries.
- Refactored the style of the code (again!).

## v1.4

- Refactored the style of the code.

## v1.3

- Added 'hex' download command that calls the hex download program in ROM at 0DD0H.
- Added 'run' command that runs program at specified address.

## v1.2

- Added support for the KS Wichit Z80 Microprocessor Kit.

## v1.1.1

- Fixed issue with the MISO pin not being correctly mapped. It was defaulting to pin 7 irrespective of the setting of the pin number.
- Added missing call to set SPI to idle state after reading a sector.
- Added these release notes.

## v1.1.0

- Initial release
