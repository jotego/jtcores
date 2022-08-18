JTCommando FPGA clone of Commando arcade faithful to original hardware
======================================================================

Please, read the main README file too.

You have just got an expensive $200 PCB according to eBay. You have in your hands
a faithful conversion of the circuits on the Commando PCB to FPGA. If you come from
the emulation world here are some of the things different from emulators:

-Real CPU/GPU bus sharing with delays
-Sprites handled with DMA exactly as in the original hardware
-Palettes determined by the original PROMs
-Graphics priority handled according to the original PROM
-No lag between image and input. Data is being sent to the screen in real time.
-No lag between sound and image. All hardware runs in parallel with no time multiplexing.
-Sound sampling rate: 41.663 kHz (i.e. exactly the original, 125/3 kHz)

These technical aspects mean that the game play will be different from an emulator
in a number of ways and that some hardware tricks that were not emulated will work
here as in the original hardware.

The ROM Master
==============
The ROM Master, aka Bruno Silva, has provided us with a .bat file to generate the necessary ROM file using MAME ROM files. Please follow the instructions of the .bat file to generate the ROM. The game works will all known ROMs.

RELEASE HISTORY
===============
21st Nov 2019
    - Fixes bug in SDRAM controller
13rd  Nov 2019
    * Fixed occasional sprite glitching
    * Updated to latest JT12 sound module. Fixes bug in JT49 envelope duration
    * Set JT49 compression to level 1 (29.1dB)
7th Oct 2019
    * Main Z80 is overclocked to avoid graphic glitches. Needs further debugging
    * Updated to latest JT49 sound module. Fixes many bugs in SFX.
    * Added 128MB RAM module support (MiSTer only)

20th Jul 2019 BETA RELEASE
    * Some graphical issues, likely to be due to a problem in the bus arbitrion implementation. These will be fixed in the final -and public- release.

TEST MODE
=========
To enter test mode press several times the shot button while the initial legal message is being displayed.

CREDITS
=======

Brought to you by Jose Tejada, aka jotego. Meet me in twitter @topapate
Checkout my patreon page here: http://patreon.com/jotego

Special thanks to all July '19 patrons.

Tier +3 Patrons Thanks!!
========================
40wattrange
Alan Steremberg
albconde
Alexander Kholodov
Allen Tipper
Andrew Moore
Andylithia
Andyways
Anthony Bolek
AtariSTFan
Blue1597
Brett McAlpine
Brian Sallee
Bruno Silva
Buster D
Carl Hagström
Carlos Del Alamo
Christian Auby
Christian Bailey
Christopher Caswell
Christopher rumford
Dacide
Daniel Bauza
Daniel Hochman
Daniel Renner
DarkStar7
Darren Newman
Dave Ross
David Colmenero
Don Gafford
Duane Hembrick
Dustin Hubbard
Ed Balan
Eoin Gibney
Fabio
Fay Dek
Filip Kindt
Francisco Javier Fuentes Moreno
Frank Wolf
Fred Fryolator
Fredrik Berglind
Frédéric Mahé
FULLSET
Funkycochise
furrtek
Geert Oost 
Gonzalo López
Gregory Hogan
Henry R
James DeRose
James Sawford
Javier Martínez
JD
Jeff Gerstmann
Jeremy Glass
Jesus Garcia
Jo Tomiyori
Joe Kalwitz
Johannes Reß
John Klimek
John Silva
John Stringer
Joshua Witt
Juan Diego Sánchez Noguera
Jérôme Moreau
Keith Kelly
Ken ottosson
Kevin Bidwell
Kyle Troutman
Leslie Law
loloC2C
Manuel
Manuel Antoni
Manuel Astudillo
Manuel Fernández
Manuelfx
Marco Tavian
Mario Salvini
Mary Marshall
Matt Charlesworth
Matt Elder
Matthew Langtry
Matthew Young
Michael Stegen
Michael Troelsen
Michael's Workshop
Miguel Angel Rodriguez Jodar
Mike Holzinger
Mordecai The Walrus
Mr.B
Neil Maguire
Nicolas Hamel
Obiwantje
Oliver Jaksch
Oliver Wndmth
Oscar Jacobsson
Oscar Laguna Garcia
Owlnonymous
Phillip McMahon
Popov
Porkchop Express
PsyFX
QcRetro
remowilliams
RetroShop.pt
Rikard Bengtsson
Rob Young
robert fisher
Roman Buser
Ryan Fig
Rysha
Salvador Perugorria Lorente
Scralings
Sembiance
SJohansson
SmokeMonster
StalkS
Stefan Nordkvist
Stephen Marshall
Steven Wilson
Suvodip Mitra
Sweetlilmre
Thomas Tahsin-Bey
Tony Peters
type78
UKShark
Ultrarobotninja
Violeta Martin Fernandez
Visa-Valtteri Pimiä
vladimir
Vorvek
Víctor Gomariz Ladrón de Guevara
William Clemens
