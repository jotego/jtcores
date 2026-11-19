# Gradius 3

You have just got an expensive $1,700 PCB according to eBay. You have in your hands a faithful conversion of the circuits on the Gradius III PCB to FPGA. If you come from the emulation world here are some of the things different from emulators:

- Real CPU/GPU bus sharing with delays
- Sprites handled with DMA exactly as in the original hardware
- Graphics priority handled by the original PROM
- No lag between image and input. Data is being sent to the screen in real time.
- Precise sound sampling rate
- Accurate FPS 100% same as real hardware

These technical aspects mean that the game play will be different from an emulator in a number of ways and that some hardware tricks that were not emulated will work here as in the original hardware.

# CPU Bus Timing

On the sub CPU, a J21 ALS74 pair clocked by the CPU clock and preset by AS delays DTACK for ROM1-3 (04'0000-0F'FFFF) and the graphics ROM readback: 1 wait state. ROM0, RAM and the interrupt register acknowledge directly from the decoder.

These wait states were derived from the schematics and have not been checked on a PCB yet.

# Acknowledgments

This core owns much to the PCB schematics work from Skutis and the initial draft submitted by Fulvio.