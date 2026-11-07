# JTNARC, FPGA core for Williams' NARC (1988)

By Chris Watson. Made from Williams' schematics and manuals for the Z-unit board, the TMS34010 User's Guide and
the PLD dumps in the ROM set.

## Supported Games

- NARC (rev 7.00)
- NARC (rev 6.00, 4.00, 3.20, 2.00 and 1.80)

## Controls

8-way joystick, Fire, Jump, Rocket Bomb and Crouch for each player. Service mode is in the OSD, or on a button
mapped to Service.

## Platform

MiSTer only, the video RAM is in the DE10-Nano's DDR3.

The CPU is [TMS34010_sv](https://github.com/birdybro/TMS34010_sv) by Kevin Coleman.
