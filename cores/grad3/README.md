# Gradius 3

You have just got an expensive $1,700 PCB according to eBay. You have in your hands a faithful conversion of the circuits on the Gradius III PCB to FPGA. If you come from the emulation world here are some of the things different from emulators:

- Real CPU/GPU bus sharing with delays
- Sprites handled with DMA exactly as in the original hardware
- Graphics priority handled by the original PROM
- No lag between image and input. Data is being sent to the screen in real time.
- Precise sound sampling rate
- Accurate FPS 100% same as real hardware

These technical aspects mean that the game play will be different from an emulator in a number of ways and that some hardware tricks that were not emulated will work here as in the original hardware.

# Acknowledgments

This core owns much to the PCB schematics work from Skutis and the initial draft submitted by Fulvio.