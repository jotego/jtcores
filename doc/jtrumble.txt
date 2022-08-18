JTRumble FPGA clone of Speed Rumbler arcade faithful to original hardware
==========================================================================

Please, read the main README file too.

You have just got a middle priced €150 PCB according to eBay. You have in your hands
a faithful conversion of the circuits on the Speed Rumbler PCB to FPGA. If you come from
the emulation world here are some of the things different from emulators:

-Real CPU/GPU bus sharing with accurate delays
-Real CPU/MCU bus sharing with accurate delays
-Sprites handled with DMA exactly as in the original hardware
-Exact timing for bus sharing with microcontroller
-Graphics priority handled as the original PROMs indicate
-No lag between image and input. Data is being sent to the screen in real time.
-Sound sampling rate: exactly the original
-Accurate FPS 100% same as real hardware

These technical aspects mean that the game play will be different from an emulator
in a number of ways and that some hardware tricks that were not emulated will work
here as in the original hardware.

Hardware
========

This game has an interesting mix of hardware modules present in former and later games from CAPCOM

-Overscan screen resolution
-Basic sprite hardware, same as GnG
-16x16 foreground tilemap, like GnG, Commando...
-16x16 mapped background tilemap, like 1943
-Two YM2203 chips for music, lime most 8-bit CAPCOM arcades
-The main CPU is a m6809, like GnG
-Resolution of 352x240 pixels
-Object buffer: Measure ~130us, probably the exact number is 128us, which is
 512 bytes transferred at 4MHz

My original board runs at 57.44Hz according to OSSC. When I measure it with the
oscilloscope I get either 57.3Hz or 57.5Hz.

REVISION HISTORY
================

 7 April 2021 Public release


CREDITS
=======

Brought to you by Jose Tejada, aka jotego. Meet me in twitter @topapate
Checkout my patreon page here: http://patreon.com/jotego

When the game is in pause, the credit screen is shown. You can disable it
by pressing 1P or 2P.

Special thanks to all April '21 patrons.

Tier +5 Patrons Thanks!!
========================
