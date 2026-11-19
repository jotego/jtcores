# JTRIDERS FPGA core Compatible with Konami's Sunset Riders hardware

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

- Sunset Riders
- TMNT Turtles in Time
- Lightning Fighters (Trigon)
- Golfing Greats

Due to limitations in the internal RAM memory of small FPGA devices, Golfing Greats will not run on MiST/SiDi FPGAs and TMNT2 will not work on SiDi.

# Game Configuration

This game does not use DIP switches but a small EEPROM to save the configuration. Access to the configuration by pressing F2 on your keyboard or pressing button 1 and coin in the Analogue Pocket. Follow the game menu to alter the configuration from that point on.

# Board Differences

Game           | Object Chipset            | Sound Chipset             | Remarks
---------------|---------------------------|---------------------------|---------------------
xmen		   | 053246/053247             | 054539/054321             | same object chipset as simpsons
ssriders       | 053244/053245             | 053260                    | objects like parodius. Protection chip for object RAM

# CPU Bus Timing

Sunset Riders, TMNT2 and Golfing Greats acknowledge ROM, work RAM and the other regions with AS (a combinational PAL on PWB 352359C): no wait states.

Accesses to the 052109 tile RAM wait for its PQ clock (3 MHz). The access starts on the first PQ rising edge after the data strobe (F15A 74LS74, clocked by PQ and set while no data strobe is active) and completes on the next PQ falling edge. Reads reach DTACK one 48 MHz clock later than writes. This is a board wait, so the core does not recover those CPU clocks.

The 053990 DMA masters the bus with the same DTACK logic, so DTACK keeps working while it owns the bus. DMA ownership only freezes the recovery of lost CPU clocks.

## PCB Check

The bus timing was measured on the PCB with a PicoROM-based test that times loops of 256 iterations of four accesses (issue #230). Without waits, a loop takes 42 CPU clocks; each wait state on the four accesses adds 4.

Access (CPU clocks per loop) | Sunset Riders PCB | Golfing Greats PCB | Core
-----------------------------|-------------------|--------------------|------
ROM, work RAM, palette       | 42                | 42                 | 42
Object RAM                   | 42                | -                  | 42
Golfing Greats ADC (0x123000)| -                 | 42                 | 42
052109 tile RAM read         | 64.1              | 65.8               | 64.1
052109 tile RAM write        | 72.1              | 73.5               | 72.1

The Golfing Greats ADC takes no wait states on the PCB, although the 7F ALS74 chain on the schematic suggested one.
