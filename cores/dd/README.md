# JTDD FPGA Arcade Hardware Jose Tejada (@topapate)

You can show your appreciation through
* [Patreon](https://patreon.com/jotego)
* [Paypal](https://paypal.me/topapate)

Yes, you always wanted to have a Double Dragon arcade board at home. First you couldn't get it because your parents somehow did not understand you. Then you grow up and your wife doesn't understand you either. Don't worry, MiST(er) is here to the rescue.

What you get with this is an extremely accurate (allegedly 100% accurate) clone of the original hardware. Bus timing and minor details have been observed and you should notice quite a different feeling when comparing the game to an emulator.

I hope you will have as much fun with it as I had it while making it!

# Compatible Hardware

This repository contains hardware designed for FPGA compatible with the following systems:

- Renegade
- Double Dragon 1 & 2

# Troubleshooting

Note that Double Dragon 1 and 2 are 57Hz games. Some screens do not support this refresh rate.
ADPCM sounds with less treble than in MAME. Upon comparison with the arcade PCB, I think
this is correct.

Flip mode is not supported. Because this is a horizontal game and cocktail tables are not
popular anymore, I don't plan to implement the flip mode.

* If the game doesn't start up after loading the ROM press F3 (reset) or select reset from the OSD menu
* Please post any issues to the github page. Click on the issues tab.

https://github.com/jotego/jtdd

# Conversion Accuracy

The HDL code respects all interaction between the different hardware subsystems. When the original signal names are used, those are in capitals. The handshaking between the main CPU and the MCU follows the original design as well. The M6801 core used for the MCU may or may not be cycle accurate. I have not checked it yet.

Although some dual port memories have been used, they can actually be replaced by single port memories
with none or minimum changes to the HDL. I moved to dual port memories while I was debugging some glitches,
which eventually were not related to that, and I just didn't change them back. There is no bus arbitrion
related to the original memories as bus access is just time interleaved without handshaking in the
original design.

The schematics of the original can be found in the doc folder.

## Antialiasing Filters

Double Dragon 1 has no antialiasing whatsoever for ADPCM audio, as can be seen in the schematics.

I do not have the schematics of DD2, so I do not know what filter it may have had, if any.
I have used a filter at 2xFs for it, which will preserve most of the aliasing and just removed
very high frequencies.

# Modules

The FPGA clone uses the following modules:

JT51:    For YM2151 sound synthesis. From the same author.
JT5205:  For MSM5205 ADPCM sound synthesis. From the same author.
JT6295:  For MSM6295 ADPCM sound synthesis. From the same author.
HD63701: JT680X. From the same author.
JTFRAME: A common framework for FPGA arcades. From the same author.
MC6809:  from Greg Miller, slightly modified. Part of JTFRAME, the original can be found in github

When populating the git, remember to use:

git submodule init
git submodule update

To get the needed modules. If you update git, you may need to manually update the
submodules commits like this:

git pull
git submodule update

# Compilation

Refer to [JTFRAME](https://github.com/jotego/jtframe) for compilation instructions.

# Keyboard

On MiSTer keyboard control is configured through the OSD.

For MiST and MiSTer: games can be controlled with both game pads and keyboard. The keyboard follows the same layout as MAME's default.

    F3      Game reset
    P       Pause
    1,2     1P, 2P start buttons
    5,6     Left and right coin inputs

    cursors 1P direction
    CTRL    1P button 1
    ALT     1P button 2
    space   1P button 3

    R,F,G,D 2P direction
    Q,S,A   2P buttons 3,2 and 1

    F7      Turn character layer on/off
    F8      Turn second background layer on/off
    F9      Turn object (sprite) layer on/off


# ROM Generation

The rom folder contains the batch files for both linux and windows to generate the ROM file starting from a MAME set. Follow the instructions of that file. There is also a MRA file to use directly in MiSTer with the MAME zipped ROM.

# SD Card

For MiST copy the file core.rbf to the SD card at the root directory. Copy also the rom you have generated with the name JTDD.rom. It will get loaded at start.

# Extras

You can press F12 to bring the OSD menu up. You can turn off music, or sound effects with it. By default, a screen filter makes the screen look closer to an old tube monitor. If you turn it off you will get sharp pixels. Note that if you switch from sharp to soft pixels you will need a couple of seconds to get your eyes used as the brain initially perceives this as an out of focus image compared to the old one.

# Credits

Jose Tejada Gomez. Twitter @topapate
Project is hosted in http://www.github.com/jotego/jtdd
License: GPL3, you are obligued to publish your code if you use mine

Special thanks to Greg Miller, Bruno Silva and to:

```
Adrian                                          Fabio                                   Leslie Law                              RetroDriven
AkaiFutari                                      Fay Dek                                 Lewis Waddington                        RetroShop.pt
Alan Steremberg                                 Filip Kindt                             loloC2C                                 Richard Gregory
albconde                                        FRANCISCO JAVIER FUENTES MORENO         Luis F Giron                            Rob Young
Alex                                            Frank Wolf                              Manuel                                  Roberto Abdelkader Martínez Pérez
Alex Hoerr                                      Fred Fryolator                          Manuel Antoni                           Roberto Lari
Allen Tipper                                    Frédéric Mahé                           Manuel Astudillo                        Roland
Amineko Stone                                   Fredrik Berglind                        Manuel Fernández                        Rolf-Karsten Bråten
Amosfear                                        FULLSET                                 Manuelfx                                Roman Buser
Andrew Boudreau                                 Funkycochise                            Marco Tavian                            Ryan Fig
Andrew Francomb                                 furrtek                                 Mario Salvini                           RyLe
Andrew Moore                                    Gary Shepherdson                        Mark Paterson                           Rysha
Andylithia                                      Geert Oost                              Mary Marshall                           Salvador Perugorria Lorente
Andyways                                        Geoff Connell                           Matt Charlesworth                       Samuli Tuomola
Anthony Bolek                                   Gonzalo López                           Matt Elder                              sawf01
Aqy                                             Gregory Hogan                           Matteo Parolin                          Scralings
Arcade Express                                  Guillermo Tunon                         Matthew Humphrey                        Sebastien COCHET
Arnaud Jacquemin                                Guinness                                matthew tecchio                         Sembiance
AtariSTFan                                      Henry R                                 Matthew Young                           Shane Lynch
Bibiabho Astoporri                              Herbert Krammer                         mattyhochs                              Shane Yates
Blue1597                                        Humanoide70                             McNathan                                Shawn Wheatley
Brett McAlpine                                  Ishmael Hallin                          Michael Scanlon                         Shogun7
Brian Sallee                                    Jacques Henri                           Michael Stegen                          SJohansson
Bruno Silva                                     James DeRose                            Mick Stone                              skywalky
Bryan Siemon                                    James Williams                          Miguel Angel Rodriguez Jodar            SmokeMonster
Buster D                                        JD                                      Mikael Tillander                        SteelRush
Carl Hagström                                   Jeff Gerstmann                          Mike Holzinger                          Stefan Nordkvist
Carlos Del Alamo                                Jeff O'Meara                            Mister JBAM                             Stephen Marshall
Charles Sagett                                  Jeremy Glass                            MrX-8B                                  Stephen Pearce
Chris Jardine                                   Jeremy Hopkins                          Neil Maguire                            Steven
Chris Mawman                                    Jeremy Kaiman                           Nelson Jr                               Steven Wilson
Christian Bailey                                Jérôme Moreau                           Nelson Machado                          Stuart Fisk
Christopher Harvey                              Jeruro                                  Niall O'Higgins                         Suvodip Mitra
Christopher rumford                             Jesus Garcia                            Nicolas Hamel                           Sweetlilmre
Christopher Tuckwell                            Jo Tomiyori                             Obiwantje                               Thomas Davies
Dana Rich                                       Joe Kalwitz                             Oliver Jaksch                           Thomas Tahsin-Bey
Daniel Bauza                                    Johannes Reß                            Oliver Seitz                            Toby Boreham
Daniel Casadevall                               John Kelley                             Oliver Wndmth                           Tony Peters
Daniel Hochman                                  John Klimek                             Oscar Jacobsson                         type78
DarkStar7                                       John Perry                              Oscar Laguna Garcia                     UKShark
Darren Newman                                   John Stringer                           Outchocinco                             Ultrarobotninja
David Filskov                                   John Williams                           Owlnonymous                             Víctor Gomariz Ladrón de Guevara
David Taylor                                    Jon Taylor                              Paul Herbert                            Videodr0me
Don Gafford                                     Jootec from Mars                        Paulie B                                Violeta Martin Fernandez
Duane Hembrick                                  Jorge Galán                             Phillip McMahon                         Visa-Valtteri Pimiä
Dustin Gray                                     Jorge Slowfret                          Popov                                   vladimir
Dyllon Moseychuck                               Juan Diego Sánchez Noguera              Porkchop Express                        Vorvek
Ed Balan                                        Juan Manuel Sandoval Jr                 PsyFX                                   Wiedo Belochkin
Eduard Mateo                                    Keith Kelly                             QcRetro                                 William Clemens
EDUARDO ARANCIBIA PASTOR                        Ken ottosson                            Rafa Davila                             wvc
emceebois                                       Kevin Bidwell                           Raziel                                  Xtro
Eoin Gibney                                     Kyle Good                               remowilliams                            Xzarian
Evan Clarke                                     Kyle Troutman                           Renan Eler                              Zimmermann
```

Supporters for Renegade development:

```
8bits4ever             Aaron Ray              Adam Leslie            Adam Small
Adrian Labastida       Alan Shurvinton        Alda Alesio            Alex Mandic
Alexander Facchini     Alexander Lash         Alexander Upton        Alfonso Clemente
Allen Tipper           Allister Fiend         Alvaro Paniagua        Andrea Chiavazza
Andreas Micklei        Andrew Boudreau        Andrew Hannan          Andrew P Gibson
Andrew Schmidt         Angel Aguinaga         Angelfred              Angelo Kanaris
Anselmo Moreno         Anthony Monaco         Anton Gale             Aquijacks (Flashjacks
Arend Pronk            Arkadiusz              Arthur Fung            Aurich Lawson
BRCDEvg                Banane                 Bear S                 Ben Toman
BigRedPimp             Bit2018                Bitmap Bureau          Bitmaps Retro
Bliz 452               Blue Abs               Boris Pruessmann       Brandon Lennie
Brandon Peach          Brandon Thomas         Brent Fraser           Brian Peek
Brian Shiver           Bruce Fontaine         Bruno Meyere           Bruno Silva
Bryan Adams            Bryan Evans            Byshop303              Cameron Berkenpas
Cameron Tinker         Carlos Bailleres       Carlos Gruberman       Carrboroman
Cesar Sandoval         Charles                Chris                  Chris Angelini
Chris Babishoff        Chris D                Chris Hoff             Chris Maguire
Chris Mzhickteno       Chris O'Neil           Chris Petroni          Chris Scully
Chris Tuckwell         Chris W Miller         Chris smith            Christian Bailey
Christophe GARDES      Clinton Cronin         Cobra Clips            Colin Colehour
Cory Stargel           Dan Doyle              Daniel .               Daniel Casadevall
Daniel Dongil          Daniel Fowler          Daniel Page            Daniele Pellegrini
Darren Attwood         Darren Wootton         Daryll David           Dasutin
Dave Bennett           Dave Douglas           David Drury            David Fleetwood
David Jones            Denis Brækhus          Denny Letourneau       Diana Carolina
Didgeridoo             Didier Touron          Dimitris Zongas        Dr Catjail
Dr. Octagon            DrMnike                Dre137                 Edward Mallett
Emilio Fahr            Enthropy               Eren Kotan             Eric
Eric Gutt              Eric J Faulkes         Eric Sorensen          F34R
Fabio Michelin         Fabricio               Federico               Five Year Guy
Florian Raoult         Fred Rojas             Gavin C                GeorgeSpinner
Grant McNaught         Greg                   Greg Sargent           Gregory Val
Guillermo Tunon        HamsoloPlays           Handheld Obsession     Harmonica
Henry                  Henry R                Hentai Joe             Hugo Pinto
ItsBobDudes            JR                     JSwan                  Jack Sammons
Jacob Hoffman          Jacob Lawter           James Dingo            James Kilgore
James Wilson           Janne Heikkarainen     Jason Baker            Jerry Langwell
Jerry Suggs            Jesse Clark            Jim Knowler            JimLahey
Jimmy Richards         Jockel                 Joe Dinges             Joe Giuliano
Joel Albino            Johan Smolinski        John Figueroa          John Fletcher
John Silva             John T. Keen           John Wilson            Johnny harvick
Jonah Phillips         Jonathan               Jonathan Tuttle        JonathanValls
Joost Peters           Jork Sonkinfield       Jose Perez             Josep Barbie
Joseph Kulinski        Joseph Milazzo         Joseph Mogavero        Josh Mayer
Josh Yates-Walker      Justin D'Arcangelo     Kai Cherry             Kai Luotojoki
Kaiosten               Keith Gordon           Ken B                  Ken Scott
Kevin Dayton           Kike Alcor             KnC                    Kricys
KrzysFR                Kyle Pedersen          L.Rapter               Lakeside
Lee Grocott            Lee Osborne            Lucius Bono            Luis F Giron
M Reznor               MaDDoG                 Mack H                 Madox
Magnus Kvevlander      Manuel Astudillo       Marcello Medini        Marco Emparan
Mark Floyd             MarthSR                Martin Ansin           Matt Elder
Matt Evans             Matt Hargett           Matt Heinrich          Matt McCarthy
Matt Postema           Matthew Pollard        Matthew Woodford       MechaGG
MiSTer Retro           Michael Anderson       Michael Bariszlovits   Michael Berger
Michael Eggers         Michael Martin         Michael Rea            Michael_DKT
Mickaël Renou          Mike Holzinger         Mike Jegenjan          Mike Olson
Mottzilla              Nadir Shabazz          Nailbomb               Nando Iron
Nathan Souris          Neil St Clair          NerdyNester            Nic Kaiman
Nick Delia             Nick G                 Nick Gudauskas         Nico Stamp
Niko                   NonstopXiaowei         Noyman29               Obvious Fakename
OopsAllBerrys          Oriez                  Oskar Sigvardsson      Pablo Avila-Estevez
Patrick McCarron       Patrick Roman          Paul                   Paul Cunningham
Paul Hoggett           Paulo M.               Paweł Mandes           PeFClic
Pedro Santiago         Per Ole                Peter Mehes            Philip Lai
Philip Lawson          Pierre-Emmanuel Martin ProfessorAnon          R D
R Omar Leal            Rachael Netz           Rachel Schaeffer       Ralph Barbagallo
Ramon Gamaliel         RandomRetro            Raphael Melgar         Raul3D
RayGun                 RetroRGB               Rex Kung               Rex Willer
Richard Eng            Richard Murillo        Richard Simpson        Riyad Twair
Robert Daniel          Robert Hayes           Romain Dijoux          Romier Silvera
Ronald Dean            Ronan Amicel           Ruben                  Ryan
Ryan Clark             Ryan O'Malley          SIDKidd64              Saiyan
Sam Hall               Samuel Pizarro         Samuel Warner          Sang Hee
Sascha Zupanek         Schnookums             Ser Erris              Seth Wickline
Shad Uttam             Shannon King           Sherwood Hachtman      Sigmund68k
Skeletex               Spank Minister         Stadium ARTs           SteelRush
Stefan Krueger         Stephen R Price        Steve Lin              Steve Skrzyniarz
Steve Tack             Steven A               Steven Hansen          Stuart Morton
Sunder Raj             SuperBabyHix           Synbios                Taehyun Kim
Tales Dilli            Terse                  The Collector          The Video
Thomas Attanasio       Thomas Irwin           Thorias                Timothy Bearup
Tobias Dossin          Tom Milner             Tony Shong             Topher Campbell
Trifle                 Two Bards              Ty B                   VickiViperZabel
Victor Bly             Victor Fontanez        Weston Boldt           Will Abbott
William Clemens        William Tryon          Yunus Soğukkanlı       Zane
Zoltan Kovacs          albertprime            alejandro carlos       amdrgn
angel_killah           arcadebros             benedict lindley       blackwine
brian burney           cbab                   chauviere benjamin     circletheory
dARKrEIGn              dECKARD                datajerk               deathr0w
deathwombat            gunmakuma              jbrlll                 jim br
jonathan capparelli    kamel rasennadja       kccheng                kernelchagi
kerobaros              keropi                 liphy                  mattcurrie
meng po                metal                  ojwales                pacoarcade
raoulvp                retrod00d              rsn8887                slayer213
sourdille              tim rogers             tonitellezb            troy coberly
turbochop3300          twilitezoner           type78                 vampsthevampyre
xqwarzia               yoaarond               Δlain
```

Thank you all!
