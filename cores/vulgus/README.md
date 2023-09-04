JTVulgus FPGA clone of GunSmoke arcade faithful to original hardware
=====================================================================

Please, read the main README file too.

You have just got an expensive $200 PCB as that is what I paid for the
board! You have in your hands a faithful conversion of the circuits on
the Vulgus PCB to FPGA. If you come from the emulation world here are 
some of the things different from emulators:

-Real CPU/GPU bus sharing with delays
-Sprites handled with the same scan pattern as in the original hardware
-Palettes determined by the original PROMs
-Graphics priority handled by the original PROM
-No lag between image and input. Data is being sent to the screen in real time.
-3 button input
-Sound sampling rate exactly as the original
-Accurate FPS 100% same as real hardware

These technical aspects mean that the game play will be different from an emulator
in a number of ways and that some hardware tricks that were not emulated will work
here as in the original hardware.

GAME PLAY
=========

The game uses two buttons: fire and missile. There is no continue screen.
If you see the POW or letter icons move while there is horizontal scrolling
going on and you think it is a bug, well, it isn't. That's just how the
hardware worked. Using a different scan sequence might avoid it. But I'm
using the original and it comes with that side effect (verified on the real PCB).

REVISION HISTORY
================

28th Dec 2019
    - Fixes missing sprite bug
    - Fixes top line missing (noticeable in cross hatch test)
    - Moved to new MiSTer SYS folder
21st Nov 2019
    - Fixes bug in SDRAM controller
13th Nov 2019
    - Updated to latest JT49 sound module. Fixes bug in envelope duration
    - Set JT49 compression to level 2 (21dB)
    
7th Oct 2019 - Public release MisT(er)


CREDITS
=======

Brought to you by Jose Tejada, aka jotego. Meet me in twitter @topapate
Checkout my patreon page here: http://patreon.com/jotego

Special thanks to all September '19 patrons.

Tier +3 Patrons Thanks!!
========================

Adrian
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
Brett McAlpine
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
Fabrice Ketels
Fay Dek
Filip Kindt
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
Guinness
Henry R
James DeRose
Javier Martínez
JD
Jeff Gerstmann
Jeremy Glass
Jeremy Hopkins
Jeremy Kaiman
Jérôme Moreau
Jesse Beau
Jesus Garcia
Jo Tomiyori
Joe Kalwitz
Johannes Reß
John Kelley
John Klimek
John Perry
John Stringer
Jootec from Mars
Jorge Slowfret
Joshua Witt
Juan Diego Sánchez Noguera
Juan Manuel Sandoval Jr
Keith Kelly
Ken ottosson
Kevin Bidwell
Kyle Good
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
RetroTyke
Rikard Bengtsson
Rob Young
robert fisher
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
Siampumpkin
SJohansson
skywalky
SmokeMonster
StalkS
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
Violeta Martin Fernandez
Visa-Valtteri Pimiä
vladimir
Vorvek
William Clemens
wvc
Xtro
Xzarian
