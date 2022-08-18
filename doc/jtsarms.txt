JTSArms FPGA clone of Side Arms arcade faithful to original hardware
======================================================================

Please, read the main README file too.

You have just got an expensive $250 PCB according to eBay. You have in your hands
a faithful conversion of the circuits on the Tiger Road PCB to FPGA. If you come from
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

For Side Arms there are some additional differences with MAME:

-CPU speed 8MHz vs 4MHz
-Star Field
-Palette circuit with error bit

GAME PLAY
=========

The game uses two buttons: shot and jump.

Note that by default the continue prompt is disabled. If you want to
be able to continue, change this in the OSD. You can then save your settings
so it will be the same the next time you powerup.

TEST SCREEN
===========
Select the test screen through the OSD menu. To pass on to the next test
screen press both action buttons.


REVISION HISTORY
================
14th August, 2020: Beta release
17th December, 2021: Final release, with correct star field


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
