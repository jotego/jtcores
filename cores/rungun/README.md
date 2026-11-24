# JTRUNGUN FPGA core Compatible with Konami's Run and Gun hardware

By Jose Tejada (@topapate)

You can show your appreciation through
* [Patreon](https://patreon.com/jotego)
* [Paypal](https://paypal.me/topapate)
* [Github](https://github.com/sponsors/jotego)

# CPU Bus Timing

PAL 056541 acknowledges every region combinationally except the 053936 ROM readback (40'0000-47'FFFF), which waits for 2WDT: AS shifted through the U205 LS175 on the CPU clock, 2 wait states. An N-stage chain started by AS gives N-1 wait states.

These wait states were derived from the schematics and have not been checked on a PCB yet. The program ROM sockets are too close to fit the PicoROM test setup.
