JTTora FPGA clone of Tiger Road arcade faithful to original hardware
======================================================================

Please, read the main README file too.

You have just got an expensive $295 PCB according to eBay. You have in your hands
a faithful conversion of the circuits on the Tiger Road PCB to FPGA. If you come from
the emulation world here are some of the things different from emulators:

-Real CPU/GPU bus sharing with delays
-Sprites handled with DMA exactly as in the original hardware
-Palettes determined by the original PROMs
-Graphics priority handled by the original PROM
-No lag between image and input. Data is being sent to the screen in real time.
-Sound sampling rate: 41.663 kHz (original, 125/3 kHz)
-Accurate FPS 100% same as real hardware

These technical aspects mean that the game play will be different from an emulator
in a number of ways and that some hardware tricks that were not emulated will work
here as in the original hardware.

GAME PLAY
=========

The game uses two buttons: shot and jump.

Note that by default the continue prompt is disabled. If you want to
be able to continue, change this in the OSD. You can then save your settings
so it will be the same the next time you powerup.

TEST SCREEN
===========
Select the test screen through the OSD menu.  To pass on to the next test 
screen press both action buttons.

TECHNICAL INFORMATION
=====================
-All PSG channels had no load on the bootleg board
-YM2203 phi M =3.7MHz, phi S = 1.2MHz (measured with broken Z80, so default divider)
-DMA duration was measured to be xxx, matching the expected behaviour

REVISION HISTORY
================
21st Nov 2019
    - Fixes bug in SDRAM controller
14 Nov 2019: Public release (MiST and MiSTer)
13 Nov 2019: beta 3
    * Adds ADPCM sound to Japanese version
    * Updated to latest JT12 sound module. Fixes bug in JT49 envelope duration
    * Set JT49 compression to level 1 (29.1dB)
1  Nov 2019: beta release 2
    * FX sound added for western versions
    * Sprite glithces fixed
    * Still missing ADPCM sound on Japanese version
27 Oct 2019: beta release.
    * No FX sound. I don't understand why.
    * Sprite glitches due to 8-pixel data loading 
      (instead of 4 pixels as other CPS0 games)



CREDITS
=======

Brought to you by Jose Tejada, aka jotego. Meet me in twitter @topapate
Checkout my patreon page here: http://patreon.com/jotego

Special thanks to all October '19 patrons.

Tier +3 Patrons Thanks!!
========================

```
Adam Forrester          Leslie Law
Adrian                  Lewis Waddington
AkaiFutari              loloC2C
Alan Steremberg         Manuel
albconde                Manuel Antoni
Alexander Kholodov      Manuel Astudillo
Allen Tipper            Manuel Fernández
Amosfear                Manuelfx
Andrew Boudreau         Marco Tavian
Andrew Moore            Mario Salvini
Andylithia              Mark Kohler (NML32)
Andyways                Mary Marshall
Anthony Bolek           Matt Charlesworth
AtariSTFan              Matt Elder
Brian Sallee            Matthew Langtry
Bruno Silva             Matthew Young
Bryan Siemon            Michael Stegen
Buster D                Michael Troelsen
Carl Hagström           Michael's Workshop
Carlos Del Alamo        Miguel Angel Rodriguez Jodar
Chris Jardine           Mikael Tillander
Chris Mawman            Mike Holzinger
Christian Auby          Mr.B
Christian Bailey        Neil Maguire
Christopher Harvey      Nelson Melo
Christopher rumford     Nicolas Hamel
Christopher Tuckwell    Obiwantje
Dacide                  Oliver Jaksch
Daniel Bauza            Oliver Seitz
Daniel Casadevall       Oliver Wndmth
Daniel Hochman          Oscar Jacobsson
Daniel Renner           Oscar Laguna Garcia
DarkStar7               Owlnonymous
Darren Newman           Phillip McMahon
Don Gafford             Popov
Duane Hembrick          Porkchop Express
Dustin Hubbard          PsyFX
Ed Balan                QcRetro
Eoin Gibney             remowilliams
Fabio                   Renan Eler
Fay Dek                 RetroShop.pt
Filip Kindt             RetroTyke
foyde                   Richard Gregory
FRANCISCO FUENTES       Rob Young
Frank Wolf              robert fisher
Fred Fryolator          Roberto Lari
Frédéric Mahé           Roland
Fredrik Berglind        Roman Buser
FULLSET                 Ryan Fig
Funkycochise            Rysha
furrtek                 Salvador Perugorria
Gary Shepherdson        Samuli Tuomola
Geert Oost              sawf01
Gonzalo López           Scralings
Gregory Hogan           Sembiance
Guillermo Tunon         Shane Lynch
Guinness                Shogun7
Henry R                 Siampumpkin
Herbert Krammer         SJohansson
James DeRose            skywalky
JD                      SmokeMonster
Jeff Gerstmann          Stefan Nordkvist
Jeremy Glass            Stephen Marshall
Jeremy Hopkins          Stephen Pearce
Jeremy Kaiman           Steve Suavek
Jérôme Moreau           Steven Wilson
Jeruro                  Stuart Fisk
Jesus Garcia            Suvodip Mitra
Jo Tomiyori             Sweetlilmre
Joe Kalwitz             Thomas Davies
Johannes Reß            Thomas Tahsin-Bey
John Kelley             Toby Boreham
John Klimek             Tony Peters
John Perry              type78
John Stringer           UKShark
Jootec from Mars        Ultrarobotninja
Jorge Galán             Víctor Gomariz Ladrón de Guevara
Jorge Slowfret          Videodr0me
Juan Diego Sánchez      Violeta Martin Fernandez
Juan M. Sandoval Jr     Visa-Valtteri Pimiä
Keith Kelly             vladimir
Ken ottosson            Vorvek
Kevin Bidwell           William Clemens
Kyle Good               wvc
Kyle Troutman           Xtro
Xzarian
```