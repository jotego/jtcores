# KONAMI 007121 Arcades Conversion to FPGA by Jotego

Konami developed a graphic chip called 007121. This was used in several games.
This project aims to accurately replicate those games in modern electronics,
namely FPGA systems.

# Arcade Titles

Name            | JT Core | Main CPU   | Sound CPU  | K007121 units | Audio
----------------|---------|------------|------------|---------------|-------------
Contra          | contra  | HD63C09EP  | 68B09EP    | x2            | YM2151
Combat School   | comsc   | 6309       | Z80        | x2            | YM2203 + UPD7759
Haunted Castle  |         | KONAMI-2   | Z80        | x2            | YM3812 + K051649
Fast Lane       | flane   | 6309       | -          | x1 + K051733  | K007232 x 2
MX5000          | mx5k    | 6309       | Z80        | x2            | YM2151 + K007232
Labyrinth Runner| labrun  | 6309       | -          | x1 + K051733  | YM2203 x 2

MX5000 uses two K007121 but the second one is connected in such a way
that it only serves to extract the 4-bit palette for the current pixel.

Games using the KONAMI-2 CPU:

* 88 Games
* Aliens
* Ajax
* Block Hole
* Chequered Flag
* Crime Fighters
* Escape Kids
* Gang Busters
* Haunted Castle
* Parodius
* Super Contra
* Surprise Attack
* Roller Games
* The Simpsons
* Thunder Cross
* Vendetta

# Supported FPGA Platforms

Binary RBF files for MiST, MiSTer and SiDi will be provided for in
https://github.com/jotego/jtbin

# Known Issues

The score colour in Fast Lane might be wrong. I do not have the board and
I have not found any original footage to verify it. However, the way the
chips are connected is the most logical way and the chip count matches that
seen in [PCB photos](doc/pcb/Fastlane.jpg). Thus, I think it is most likely
right.

# Compiling

You need to have Quartus installed in a linux machine. Clone this repository and
its submodules following standard git instructions. Go to the root folder and
type `source setprj.sh`. Now you can compile the core with `jtcore contra -mist`
Use `-mister` or `-sidi` if appropriate.

Also check the instructions in [modules/jtframe/doc/compilation.md](JTFRAME)

# ROM file

Use the mra file in rom/mra for MiSTer. For MiST/SiDi, convert the mra to a rom
file using the mra tool.

# External Modules Used

Name          | Purpose           | Author  | URL
--------------|-------------------|---------|---------------------------------
JT7759        | ADPCM  sound      | jotego  | https://github.com/jotego/jt7759
JT12          | YM2203 sound      | jotego  | https://github.com/jotego/jt12
JT51          | YM2151 sound      | jotego  | https://github.com/jotego/jt51
JTFRAME       | FPGA framework    | jotego  | https://github.com/jotego/jtframe

# KONAMI 007121

Furrtek made a full RE of this chip [here](https://github.com/furrtek/VGChips/tree/master/Konami/007121)

The internal register mapping has R/W access from the CPU. If the row scroll registers are prevented from reading, Combat School boots up with an error on "zure RAM", note that "zure" is Japanese for scroll.

Address    |   Purpose
-----------|------------
20-3F      | zure RAM - row scroll
40-5F      | text tilemap selection (over scroll tilemap)
2000-2FFF  | VRAM
3000-3FFF  | OBJ RAM

## Tilemap

Attribute byte

Bits   | Usage            | Condition
-------|------------------|------------------
 2:0   | Palette          |
 3     | Palette MSB      | MMR[6][0] high
 6:3   | Bank bits 4:1    | Enabled by MMR[4] and MMR[5]
 7     | Bank bit 0       |

## Pinout

Pin Name | Number | I/O | Usage
---------|--------|-----|-----------------------------------------------
  H2     |  68    |  O  | 0=output ROM addr is for tilemaps, 1=objects
  A13    | 109    |  I  | 0=internal config registers, 1=VRAM
  A12    |  52    |  I  | 0=tilemaps, 1=objects
  NXCS   |  63    |  I  | chip select
  COA6   |  81    |  O  | palette RAM address 6
  COA5   |  20    |  O  | palette RAM address 5
  COA4   |  80    |  O  | palette RAM address 4
  COA3   |  79    |  O  | palette RAM address 3
  COA2   |  18    |  O  | palette RAM address 2
  COA1   |  16    |  O  | palette RAM address 1
  COA0   |  17    |  O  | palette RAM address 0
  CK24   |   1    |  I  | 24MHz input clock
  CK2    |   4    |  O  | CK24/4 (6MHz output clock)
  NE     |  65    |  O  | E signal for M6809
  NQ     |  66    |  O  | Q signal for M6809

## Register Map

There are 8 programmable registers, most of them are 8-bit long, some
have unused bits which do not connect to any physical register. Register
cannot be read back.

# Support

The *jotego* nickname had already been used by other people so on some networks
you will find me as *topapate*.

Contact via:
* https://twitter.com/topapate
* https://github.com/jotego

You can show your appreciation through
* Github:
* Patreon: https://patreon.com/jotego
* Paypal: https://paypal.me/topapate

# Thanks to September 2021 Patrons

80's spaceman        Adam Leslie          Adam Small           Adam Zorzin
Adrian Labastida     Adrian Nabarro       Alan Shurvinton      Alexander Lash
Alexander Upton      Alfonso Clemente     Alvaro Paniagua      Andrea Chiavazza
Andreas Micklei      Andrew Boudreau      Andrew Hannan        Andrew P Gibson
Andrew Schmidt       Angelfred            Angelo Kanaris       Anthony Monaco
Antoine Mariette     Anton Gale           Antwon               Aquijacks (Flashjacks
Arend Pronk          Arthur Blough        Arthur Fung          BRCDEvg
Banane               Bear S               Ben Toman            Bitmap Bureau
Bitmaps Retro        Bliz 452             Brandon Peach        Brandon Smith
Brandon Thomas       Brent Fraser         Brian Peek           Brian Plummer
Bruno M              C                    Cameron Tinker       Carrboroman
Cesar Sandoval       Charles              Chris Chung          Chris Mzhickteno
Chris Tuckwell       Chris W Miller       Chris smith          Christian Bailey
Clinton Cronin       Cobra Clips          Colin Colehour       Colt83
DARK WEB DANGer      Dan Doyle            Daniel               Daniel Casadevall
Daniel Fowler        Daniel Page          Daniel Tibi          Daniel Zetterman
Darren Wootton       Dasutin              David Drury          David Filskov
David Fleetwood      David Jones          Denis Brækhus        Diana Carolina
Didier Touron        Dimitris Zongas      Dr Catjail           DrMnike
Dre137               Eren Kotan           Eric J Faulkes       Eric Schlappi
Federico             Five Year Guy        Florian Raoult       Focux
GeorgeSpinner        Gluthecat            GohanX               Gonzalo Lopez
Goolio               Greg                 Gregory Val          HFSPlay
Handheld Obsession   Henry                Hugo Pinto           Ibrahim
ItsBobDudes          JOSE LUIS            JR                   Jack Sammons
Jacob Hoffman        Jacob Lawter         James B Ross         James Dingo
James Kilgore        Javier Rodas         Jeff Roberts         Jeremy Hasse
Jerry Suggs          Jesse Clark          Jim Knowler          JimLahey
Jimmy Dozier         Jockel               Johan Smolinski      John Figueroa
John Fletcher        John Hood            John Silva           John T. Keen
John Wilson          Jonah Phillips       Jonathan Brochu      Jonathan Loor
Jonathan Tuttle      Joost Peters         Jootec from          Jorge
Jork Sonkinfield     Joseph Kulinski      Joseph Milazzo       Joseph Mogavero
Josh Emery           Josh Mayer           Josiah Wilson        Justin D'Arcangelo
Kai Cherry           Keith Gordon         Kem Yos              Ken Scott
Kevin Gudgeirsson    KnC                  KrzysFR              L.Rapter
LFT                  Lakeside             Laurent Cooper       Lee Grocott
Lee Osborne          Luc JOLY             Luis F Giron         MaDDoG
Mack H               Madox                Magnus Kvevlander    Manuel Astudillo
Marco Emparan        Mark Baffa           Mark Davidson        MarthSR
Martin Ansin         Matheus              Matt Elder           Matt Evans
Matt Lichtenberg     Matt McCarthy        Matt ODonnell        Matthew Humphrey
Matthew Woodford     Me getting           MechaGG              Megan Alnico
Michael Anderson     Michael Berger       Michael C            Michael Deshaies
Michael Rea          Michael_DKT          Mick Stone           Mike Holzinger
Mike Jegenjan        Mike Olson           Mike Parks           Mottzilla
NINE                 Nailbomb             Narugawa             Neil St Clair
NerdyNester          Nick Delia           Nick G               Nico Stamp
Nicolas Hurtado      Niko                 NonstopXiaowei       Norman Wehrle
OopsAllBerrys        Oriez                Oskar Sigvardsson    Parker Blackman
Pascal Courtois      Patrick Roman        Paul Cunningham      Paul Hoggett
Paul M               Paulo M.             Paweł Mandes         PeFClic
Per Ole              Philip Lai           Philip Lawson        Piafoman
Pierre-Emmanuel M.   Pontus Nyholm        Rachael Netz         Rachel Schaeffer
RayGun               RetroRGB             Richard Eng          Richard Murillo
Richard Simpson      Rick Ochoa           Robert Daniel        Romain Dijoux
Ronald Dean          Ronan Amicel         Roro                 Ryan
Ryan O'Malley        Sam Hall             Samuel Warner        Schnookums
Shannon King         Spank Minister       SteelRush            Stefan Krueger
Stephen R Price      Steve Ikeguchi       Steve Skrzyniarz     Steve Tack
Steven Hansen        Stuart Morton        SuperBabyHix         Syrotuck
Taehyun Kim          Taiki Hosoda         Tales Dilli          Tarnjeet Bhachu
Tatton Partington    TealShark            Terse                The Collector
The Video            TheLevelOfDetail .   Thomas Attanasio     Thomas Capetanakis
Thomas Irwin         Timothy Bearup       Tobias Dossin        Tom Milner
Travis Brown         Trifle               Turboman UK          Ty B
VickiViperZabel      Victor Bly           Victor Fontanez      Will Abbott
William Clemens      Yunus Soğukkanlı     Zach Marquette       Zoltan Kovacs
albertprime          alejandro carlos     angel_killah         arcadebros
benedict lindley     blackwine            brian burney         cbab
chauviere benjamin   datajerk             deathwombat          derFunkenstein
gunmakuma            joshewah777          kamel rasennadja     kccheng
kernelchagi          liphy                meng po              natalie
nonamebear           qzxcvbn              retrod00d            rsn8887
slayer213            taal.M               tonitellezb          troy coberly
yoaarond
