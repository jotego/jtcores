JT1943 FPGA clone of 1943 arcade faithful to original hardware
==============================================================

Please, read the main README file too.

You have just got an expensive $500 PCB according to eBay. You have in your hands
a faithful conversion of the circuits on the 1943 PCB to FPGA. If you come from
the emulation world here are some of the things different from emulators:

-Real CPU/GPU bus sharing with delays
-Sprites handled with DMA exactly as in the original hardware
-Palettes determined by the original PROMs
-Graphics priority handled by the original PROM
-No lag between image and input. Data is being sent to the screen in real time.
-3 button input (although the game seems to use only two buttons)
-Sound sampling rate: 41.663 kHz (original, 125/3 kHz)

These technical aspects mean that the game play will be different from an emulator
in a number of ways and that some hardware tricks that were not emulated will work
here as in the original hardware.

GAME PLAY
=========

It is obvious what you have to do except:

-Press fire 1 and 2 to roll
-Hold the coin button during power up to test mode in order to be
 able to access al test options
-Hold fire 1 at the end of an air carrier phase to receive a weapon at the
 beginning of the next phase

 Because rolling by pressing two buttons is hard; the FPGA core uses the 
 3rd button to roll. That is not the original behaviour. If you want to play
 like the original, just don't use the 3rd button.

CHEAT
=====
If you enable the test mode after the game has already started, it is possible
to start at any level by altering the value of the coin slot settings.

Note that you can reset the game by pressing F3 or selecting RST in the OSD menu.

RELEASE HISTORY
===============
1st  Dec 2019
    - Flip mode partially fixed

21st Nov 2019
    - Fixes bug in SDRAM controller
    - Fixes flip screen mode (still glitchy though)
13th  Nov 2019
    * Fixed occasional sprite glitching
    * Updated to latest JT12 sound module. Fixes bug in JT49 envelope duration
    * Set JT49 compression to level 1 (29.1dB)

20th Oct 2019
    * Increased sprites per line to 32.
            Changed object to 8MHz as per schematics.
            In the same time, we can produce 32 objects:
                32*16/8MHz = 24*16/6MHz
            This is the approach of Bionic Commando, which also
            uses 8MHz instead of 6MHz.
7th Oct 2019
    * Added FLIP option, although it is a bit glitchy. Original hardware
      did not fully implemented it so it is a bit of a hack.
    * Updated to latest JT49 sound module. Fixes many bugs in SFX.
    * Added 128MB RAM module support (MiSTer only)

CREDITS
=======

Brought to you by Jose Tejada, aka jotego. Meet me in twitter @topapate
Checkout my patreon page here: http://patreon.com/jotego

Special thanks to all March '19 patrons.

Tier +3 Patrons Thanks!!
========================
Suvodip Mitra
Scralings 
Phillip McMahon
Brian Sallee
Jo Tomiyori
Dustin Hubbard
Oliver Jaksch
Dave Ross
Andrew Moore
Ultrarobotninja 
Víctor Gomariz Ladrón de Guevara
Andyways 
Mark Kohler (NML32)
Mary Marshall
Oscar Laguna Garcia
Leslie Law
SmokeMonster 
Don Gafford
furrtek 
Fred Fryolator
40wattrange 
Stephen Marshall
Chris Toast
Geert Oost 
Michael Troelsen
Mads Troest
Jan Beta
Neil Maguire
Filip Kindt
Jeremy Glass
Daniel Hochman
Mike Holzinger
Obiwantje 
Oliver Wndmth
Carl Hagström
Johannes Reß
QcRetro 
Kevin Bidwell
robert fisher
type78 
Manuel Astudillo
Joshua Witt
Duane Hembrick
UKShark 
Javier Martínez
Frank Wolf
Thomas Tahsin-Bey
Miguel Angel Rodriguez Jodar
Manuel Antoni
Peter Edwards
Keith Kelly
Funkycochise 
Marco Tavian
Jérôme Moreau
Owlnonymous 
Eoin Gibney
crashman 
Christian Bailey
James DeRose
Rob Young
Gonzalo López
Nicolas Hamel
Gregory Hogan
Joe Kalwitz
Manuelfx 
Alan Steremberg
StalkS 
DarkStar7 
RetroShop.pt 
Marcos 
Matthew Langtry
Travis Brown
Porkchop Express
Violeta Martin Fernandez
SJohansson 
JD 
loloC2C 
PsyFX 
Darren Newman
Fredrik Berglind
Matt Charlesworth
John Klimek
remowilliams 
Rysha 
Popov 
Dag J.
Michael Stegen
Carlos Del Alamo
albconde 
Fay Dek
Manuel Fernández
Blue1597 
Bruno Silva
Ed Balan
Manuel 
Salvador Perugorria Lorente


