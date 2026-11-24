# JTXMEN FPGA core Compatible with Konami's X-Men hardware

By Jose Tejada (@topapate)

You can show your appreciation through
* [Patreon](https://patreon.com/jotego)
* [Paypal](https://paypal.me/topapate)
* [Github](https://github.com/sponsors/jotego)

# CPU Bus Timing

GAL C14 asserts DTACK with AS, so ROM, work RAM and the other regions take no wait states.

The 052109 tile RAM select (~VRAM, low byte only) is latched on a PQ rising edge (E18A 74LS74, set while LDS is inactive). The access completes on the next PQ falling edge (VSC = ~VCS | PQ). Reads reach DTACK one 48 MHz clock later than writes. This is a board wait, so the core does not recover those CPU clocks. The main ROM uses a 1 kB cache so that SDRAM latency can be recovered.

## PCB Check

The bus timing was measured on the PCB with a PicoROM-based test that times loops of 256 iterations of four accesses (issue #230). Without waits, a loop takes 42 CPU clocks; each wait state on the four accesses adds 4.

Access (CPU clocks per loop)        | PCB  | Core
------------------------------------|------|------
ROM, work RAM, object RAM, palette  | 42   | 42
052109 tile RAM read (byte)         | 64.1 | 64.1
052109 tile RAM write (byte)        | 72.1 | 72.0
