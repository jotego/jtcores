Release history
===============

18th Apr 2022
    * Makes color flash bug possible, like the original board

21st Nov 2019
    * Fixes bug in SDRAM controller
13th  Nov 2019
    * Fixed occasional sprite glitching
    * Updated to latest JT12 sound module. Fixes bug in JT49 envelope duration
    * Set JT49 compression to level 1 (29.1dB)
7th Oct 2019
    * Moved back to old scan doubler. Please use MiSTer custom filters if
      the scroll is not smooth for you.
    * Updated to latest JT49 sound module. Fixes many bugs in SFX.
    * Added 128MB RAM module support (MiSTer only)

13th Sept 2019
    * Fixed ogre sound
    * Fixed sprite alignment
    * Fixed bug that erased the first pixel of the sprite line buffer
    * Added more DIP options through OSD menu
    * Better scan doubler in MiSTer, although it requires a reset sometimes
    * MiSTer core name changed to JTGNG, as was in MiST before
    * MiST ROM file changed to follow the same format as MiSTer's
    * Reduced SDRAM speed (48MHz) for greater robustness

--- history of older releases is not shown here


Project Structure
=================

This work has two separate parts:

1. A verilog model of the original hardware, replicated from original schematics. This is found in the hdl folder. Some test benches are available in the "ver" (for verification) folder. Data sheets of parts used in the original design are located in the "doc" folder. This is interesting to understand how it worked. It can be used to repair broken boards too.

2. A modern clone written in Verilog. It has been made with the MiST board in mind but the game itself (jtgng_game module) is highly portable. All components used aim to be cycle exact -some even sub-cycle exact- so the recreation is the most similar thing to having the original PCB you can get.

Notes
=====

Install LWTOOLS (http://lwtools.projects.l-w.ca/) to assemble m6809 source code for test cases.