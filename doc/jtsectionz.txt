JTSectionZ FPGA clone of Section Z arcade
=========================================

Please, read the main README file too.

You have just got an expensive $250 PCB (+delivery) according to eBay. 
You have in your hands a faithful conversion of the circuits on the Section Z PCB to FPGA.
This work has been done based on other CAPCOM boards and schematics and on MAME sources.
I did not have access to the PCB but I am pretty confident this is accurate. Some features:

-Real CPU/GPU bus sharing with delays
-Sprites handled with DMA exactly as in the original hardware
-No lag between image and input. Data is being sent to the screen in real time.
-According to MAME the frame rate should be 55.37Hz, I find that not possible
 to done in a reasonable way in hardware. I think the figure of 55.8Hz should be
 the right one and maybe the PCB they measured had drifted in value over the decades.
 This is related to video timings (blanking intervals, number of lines, etc.)

These technical aspects mean that the game play will be different from an emulator
in a number of ways and that some hardware tricks that were not emulated will work
here as in the original hardware.

GAME PLAY
=========

The game uses two buttons: turn around and fire. Try to make it to the second level
as it gets much more interesting than the first one.

TEST SCREEN
===========
Select the test screen through the OSD menu.

COMPILATION
===========
For MiSTer: jtcore sectionz -mister
For MiST/Sidi: jtcore sectionz -mist/-side -rename JTSZ

TECHNICAL INFORMATION
=====================
-This board seems to be the same as Legendary Wings except for CPU speed.
-The screen resolution is a bit overscanned so it may be quite problematic on CRT screens

REVISION HISTORY
================
19th Apr 2020 - Initial release to cellebrate 1000 patrons.

CREDITS
=======

Brought to you by Jose Tejada, aka jotego. Meet me in twitter @topapate
Checkout my patreon page here: http://patreon.com/jotego

Special thanks to all my patreons during the last year. You've been great!
