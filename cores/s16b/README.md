# JTS16

You can show your appreciation through
* Patreon: https://patreon.com/jotego
* Paypal: https://paypal.me/topapate
* Github: https://github.com/sponsors/jotego

SEGA System 16 compatible verilog core for FPGA by Jose Tejada (jotego). This core was developed with the help of a SEGA System 16B model 171-5358 board lent by FunkyCochise and the Out Run board donated by Travis Brown.

This project aims to be compatible with System 16, Out Run and derivatives.

# Supported Games

Most games work correctly. Some games have problems mapping their inputs because the original arcade was not a joystick with buttons but something else hard to translate. Please check the [issues section in Github](https://github.com/jotego/jts16/issues).

Developer's note: encrypted games don't work if the core is compiled using the J68 CPU module for M68000.

# Special Inputs

Game           |  Players |  Analog    | Other
---------------|----------|------------|---------------
Passing Shot   |    4     |            |
SDI            |    1     |  2 axis    | trackball
Sukeban        |    1     |            | Keyboard-like
Major League   |    1     |  3 axis    |
Dump Matsumoto |    1     |            | inputs via 8751
Ace Attack     |    1     |            | inputs via CXD1095
Out Run        |    1     |  2 axis    |


# Core Division

Because of the hardware variety, there are different cores targeted for each of them

System               |  Core    | Logic Usage | BRAM Usage
---------------------|----------|-------------|-------------
16A                  | jts16    | 22,149      | 374,458
16B i8751            | jts16b   | 23,073      | 364,218
Super Hang-On        | jtshanon |             |
Out Run              | jtoutrun | 22,719      | 441,238

MiST has 608,256 memory bits and 24,624 logic elements.
Although the MCU can be synthesized in MiST and SiDi, timings are usually broken and requires several runs with different seeds because the FPGA is almost full. For MiSTer it seems to always go well.

The original Out Run design used a frame buffer to draw the sprites. The frame buffer is maintained for Pocket and MiSTer but it is not supported on some FPGA systems, like MiST. Because of the large number of sprites, it is not possible to process all sprite data in one scan line, so MiST and other systems some times have garbled lines as a result. This problem is minimized by doubling the video clock in those systems (up to 100MHz) but it still is visible in some scenes. Another side effect of missing the frame buffer is that sprites appear one-frame ahead of time in those systems.

Because of lack of sufficient internal FPGA RAM (called BRAM), MiST and other smaller systems cannot run the encrypted versions of these games.

Despite these problems, the MiST version is fully playable.

# PCB Check List

These items need double checking on the PCB

* How much shadow is created by sprite palette 3F? The core assumes 25% attenuation

# Schematics

The KiCAD schematics developed by JOTEGO's team are in the sch folder of each core. Some of them only reproduce one aspect of the board that we needed to double check. A link to PDF versions is available below.

- [JOTEGO's schematics for System 18](https://github.com/jotego/jtbin/tree/master/sch/s18.pdf)

# Clocks

HSync (OSSC) 15.73kHz
VSync (Analog Discovery) 60.042Hz
Vblank: 2.427 ms (38 lines)

Crystal Oscillators (System 16B)

Location | Freq (MHz) | Use
---------|------------|-------
B1       | 20         | M68k
E12      | 8.000      | Sound
G1       | 25.1748    | Video

Pixel clock: 6.2937 MHz

Estimated geometry:
    400 pixels/line = 63.555us = 15.734 kHz
    262 lines/frame

Core clock: 50.3496 MHz

Dividers:

Clock   |  m   |  n
--------|------|-----
25.1748 |   1  |   2
20      |  29  |  73
8       | 109  | 686

# 8255 Connections

Line   |  Destination
-------|--------------
PA     |  Sound latch
PB3-0  |  Coin lock ?
PB4    |  Display enable
PB6-5  |  ?
PB7    |  Flip (pull down)
PC7    |  Port A handshaking signal /OBF -> Sound /NMI
PC6    |  Port A handshaking signal ACK
PC5-3  |  Unconnected
PC2    |  To PAL 315-5107 pin 9 (SCONT1)
PC1    |  To PAL 315-5108 pin 19 (SCONT0)
PC0    |  To MUTE input on MB3733 amplifier (0=sound disabled)

# Memory Size

Item      |  Size (kB)
----------|------------
Main ROM  |  512
Main RAM  |   16
Object    |    2
Palette   |    4
Char      |    4
Scroll    |   32 (?)

# Support

You can show your appreciation through
* Patreon: https://patreon.com/jotego
* Paypal: https://paypal.me/topapate

# Licensing

Contact the author for special licensing needs. Otherwise follow the GPLv3 license attached.

# Patron Acknowledgement

Apart from the directors and supported shown in the core credits screen,
the following patrons also supported the development of JTS16:

```
0x157fae8              3style                 8bits4ever             Aaron Ray
Adam Leslie            Adam Rykowski          Adam Small             Adrian Labastida
Alan Shurvinton        Alda Alesio            Alec Peden             Alex Baldwin
Alex Mandic            Alexander Facchini     Alexander Lash         Alexander Upton
Alfonso Clemente       Allen Tipper           Allen Tulowitzki       Allister Fiend
Alvaro Paniagua        Andrea Chiavazza       Andreas Micklei        Andrew Boudreau
Andrew Hannan          Andrew P Gibson        Andrew Schmidt         Angel Aguinaga
Angelfred              Angelo Kanaris         AnotherJoe             Anselmo Moreno
Anthony Cheng          Anthony Monaco         Anton Gale             Arend Pronk
Arkadiusz              Arthur Fung            Aurich Lawson          BRCDEvg
Banane                 Barley Cheezers        Bear S                 Ben Cullen
Ben Tiefert            Ben Toman              BigRedPimp             Bit2018
Bitmap Bureau          Bitmaps Retro          Bliz 452               Boris Pruessmann
Brandon Lennie         Brandon Peach          Brandon Thomas         Brandoon
Brent Fraser           Brian Peek             Brian Shiver           Brianna Cluck
Bruce Fontaine         Bruno Meyere           Bruno Silva            Bryan Evans
Byshop303              Cameron Berkenpas      Cameron Tinker         Carlos Bailleres
Carlos Gruberman       Casey Hamann           Cedric Vioget          Cesar Sandoval
Chad Page              Charles                Chris                  Chris Angelini
Chris Babishoff        Chris D                Chris Davis            Chris Hauk
Chris Hoff             Chris Maguire          Chris Mzhickteno       Chris O'Neil
Chris Petroni          Chris Scully           Chris Sewell           Chris Tuckwell
Chris W Miller         Chris keesler          Chris smith            Christophe GARDES
Clayton Anderson       Clinton Cronin         Cobra Clips            Colin Colehour
Cory Sizemore          Cory Stargel           Cosmic Savant          Damien D
Daniel                 Daniel .               Daniel Dongil          Daniel Fowler
Daniel Page            Daniele Pellegrini     Danny Garfield         Darren Attwood
Darren Wootton         Daryll David           Dasutin                Dave Bennett
Dave Douglas           Dave Nice              David                  David Drury
David Fleetwood        David Jones            David Stone            Denis Brækhus
Dennis Ranker          Denny Letourneau       Devon Meunier          Diana Carolina
Didier Touron          Dimitris Zongas        Douglas Alves          Dr Catjail
Dr. Octagon            DrMnike                Dre137                 Dubesinhower
Ed                     Edward Mallett         Enthropy               Epixjava
Eren Kotan             Eric                   Eric Gutt              Eric J Faulkes
Eric Schneider         Eric Sorensen          F34R                   FROELIGER
Fabio Michelin         Fabrice Odero          Fabricio               Federico
Five Year Guy          Flavio Real            Florian Raoult         Franco Catrin
Fred Rojas             Gareth Jones           Gavin C                GeorgeSpinner
GigaBoots              Girth305               Glenn Percival         Gord Allott
Grant McNaught         Greg Sargent           Gregory Val            Grummkol
Guillermo Tunon        Gutxi Haitz            Guy Taylor             Gwaland
HamsoloPlays           Harmonica              Henry                  Henry R
Hentai Joe             Hugo Pinto             ItalianGrandma         ItsBobDudes
JR                     JSwan                  Jack Sammons           Jacob Hoffman
Jacob Lawter           Jakob Schmid           James Dingo            James Durden
James Mann             James Nivin            James Trautner         James Wilson
Janne Heikkarainen     Jason Baker            Javier Heredia         Jayson Larose
Jeremy Hopkins         Jerry Langwell         Jerry Suggs            Jerry Yuan
Jesse Clark            Jesse Rankin           Jim Knowler            Jimmy Richards
Jockel                 Joe Dinges             Joe Giuliano           Joel Albino
John Figueroa          John Fletcher          John Silva             John T. Keen
John Torn              John Wilson            John Woods             Johnny harvick
Jonah Phillips         Jonathan               Jonathan Tuttle        JonathanValls
Joost Peters           Jork Sonkinfield       Jose Perez             Josep Barbie
Joseph Kulinski        Joseph Milazzo         Joseph Mogavero        Josh Hogan
Josh Mayer             Josh Yates-Walker      Juan Barriga           Juan Pablo
Justin D'Arcangelo     Kai Cherry             Kai Luotojoki          Kaiosten
Kaya Bear              Keith Gordon           Kellerkind             Ken B
Ken Scott              Kevin Dayton           Kike Alcor             Kimberley Fisher
KnC                    Konrad                 Kricys                 Kristian.
KrzysFR                Kyle Pedersen          L.Rapter               Lakeside
Lee Grocott            Lee Osborne            Lucian                 Lucius Bono
Luis F Giron           M Reznor               MaDDoG                 Mack H
Madox                  Magnus Kvevlander      Mane Function          Manksalot
Manuel Astudillo       Marc Nuernberger       Marcello Medini        Mark Floyd
Mark Saunders          MarthSR                Matt Bouverie          Matt Evans
Matt Hargett           Matt Heinrich          Matt McCarthy          Matt Postema
Matt Simonds           Matt Vulcano           Matthew Compston       Matthew Woodford
Matthieu Marchione     Max                    Max Power              MechaGG
MiSTer Retro           Michael Anderson       Michael Bariszlovits   Michael Martin
Michael Rea            Michael_DKT            Mickaël Renou          Mike Holzinger
Mike Jegenjan          Mottzilla              Mysterious Benefactor  Nadir Shabazz
Nailbomb               Nando Iron             Nathan Souris          NerdyNester
Nicholas Bold          Nick Daniels           Nick Delia             Nick Gudauskas
Nico Stamp             Niko                   NonstopXiaowei         Noyman29
Obvious Fakename       Omar                   Omar Najera            OopsAllBerrys
Oriez                  Oskar Maria            Oskar Sigvardsson      Oyvind Christiansen
Pablo Avila-Estevez    Patrick McCarron       Patrick Roman          Paul
Paul Cunningham        Paulo M.               Paulo Nascimento       Paweł Mandes
PeFClic                Pedro Santiago         Per Ole                Peter Mehes
Philip Lai             Philip Lawson          Pierre-Emmanuel Martin Potato
ProfessorAnon          R Omar Leal            Rachel Schaeffer       Ralph Barbagallo
Ramon Gamaliel         RandomRetro            Raphael Melgar         Raul3D
RayGun                 RetroRGB               Retro_Brewz            Rex Kung
Rex Willer             Richard Eng            Richard Murillo        Richard Simpson
Robert Hayes           Robin Hertzberg        Romain Dijoux          Romier Silvera
Ronald Dean            Ronan Amicel           RoryDropkick           Ruben
Rune P                 Russ Crandall          Ryan                   Ryan Clark
Ryne Weiss             SIDKidd64              Saiyan                 Sam Hall
Samuel Pizarro         Samuel Warner          Sang Hee               Sascha Zupanek
Schnookums             Scott Bender           Ser Erris              Seth Wickline
Shad Uttam             Shannon King           Shen mue               Sherwood Hachtman
Sigmund68k             Skeletex               Spank Minister         Stadium ARTs
SteelRush              Stefan Krueger         Stephen                Stephen Pagenstecher
Stephen R Price        Steve Lin              Steve Skrzyniarz       Steve Tack
Steven A               Steven Hansen          Stoneman               Stuart Morton
Sunder Raj             SuperBabyHix           Synbios                TMoney
Taehyun Kim            Tales Dilli            Terse                  The Collector
The Video              Thomas Attanasio       Thorias                Tim Inman
Timothy Bearup         Tobias Dossin          Tom Milner             Tony Shong
Trifle                 Two Bards              Ty B                   Tyson Hanes
VickiViperZabel        Victor Bly             Victor Emmanuel        Victor Fontanez
Vincent Lietart        Wesley Lyons           Will Abbott            William Clemens
William Roussin        William Tryon          Xaxius                 Yunus Soğukkanlı
Zoltan Kovacs          aguijon                alejandro carlos       alexcom
amdrgn                 angel_killah           arcadebros             blackwine
brian burney           cbab                   chauviere benjamin     dARKrEIGn
dECKARD                datajerk               deathwombat            dzponce11
eclipse                eltee                  ill_deez               jbrlll
jim br                 jonathan capparelli    kccheng                kernelchagi
kerobaros              keropi                 liphy                  mattcurrie
mattyhochs             meijin3                metal                  myusernamewastaken
ogge_leander           ojwales                patrick woodburn       raoulvp
retroboi               rsn8887                slayer213              sourdille
thomas winfrey         tim rogers             tonitellezb            troy coberly
turbochop3300          twilitezoner           type78                 vampsthevampyre
yoaarond
```