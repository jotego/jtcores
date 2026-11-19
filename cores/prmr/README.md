# JTPRMR FPGA core Compatible with Konami's Premier Soccer hardware

By Jose Tejada (@topapate)

You can show your appreciation through
* [Patreon](https://patreon.com/jotego)
* [Paypal](https://paypal.me/topapate)
* [Github](https://github.com/sponsors/jotego)

Project source code hosted at http://www.github.com/jotego/jtcores
License: GPL3, you are obligued to publish your code if you use mine

Yes, you always wanted to have an arcade board at home. First you couldn't get it because your parents somehow did not understand you. Then you grow up and your wife doesn't understand you either. Don't worry, JT cores are here to the rescue.

I hope you will have as much fun with this project as I had while working on it!

# Supported Systems

This FPGA core is compatible with the following arcade PCBs:

- Premier Soccer

This core does not fit in devices with small internal RAMs, such as MiST and SiDi.

# Game Configuration

This game has a small EEPROM to save the configuration. Access to the configuration by pressing F2 on your keyboard or pressing button 1 and coin in the Analogue Pocket. Follow the game menu to alter the configuration from that point on.

# CPU Bus Timing

8J 74LS10 asserts DTACK with AS for 00'0000-1F'FFFF, so ROM, work RAM and the other low regions take no wait states.

The PSAC ROM read (30'0000) and the watchdog (28'0000) wait for the 9G 74LS175 delay chain: AS shifted by three CPU clock rising edges, two wait states. The watchdog is decoded only for its bus wait; its reset is not modelled.

The KiCad drawing labels the A0 input of the 3G 74LS139 as A21, which would never select the 052109. The core uses A19, which matches the board's use of both outputs: the 052109 sits at 20'0000-27'FFFF and the watchdog at 28'0000-2F'FFFF.

The 052109 tile RAM select is latched on a PQ rising edge (7G 74LS74, set while no data strobe is active) and DTACK follows once PQ is low again. This is a board wait, so the core does not recover those CPU clocks.

## PCB Check

The bus timing was measured on the PCB with a PicoROM-based test that times loops of 256 iterations of four accesses (issue #230). Without waits, a loop takes 42 CPU clocks; each wait state on the four accesses adds 4.

Access (CPU clocks per loop) | PCB  | Core
-----------------------------|------|------
ROM, work RAM, palette       | 42   | 42
PSAC ROM, watchdog           | 50   | 50
052109 tile RAM read         | 57.8 | 53.4
052109 tile RAM write        | 72.0 | 72.0

Tile RAM reads are about one wait state shorter in the core than on the PCB.
