JTBTiger FPGA clone of Black Tiger arcade faithful to original hardware
========================================================================

Please, read the main README file too.

You have just got an expensive €315 PCB according to eBay. You have in your hands
a faithful conversion of the circuits on the Tiger Road PCB to FPGA. If you come from
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

MiST VERSION
============

The MiST version does not have sound because of lack of enough internal memory
in the FPGA. Maybe it can be fixed with some architectural change but I will
probably not do it myself unless several patrons ask for it.

MiSTer will feature sound in the release version, although the first beta doesn't
play sounds (the hardware is there but something fails in the CPU/MCU/2nd CPU interface)

GAME PLAY
=========

The game uses two buttons: shot and jump.

Note that by default the continue prompt is disabled. If you want to
be able to continue, change this in the OSD. You can then save your settings
so it will be the same the next time you powerup.

TEST SCREEN
===========
Select the test screen through the OSD menu. Press 1P coin button during ROM
test to access all test sections. To pass on to the next test screen press 
both action buttons.


REVISION HISTORY
================

 8 Mar 2020 Improved stability by eliminating the clock enable of the MCU 
            and using a 6MHz clock directly
 6 Jan 2020 Public release
24 Nov 2019 Beta release


CREDITS
=======

Brought to you by Jose Tejada, aka jotego. Meet me in twitter @topapate
Checkout my patreon page here: http://patreon.com/jotego

Special thanks to all November '19 patrons.

Tier +3 Patrons Thanks!!
========================

Adrian                                  Lewis Waddington
AkaiFutari                              loloC2C
Alan Steremberg                         Manuel
albconde                                Manuel Antoni
Allen Tipper                            Manuel Astudillo
Amosfear                                Manuel Fernández
Andrew Boudreau                         Manuelfx
Andrew Moore                            Marco Tavian
Andyways                                Mario Salvini
Anthony Bolek                           Mary Marshall
AtariSTFan                              Matt Charlesworth
Blue1597                                Matt Elder
Brian Sallee                            Matteo Parolin
Bruno Silva                             Matthew Langtry
Bryan Siemon                            Matthew Young
Buster D                                McNathan
Carl Hagström                           Michael Scanlon
Carlos Del Alamo                                Michael Stegen
Charles Sagett                          Michael's Workshop
Chris Jardine                           Mick Stone
Chris Mawman                            Miguel Angel Rodriguez Jodar
Christian Auby                          Mikael Tillander
Christian Bailey                        Mike Holzinger
Christopher Harvey                      Mister JBAM
Christopher rumford                     MrX-8B
Christopher Tuckwell                    Neil Maguire
Dana Rich                               Nelson Jr
Daniel Bauza                            Nicolas Hamel
Daniel Casadevall                       Obiwantje
Daniel Hochman                          Oliver Jaksch
DarkStar7                               Oliver Seitz
Darren Newman                           Oliver Wndmth
Don Gafford                             olivier bernhard
Duane Hembrick                          Oscar Jacobsson
Ed Balan                                Oscar Laguna Garcia
emceebois                               Outchocinco
Eoin Gibney                             Owlnonymous
Evan Clarke                             Phillip McMahon
Fabio                                   Popov
Fay Dek                                 Porkchop Express
Filip Kindt                             PsyFX
FRANCISCO JAVIER FUENTES MORENO         QcRetro
Frank Wolf                              Raziel
Fred Fryolator                          remowilliams
Frédéric Mahé                           Renan Eler
Fredrik Berglind                        RetroShop.pt
FULLSET                                 Richard Gregory
Funkycochise                            Rob Young
furrtek                                 Roberto Lari
Gary Shepherdson                        Roland
Geert Oost                              Roman Buser
Gonzalo López                           Ryan Fig
Gregory Hogan                           Rysha
Guillermo Tunon                         Salvador Perugorria Lorente
Guinness                                Samuli Tuomola
Henry R                                 sawf01
Herbert Krammer                         Scralings
Humanoide70                             Sembiance
Ishmael Hallin                          Shane Lynch
James DeRose                            Shawn Wheatley
JD                                      Shogun7
Jeff Gerstmann                          SJohansson
Jeff O'Meara                            skywalky
Jeremy Glass                            SmokeMonster
Jeremy Hopkins                          Stefan Nordkvist
Jeremy Kaiman                           Stephen Marshall
Jérôme Moreau                           Stephen Pearce
Jeruro                                  Steven
Jesus Garcia                            Steven Wilson
Jo Tomiyori                             Stuart Fisk
Joe Kalwitz                             Suvodip Mitra
Johannes Reß                            Sweetlilmre
John Kelley                             Thomas Davies
John Klimek                             Thomas Tahsin-Bey
John Perry                              Toby Boreham
John Stringer                           Tony Peters
Jootec from Mars                        type78
Jorge Galán                             UKShark
Jorge Slowfret                          Ultrarobotninja
Juan Diego Sánchez Noguera              Víctor Gomariz Ladrón de Guevara
Juan Manuel Sandoval Jr                 Videodr0me
Keith Kelly                             Violeta Martin Fernandez
Ken ottosson                            Visa-Valtteri Pimiä
Kevin Bidwell                           vladimir
Kris Butler                             Vorvek
Kyle Good                               William Clemens
Kyle Troutman                           wvc
LawdVayduh                              Xtro
Leslie Law                              Xzarian
