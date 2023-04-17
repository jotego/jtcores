# Haunted Castle Compatible FPGA core by Jotego

Konami developed a graphic chip called 007121. This was used in several games.
This project aims to accurately replicate those games in modern electronics,
namely FPGA systems.

Haunted Castle is a rare arcade game. Its PCB is hard to find and the home
conversions (emulation) done for PS2 is also an expensive item. On top of that
it depends on Konami's custom CPU, for which there are no replacements, which
shortens the life of the original PCBs.

# 007121 Series Arcade Titles

Name            | JT Core | Main CPU   | Sound CPU  | K007121 units | Audio
----------------|---------|------------|------------|---------------|-------------
Contra          | contra  | HD63C09EP  | 68B09EP    | x2            | YM2151
Combat School   | comsc   | 6309       | Z80        | x2            | YM2203 + UPD7759
Haunted Castle  | castle  | KONAMI-2   | Z80        | x2            | YM3812 + K007232 + K051649
Fast Lane       | flane   | 6309       | -          | x1 + K051733  |          K007232 x 2
MX5000          | mx5k    | 6309       | Z80        | x2            | YM2151 + K007232
Labyrinth Runner| labrun  | 6309       | -          | x1 + K051733  | YM2203 x 2

MX5000 uses two K007121 but the second one is connected in such a way
that it only serves to extract the 4-bit palette for the current pixel.

Other games using the KONAMI-2 CPU:

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
* Patreon: https://patreon.com/jotego
* Paypal: https://paypal.me/topapate

# Thanks to April 2023 Patrons

```
0x157fae8              3style                 8bits4ever             A Hernandez
A Murder               Aaron Ray              Aaron S                Adam Foster
Adam Leslie            Adam Small             Adam Zorzin            Adrian Labastida
Alan McGrath           Alan Shurvinton        Alberta Dave           Alda Alesio
Alden                  Alec Peden             Alex Baldwin           Alex Mandic
Alexander Facchini     Alexander Lash         Alexander Upton        Alfonso Clemente
Alfredo Henriquez      AllDarnDavey           Allen Tipper           Allen Tulowitzki
Allister Fiend         Alvaro Paniagua        Andrea Chiavazza       Andreas Micklei
Andrew Boudreau        Andrew Hannan          Andrew Kaczrowski      Andrew Schmidt
Angel Aguinaga         Angelfred              Angelo Kanaris         AnotherJoe
Anselmo Moreno         Anthony Cheng          Anthony Monaco         Antoine Mariette
Anton Gale             Antwon                 Aquijacks (Flashjacks  Arend Pronk
Arjan de Lang          Arkadiusz              Armin Hierstetter      Arnulf Eide
Arthur Blough          Arthur Fung            Aunaste                Aurich Lawson
AzathothCultist        BRCDEvg                Banane                 Barley Cheezers
Bear S                 Ben                    Ben Cullen             Ben Mininberg
Ben Tiefert            Ben Toman              BigRedPimp             Bit2018
Bitmap Bureau          Bitmaps Retro          Bliz 452               Bluezer222
Boris Pruessmann       Brad Higginbotham      Brandon Lennie         Brandon Peach
Brandon Smith          Brandon Thomas         Brandon Yoder          Brandoon
Brent Fraser           Brian Birkinbine       Brian Nagel            Brian Peek
Brian Plummer          Brian Shiver           Brianna Cluck          Bruce Fontaine
Bruno Freitas          Bruno Meyere           Bruno Silva            Bryan Evans
Byshop303              Cameron Berkenpas      Cameron Tinker         Carlos Bailleres
Carlos Gruberman       Casey Hamann           Cedric Vioget          Cesar Sandoval
Chad Page              Chance Richmond        Charles                Charles Paek
Chris                  Chris Angelini         Chris Babishoff        Chris Brentano
Chris Chung            Chris Coughlan         Chris D                Chris Davis
Chris Hauk             Chris Hoff             Chris King             Chris Maguire
Chris Mzhickteno       Chris Petroni          Chris S                Chris Scully
Chris Sewell           Chris Tuckwell         Chris W Miller         Chris Waltham
Chris keesler          Chris smith            Christophe GARDES      Chuong Dang
Clayton Anderson       Clinton Cronin         Clinton McCarty        Cobra Clips
Coldheat007            Colin Colehour         Collidingforces        Cory Sizemore
Cosmic Savant          Craig McLaughlin       Crystal Cauley         Dakken
Damien D               Dan Kelley             Dane Biegert           Daniel
Daniel .               Daniel Dongil          Daniel Flowers         Daniel Fowler
Daniel Ibanez          Daniel Page            Daniel Zee             Daniel Zetterman
Daniele Pellegrini     Danny Austin           Danny Garfield         Darren Attwood
Darren Wootton         Daryll David           Dasutin                Dave Bennett
Dave Douglas           Dave Nice              David                  David Drury
David Fleetwood        David Frost            David Gallène          David Osborne
David Stone            DeanoC                 Denis Brækhus          Dennis Ranker
Denny Letourneau       Devon Meunier          Diana2Carolina         Didgeridoo
Didier Malenfant       Didier Touron          Diego Farrell          Dimitris Zongas
Douglas Alves          Dr Catjail             Dr. Octagon            DrMnike
Dre137                 Drew Roberts           Dubesinhower           Dward Venegas
Ed                     Edgar Fuentes          EdgarsDouble           Edward Mallett
Emile Denichaud        Enthropy               Enzo                   Epixjava
Eren Kotan             Eric                   Eric Gutt              Eric J Faulkes
Eric Schlappi          Eric Schneider         Eric Sorensen          Erik
F34R                   FROELIGER              Fabian L               Fabio Michelin
Fabrice Odero          Fabricio               Fahim Rahman           Federico
Fernando Irons         Five Year Guy          Florian Raoult         Focux
Francis B              Franco Catrin          Frank Brevoort         Frank Hoedemakers
Frank Schwab           Fred Rojas             GarethY                Gavin C
Geddon                 GeorgeSpinner          GigaBoots              Girth305
Glenn Percival         Gluthecat              GohanX                 Gord Allott
Gordon Coughlin        Grant McNaught         Greg                   Greg Sargent
Gregory Val            Grummkol               Grzegorz {NineX}       Guillermo Tunon
GuitarJedi             Gutxi Haitz            Guy Taylor             Gwaland
HFSPlay                HamsoloPlays           Handheld Obsession     Hans Baier
Harmonica              Heinz Stampfli         Henry                  Henry R
Hermes Yan             Hilton Price           Hugo Pinto             Hunter
Ibrahim                Igor Brodecki          IndieKebab             ItalianGrandma
ItsBobDudes            Ivan Vodopiviz         JAMES D BOOTH          JOSE LUIS
JSwan                  Jack Sammons           Jacob Hoffman          Jacob Lawter
Jakob Schmid           James Boone            James Dingo            James Ervin
James Miller           James Nivin            James Trautner         James Wilson
Janne Heikkarainen     Jason Baker            Jason Dee              Jason Jacobs
Javier Heredia         Jayson Larose          Jeff Roberts           Jeremie Barnes
Jeremy Hopkins         Jeremy Kelaher         Jerry Langwell         Jerry Suggs
Jerry Yuan             Jesse Clark            Jesse Rankin           Jesus Garcia
Jesus Rodriguez        Jim Hendricks          Jim Knowler            JimLahey
Jimmy Dozier           Jimmy Ecker            Jimmy Kim              Jimmy Richards
Jindo Fox              Jms                    Job van                Jockel
Joe Dinges             Joe Giuliano           Joel Albino            Johan Smolinski
John Dawson            John Figueroa          John Fletcher          John Hood
John K                 John T. Keen           John Torn              John Wilson
John Woods             Johnny harvick         Jon Prusik             Jonah Phillips
Jonathan               Jonathan Brochu        Jonathan Loor          Jonathan Tuttle
Joost Peters           Jorge                  Jorge Crisostomo       Jork Sonkinfield
Jose Gabriel           Jose L                 Jose Perez             Josep Barbie
Joseph Campo           Joseph Johnston        Joseph Kulinski        Joseph Milazzo
Joseph Mogavero        Josh Hogan             Josh Yates-Walker      Juan Barriga
Juan Pablo             Julian Baptiste        Julien Perrot          Justin D'Arcangelo
Justin Rudebaugh       Kai Cherry             Kai Luotojoki          Kaiosten
Kaya Bear              Keith Duncan           Keith Gordon           Kellerkind
Ken B                  Ken Scott              Kendrick Hughes        Kevin Dayton
Kevin Gudgeirsson      Kevin Miller           Kike Alcor             Kimberley Fisher
KnC                    Konrad                 Kricys                 Kristian.
Krisztian Lanyi        KrzysFR                Kyle Pedersen          Kyle Peters
Kyo Kim                L.Rapter               LFT                    Lakeside
Lance Bohy             Lars Vonhof-Hunold     Lee Grocott            Lee Osborne
LoBai Zen              Luc JOLY               Lucian                 Lucius Bono
Luis F Giron           M Reznor               MaDDoG                 Mack H
Madox                  Magnus Aspling         Magnus Kvevlander      Mane Function
Manfred Müller         Manksalot              Manuel Astudillo       Marc Nuernberger
Marcello Medini        Marco                  Marco Cuevas           Marco Emparan
Mark Baffa             Mark Floyd             Mark Jeffers           Mark R
Mark Saunders          Markonnen              MarthSR                Matheus
Matt Bouverie          Matt Elder             Matt Evans             Matt Hargett
Matt Heinrich          Matt McCarthy          Matt Postema           Matt Simonds
Matt Vulcano           Matthew Compston       Matthew Heyman         Matthew J
Matthew Woodford       Matthieu Marchione     Max                    Max Power
Me whenever            MechaGG                Megan Alnico           Mehdi Daouas
MiSTer Retro           Michael Anderson       Michael Bariszlovits   Michael Berger
Michael Eggers         Michael Maple          Michael Petri          Michael Rea
Michael_DKT            Mick Stone             Mickaël Renou          Mike Holzinger
Mike Jegenjan          Mike Olson             Mottzilla              Murray Sneddon
Mysterious Benefactor  NINE                   Nadir Shabazz          Nailbomb
Narugawa               Nathan Souris          Neil St Clair          NerdyNester
Nic B.                 Nic Kaiman             Nicholas Bold          Nick Daniels
Nick Delia             Nick Gudauskas         Nico Stamp             Nicolas Hurtado
Niko                   NonstopXiaowei         Norman Wehrle          Noyman29
Obvious Fakename       Odilio FRAGATA         Oliver Heilmann        Omar Najera
Omega16bit             OopsAllBerrys          Oriez                  Oskar Maria
Oskar Sigvardsson      OtakuAnthony           Oyvind Christiansen    Pablo Avila-Estevez
Parker Blackman        Pascal Courtois        Patrick McCarron       Patrick Roman
Paul Cunningham        Paul Hoggett           Paul Jr                Paulo M.
Paulo Nascimento       Paweł Mandes           PeFClic                Pedro Santiago
Per Ole                Peter Mehes            Philip Lai             Philip Lawson
Piafoman               Pierre-Emmanuel Martin Pontus Nyholm          Potato
Prime1984              ProfessorAnon          Pumpy Crumpy           R Omar Leal
Rachel Schaeffer       Ralph Barbagallo       Ramon Gamaliel         Ramon jimenez
RandomRetro            Raph_friend            Raphael Melgar         Raul3D
Rautz                  RayGun                 ReTr0~g!GGles          Reborn 187
RetroRGB               Retro_Brewz            Rex Kung               Rex Willer
Richard Eng            Richard Murillo        Richard Simpson        Richard Smith
Rick Ochoa             Riyad Twair            Rob Mossefin           Robert Hayes
Robin Hertzberg        Romain Dijoux          Romier Silvera         Ronald Dean
Ronan Amicel           Ronin Yojimbo          Roro                   RoryDropkick
Ruben                  Rufo Sanchez           Rune P                 Russ Crandall
Ryan                   Ryan Clark             Ryan Fig               Ryan Kasper
Ryan Wilson            Ryne Weiss             SIDKidd64              Saiyan
Sam Hall               Samuel Pizarro         Samuel Warner          Sang Hee
Sascha Zupanek         Sayit BELET            Schnookums             Scott Bender
Sean Lake              Sean Quinn             Ser Erris              Seth Wickline
Shad Uttam             Shannon King           Shen mue               Sherwood Hachtman
Shon Garraway          Sigmund68k             Simon Osborne          Skeletex
Sonthaya Sonthaya      Sonthayaya Siha        Spank Minister         Stadium ARTs
SteelRush              Stefan Krueger         Stephen                Stephen Pagenstecher
Stephen R Price        Steve Ikeguchi         Steve Lin              Steve Skrzyniarz
Steve Tack             Steven A               Steven Hansen          Stoneman
Stuart Morton          Sunder Raj             SuperBabyHix           Sweaty McNasty
Synbios                TAKA Hara              TM421                  TMoney
Taehyun Kim            Tales Dilli            Terse                  TgrMstr
The Collector          The Video              TheLevelOfDetail .     Thomas Attanasio
Thomas Irwin           Thomas Popper          Thomas Ruf             Thorias
Tim Inman              Timothy Bearup         Timothy Latunde        Tobias Dossin
Tom Milner             Tony Shong             Topher Campbell        Travis Brown
Travis Kennington      Trifle                 Troy                   Trucker 69
Two Bards              Ty B                   Tyson Hanes            VERHILLE Arnaud
VickiViperZabel        Victor Bly             Victor Emmanuel        Victor Fontanez
Victor Yoon            Vincent Lietart        WackyDelly             Wesley Lyons
Weston Boldt           Will Abbott            William Clemens        William Roussin
William Tryon          XC-3730C               Xaxius                 Yonghan
Yoshi9288              Yunus Soğukkanlı       Zach Marquette         Zane
Zoltan Kovacs          aguijon                alejandro carlos       alexcom
amdrgn                 angel_killah           arcadebros             benedict lindley
blackwine              brian burney           cbab                   chauviere benjamin
circletheory           dARKrEIGn              dECKARD (Daniel        dannahan
datajerk               deathwombat            derFunkenstein         dzponce11
eclipse                eltee                  fbmg                   ill_deez
iunno                  jbrlll                 jim br                 jonathan capparelli
jose luis              jp                     juan jesus             kadybat
kccheng                kernelchagi            kerobaros              keropi
liphy                  mattcurrie             mattyhochs             meijin3
metal                  moalthan               myusernamewastaken     natalie
ogge_leander           ohmy                   ojwales                olivier bernhard
patrick pejic          patrick woodburn       raoulvp                retroboi
rsn8887                slayer213              sourdille              spaceduck
starman_jr             thomas winfrey         tim rogers             tonitellezb
troy coberly           turbochop3300          twilitezoner           type78
vampsthevampyre        yoaarond               Δlain                  종규 박
```
