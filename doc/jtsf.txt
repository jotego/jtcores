JTSF FPGA clone of Street Fighter arcade faithful to original hardware
======================================================================

Please, read the main README file too.

You have just got an expensive $250 PCB, at least I paid that for it. You have in your hands
a faithful conversion of the circuits on the Street Fighter 1 PCB to FPGA. If you come from
the emulation world here are some of the things different from emulators:

-Real CPU/GPU bus sharing with delays
-Sprites handled with DMA exactly as in the original hardware
-Palettes determined by the original PROMs
-Graphics priority handled by the original PROM
-No lag between image and input. Data is being sent to the screen in real time.
-Sound sampling rate: 41.663 kHz (original, 125/3 kHz)
-Accurate FPS 100% same as real hardware (61Hz)

These technical aspects mean that the game play will be different from an emulator
in a number of ways and that some hardware tricks that were not emulated will work
here as in the original hardware.

GAME VERSIONS
=============

Short name | Variation | MCU    |  Pneumatic buttons  | Input style
-----------|-----------|--------|---------------------|------------
sf         | US set 1  |        |                     |
sfua       | US set 2  | Yes    |                     | sfjp
sfj        | Japan     | Yes    |                     | sfjp
sfjan      | Japan     |        | Yes                 |
sfjbl      | Japan     | Yes    |                     | sfjp
sfan       | World     |        | Yes                 |
sfp        |           |        |                     |
sfw        | World     | Yes    |                     | sfw

HARDWARE DIFFERENCES
====================

The registered PAL device is not being used. The DTACK timing may be wrong.
There might some additional video signals -like a palette error bit. I have not
looked for them on the PCB.


Issues
======

-ADPCM is a bit noisy, probably because of missing ROM reads


TEST SCREEN
===========
Select the test screen through the OSD menu. To pass on to the next test
screen press both action buttons.

SDRAM LAYOUT
============

Region        |  ROM Start | SDRAM Start | Length    |  Bank
--------------|------------|-------------|-----------|--------
Main CPU ROM  |       0    |         0   |  6'0000   |   0
Main CPU RAM  |     N/A    |    3'0000   |           |   0
Sound 1 CPU   |  6'0000    |         0   |    8000   |   1
Sound 2 CPU   |  6'8000    |      4000   |    8000   |   1
MCU           |  A'8000    |      8000   |    1000   |   1
Map 1         |  A'9000    |         0   |    2000   |   2
Map 2         |  C'9000    |      1000   |    2000   |   2
Char          |  E'9000    |      2000   |    4000   |   2
Scroll 1      |  E'D000    |         0   | 10'0000   |   3
Scroll 2      | 1E'D000    |    8'0000   |  8'0000   |   3
Object        | 26'D000    |    C'0000   | 1C'0000   |   3


REVISION HISTORY
================
27th November, 2020: Public release
 4th September, 2020: Beta release


CREDITS
=======

Brought to you by Jose Tejada, aka jotego. Meet me in twitter @topapate
Checkout my patreon page here: http://patreon.com/jotego

Special thanks to all August '20 patrons.

Tier +5 Patrons Thanks!!
========================

80's spaceman           Darren Wootton      Justin D'Arcangelo  Patrick Roman Fabri
Alan Shurvinton         David Fleetwood     Keith Duncan        Paweł Mandes
Alonso J. Núñez         David Jones         KnC                 RandomRetro
Andrea Chiavazza        DrMnike             Lee Osborne         Richard Eng
Andreas Micklei         Eric J Faulkes      Louis Martinez      Richard Murillo
Andrew Ajello           Fabio Michelin      Luc JOLY            Richard Simpson
Andrew Boudreau         Filip Kindt         Magnus Kvevlander   Robert Forbes
Andy Palmer             Francis B           Manuel Astudillo    Roel Pollaert
Angelo Kanaris          Frank Hoedemakers   Matt Evans          Sassbasket Silvercloud
Anthony Monaco          Frederic FONTANA    Matthew Woodford    SNIPERMikeUK
asdfgasfhsn             GA                  Michael Deshaies    Spank Minister
Ben Toman               Gavin               Michael Yount       Stephen Goldberg
Bob Gallardo            Greg                Mick Stone          Steven Yedwab
Brent Fraser W.         Gregory Val         Mike Jegenjan       Thomas Irwin
Brett T Davis           HFSPlay             Mike Parks          Tony Toon
Carrboroman             Human0Target        Nailbomb            Trifle
Charles                 hyp36rmax           natalie             Victor Bly
Chris smith             Jesse Clark         Neil St Clair       XC-3730C
Christian Bailey        Johan Smolinski     Nico Stamp
Daniel Estreito         Jonathan Loor       Oskar Sigvardsson
