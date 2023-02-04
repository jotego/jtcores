JTTora FPGA clone of Bionic Commando arcade faithful to original hardware
=========================================================================

Please, read the main README file too.

You have just got an expensive €175 PCB according to eBay. You have in your hands
a faithful conversion of the circuits on the Tiger Road PCB to FPGA. If you come from
the emulation world here are some of the things different from emulators:

-Real CPU/GPU bus sharing with delays
-Sprites handled with DMA exactly as in the original hardware
-Exact timing for bus sharing with microcontroller
-Graphics priority handled by the original PROM
-No lag between image and input. Data is being sent to the screen in real time.
-Sound sampling rate: exactly the original
-Accurate FPS 100% same as real hardware
-Test DIP does not stop the game, so it is possible to use all test
features (read below about cheating). For some reason, the test dip stops
the game in MAME

These technical aspects mean that the game play will be different from an emulator
in a number of ways and that some hardware tricks that were not emulated will work
here as in the original hardware.

Sound Issues
============

The MiST version does not have sound because of lack of enough internal memory
in the FPGA. Maybe it can be fixed with some architectural change but I will
probably not do it myself unless several patrons ask for it.

MiSTer version uses 3MHz as the clock for the sound CPU but it should be 3.7MHz. There is
an issue preventing the sound to work when the sound CPU is run at 3.7MHz. The sound CPU
ignores the JT51 interrupt line when using 3.7MHz. It is not clear whether the interaction
with the MCU and main CPU has something to do with this.

GAME PLAY
=========

The game uses two buttons: shot and jump.

Note that by default the continue prompt is disabled. If you want to
be able to continue, change this in the OSD. You can then save your settings
so it will be the same the next time you powerup.

CHEAT
=====
If you enable the test mode after the game has already started, it is possible
to start at any level by altering the value of the coin slot settings.

Slot1 Input Stage
1c1    1
1c2    2
1c3    3
1c4    4
1c5    5

Note that you can reset the game by pressing F3 or selecting RST in the OSD menu.

TEST SCREEN
===========

Select the test screen through the OSD menu. Press 1P coin button during ROM
test to access all test sections. To pass on to the next test screen press 
both action buttons.


REVISION HISTORY
================

30   Nov 2019
    -Sound works in MiSTer using 3MHz clock
28   Nov 2019   Public release
    -Sound doesn't work in MiST because it doesn't fit in the FPGA
    -Sound doesn't work in MiSTer for unknown reason. It works in simulation.
21st Nov 2019
    - Fixes bug in SDRAM controller
1st Nov 2019 beta release (2)
    - Fixed occasional sprite glitching
27 Oct 2019: beta release. 
                -No sound (some MCU issue?)
                -Sprite glitches due to 8-pixel data loading 
                 (instead of 4 pixels as other CPS0 games)
                -Background glitch when elevator lights flash


CREDITS
=======

Brought to you by Jose Tejada, aka jotego. Meet me in twitter @topapate
Checkout my patreon page here: http://patreon.com/jotego

Special thanks to all October '19 patrons.

Tier +3 Patrons Thanks!!
========================

Adam Forrester
Adrian
AkaiFutari
Alan Steremberg
albconde
Alexander Kholodov
Allen Tipper
Amosfear
Andrew Boudreau
Andrew Moore
Andylithia
Andyways
Anthony Bolek
AtariSTFan
Brian Sallee
Bruno Silva
Bryan Siemon
Buster D
Carl Hagström
Carlos Del Alamo
Chris Jardine
Chris Mawman
Christian Auby
Christian Bailey
Christopher Harvey
Christopher rumford
Christopher Tuckwell
Dacide
Daniel Bauza
Daniel Casadevall
Daniel Hochman
Daniel Renner
DarkStar7
Darren Newman
Don Gafford
Duane Hembrick
Dustin Hubbard
Ed Balan
Eoin Gibney
Fabio
Fay Dek
Filip Kindt
foyde
FRANCISCO JAVIER FUENTES MORENO
Frank Wolf
Fred Fryolator
Frédéric Mahé
Fredrik Berglind
FULLSET
Funkycochise
furrtek
Gary Shepherdson
Geert Oost 
Gonzalo López
Gregory Hogan
Guillermo Tunon
Guinness
Henry R
Herbert Krammer
James DeRose
JD
Jeff Gerstmann
Jeremy Glass
Jeremy Hopkins
Jeremy Kaiman
Jérôme Moreau
Jeruro
Jesus Garcia
Jo Tomiyori
Joe Kalwitz
Johannes Reß
John Kelley
John Klimek
John Perry
John Stringer
Jootec from Mars
Jorge Galán
Jorge Slowfret
Juan Diego Sánchez Noguera
Juan Manuel Sandoval Jr
Keith Kelly
Ken ottosson
Kevin Bidwell
Kyle Good
Kyle Troutman
Leslie Law
Lewis Waddington
loloC2C
Manuel
Manuel Antoni
Manuel Astudillo
Manuel Fernández
Manuelfx
Marco Tavian
Mario Salvini
Mark Kohler (NML32)
Mary Marshall
Matt Charlesworth
Matt Elder
Matthew Langtry
Matthew Young
Michael Stegen
Michael Troelsen
Michael's Workshop
Miguel Angel Rodriguez Jodar
Mikael Tillander
Mike Holzinger
Mr.B
Neil Maguire
Nelson Melo
Nicolas Hamel
Obiwantje
Oliver Jaksch
Oliver Seitz
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
Renan Eler
RetroShop.pt
RetroTyke
Richard Gregory
Rob Young
robert fisher
Roberto Lari
Roland
Roman Buser
Ryan Fig
Rysha
Salvador Perugorria Lorente
Samuli Tuomola
sawf01
Scralings
Sembiance
Shane Lynch
Shogun7
Siampumpkin
SJohansson
skywalky
SmokeMonster
Stefan Nordkvist
Stephen Marshall
Stephen Pearce
Steve Suavek
Steven Wilson
Stuart Fisk
Suvodip Mitra
Sweetlilmre
Thomas Davies
Thomas Tahsin-Bey
Toby Boreham
Tony Peters
type78
UKShark
Ultrarobotninja
Víctor Gomariz Ladrón de Guevara
Videodr0me
Violeta Martin Fernandez
Visa-Valtteri Pimiä
vladimir
Vorvek
William Clemens
wvc
Xtro
Xzarian
