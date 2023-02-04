JTTrojan FPGA clone of Trojan arcade faithful to original hardware
===================================================================

Please, read the main README file too.

You have just got a middle priced €150 PCB according to eBay. You have in your hands
a faithful conversion of the circuits on the Trojan PCB to FPGA. If you come from
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

-Overscan screen resolution, same as SectionZ
-Basic 6MHz sprite hardware, same as GnG
-16x16 foreground tilemap, like GnG, Commando...
-16x16 mapped background tilemap, like 1943
-MSM5205 ADPCM voices, like Tora e no michi (Japanese version of Tiger Road)
-Two YM2203 chips for music, lime most 8-bit CAPCOM arcades
-Three Z80 chips in total!

I only had a bootleg board and it runs at 55.97Hz according to OSSC. But when I measure it with the
oscilloscope I could only measure either 55.5Hz or 55.2Hz (very jittery). With the time settings I had
for Section Z (same resolution) I was getting 55.77Hz reported by OSSC and the game was running behid the
demo loop. So I have opted to speed it up to 56.0Hz by removing one blanking line. If I ever come across
an original board I'll measure its frame rate and correct the core if needed.

Curiously, the WAITN signal seemed to be always high on the main Z80 on my bootleg board. Bus arbitrion must
be done by gating directly the CPU clock, as in other CAPCOM games, but I haven't checked it on the PCB.

REVISION HISTORY
================

 7 Aug 2020 Public release


CREDITS
=======

Brought to you by Jose Tejada, aka jotego. Meet me in twitter @topapate
Checkout my patreon page here: http://patreon.com/jotego

When the game is in pause, the credit screen is shown. You can disable it
by pressing 1P or 2P.

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
