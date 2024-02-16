# JTSIMSON FPGA core Compatible with Konami's The Simpsons hardware

By Jose Tejada (@topapate)

You can show your appreciation through
* [Patreon](https://patreon.com/jotego)
* [Paypal](https://paypal.me/topapate)
* [Github](https://github.com/sponsors/jotego)

Project source code hosted at http://www.github.com/jotego/jtcores
License: GPL3, you are obligued to publish your code if you use mine

Yes, you always wanted to have an arcade board at home. First you couldn't get it because your parents somehow did not understand you. Then you grow up and your wife doesn't understand you either. Don't worry, JT cores are here to the rescue.

I hope you will have as much fun with this project as I had while working on it!

# Supported Systems

This FPGA core is compatible with the following arcade PCBs:

- The Simpsons
- Parodius da!
- Vendetta (Crime Fighters 2)

# Game Configuration

This game does not use DIP switches but a small EEPROM to save the configuration. Access to the configuration by pressing F2 on your keyboard or pressing button 1 and coin in the Analogue Pocket. Follow the game menu to alter the configuration from that point on.

# PLD Equations

Derived from Caius original [files](https://wiki.pldarchive.co.uk/index.php?title=The_Simpsons).


**053994** at 11C:

```
/i7 = /AS & /INIT & /A15 & /A14 & /A13 & A12 & A11 & A10 & /W0C1 & W0C0 +
      /AS & /INIT & /A15 & /A14 & /A13 & A12 & A11 & A10 &  W0C1 +
      /AS &         /A15 & /A14 & /A13 & A12 & A11 & A10 &        /W0C0 +
      /AS &  INIT & /A15 & /A14 &  A13 &                   /W0C1 +
      /AS &  INIT & /A15 & /A14 & /A13 &                          /W0C0 +
      /AS &  INIT & /A15 & /A14 & /A13 & A12

# 1C00~1FFFF and if /INIT 7C00~7FFF
/i6     = /AS & /INIT & /A15 &  A14 &  A13 & A12 & A11 & A10 +
          /AS &         /A15 & /A14 & /A13 & A12 & A11 & A10   =>
        =>/AS & ( A[15:10]==7 || (A[15:10]=='h1F && /INIT))

/WORKCS = /AS & INIT & /A15 & A14 & /A13

/OBJCS = /AS & INIT & /A15 & /A14 & A13 & W0C1

/COLOCS = /AS & INIT & /A15 & /A14 & /A13 & /A12 & W0C0

/PROGCS = /AS & INIT & A14 & A13 & BK4 +
       /AS & A15

/BNKCS = /AS & INIT & /A15 & A14 & A13 & /BK4
```

**053995** at 11D:

```
/EEPROM = /AS & //i6 & //i7 & A9 & A8 & A7 & /A6 & /A5 & /A4
/JOYSTK = /AS & //i6 & //i7 & A9 & A8 & A7 & /A6 & /A5 &  A4
/OBJREG = /AS & //i6 & //i7 & A9 & A8 & A7 & /A6 &  A5 & /A4 # A[9:4]==111010
/PCUCS  = /AS & //i6 & //i7 & A9 & A8 & A7 & /A6 &  A5 &  A4
/IOCS   = /AS & //i6 & //i7 & A9 & A8 & A7 &  A6 & /A5 & /A4

/VRAMCS = /AS & //i6 &      /A9  +
          /AS & //i6 &      /A8  +
          /AS & //i6 &      /A7  +
          /AS & //i6 &       A6 & A5 +
          /AS & //i6 &       A6 & A4
          /AS & //i6 &  /i7 +
          /AS &  /i6 & //i7 +
```

# K053246

Based on 051960 (previous generation of sprite hardware)
and MAME documentation

256 sprites, 8x 16-bit data per sprite
Sprite table = 256*8*2=4096 = (0x1000)
DMA transfer takes 297.5us, and occurs 1 line after VS finishes
The PCB may detect end of the DMA transfer and set
an interrupt on it

The chip can operate in either 8-bit or 16-bit mode, so it can
connect to an 8-bit CPU (and RAM) or a 16-bit system
Is the 8-bit mode set by an MMR?
DMA A0 line max speed is 3MHz (166ns low, 166ns high)
in 8-bit mode, not all 8 positions have low & high bytes read
if all were read, DMA should last for 682.67us but it is 596.9us
so 14 out of 16 bytes are read for each object
MSB is read first, so the order is
1,0,3,2,5,4,7,6,9,8,B,A,D,C
Note that F,E are missing. Could they be enabled with some MMR?

In X-Men (16-bit mode) DMA lasts for 298.7us, half the time
than in 8-bit mode (595us, accounting for some inaccuracy in the measurement)

This implementation has a first phase that clears out the internal buffer
and then sprites are copied by their priority code into memory, so they
naturally fall in order.
The original one likely has the same clear phase but executed right after
the vs edge and lasting for a whole line.
The DMA timing has been matched with the original, despite of the different
buffer-clear logic

# Credits

Special thanks to [Museo Arcade Vintage](https://museoarcadevintage.com/) for lending their Simpsons PCB to us during development.

Thanks to August 2023 Patreon supporters

```
3style                 8bits4ever             A Murder               Aaron Ray
Aaron S                Adam Leslie            Adrian Labastida       Adrien Pestel
Alan Shurvinton        Alec Peden             Alex Mandic            Alexander Facchini
Alexander Lash         Alexander Upton        Alfonso Clemente       AllDarnDavey
Allen Tipper           Allister Fiend         Alvaro Paniagua        Andrea Chiavazza
Andreas Micklei        Andrew Boudreau        Andrew Hannan          Andrew Schmidt
Angel Aguinaga         Angelfred              Angelo Kanaris         AnotherJoe
Anselmo Moreno         Anthony Archer         Anthony Monaco         Anton Gale
Antwon                 Arend Pronk            Arjan de Lang          Arkadiusz
Armin Hierstetter      Arthur Fung            Aurich Lawson          BRCDEvg
Banane                 Barley Cheezers        Batlab Electronics     Bear S
Ben Cullen             Ben Toman              BigRedPimp             Bit2018
Bitmap Bureau          Bitmaps Retro          Bluezer222             Boris Prüßmann
Brandon Arnold         Brandon Peach          Brandon Thomas         Brandoon
Brent Fraser           Brian Birkinbine       Brian Nagel            Brian Peek
Brian Shiver           Brianna Cluck          Bruce Fontaine         Bruno Meyere
Bruno Silva            Bryan Evans            Byshop303              Cameron Berkenpas
Cameron Tinker         Carlos Gruberman       Chad Page              Charles
Charles Paek           Chris                  Chris Angelini         Chris Babishoff
Chris D                Chris Davis            Chris Hauk             Chris Hoff
Chris Jardine          Chris Maguire          Chris Mzhickteno       Chris Petroni
Chris S                Chris Scully           Chris Tuckwell         Chris W Miller
Chris Waltham          Christophe GARDES      Clinton Cronin         Clinton McCarty
Cobra Clips            Colin Colehour         Collidingforces        Cory Sizemore
Cosmic Savant          Craig Kergald          Craig McLaughlin       Damien D
Dan Anderson           Dan Kelley             Dane Biegert           Daniel .
Daniel Dongil          Daniel Flowers         Daniel Page            Daniel Zee
Daniele Pellegrini     Danny Austin           Danny Garfield         Darren Wootton
Daryl Boothe           Daryll David           Dave Douglas           Dave Nice
David                  David Fleetwood        David Gallène          David Osborne
David Stone            DenizB                 Dennis Ranker          Denny Letourneau
Devon Meunier          Diana2Carolina         Didier Touron          Diego Farrell
Douglas Alves          Dr Catjail             Dr. Octagon            DrMnike
Dre137                 Dward Venegas          EDDY                   Ed
EdgarsDouble           Edward Mallett         Emile Denichaud        Enzo
Epixjava               Eren Kotan             Eric Gutt              Eric J Faulkes
Eric Schneider         Eric Sorensen          Erik                   F Iron
FROELIGER              Fabian L               Fabio Michelin         Fabrice Odero
Fabricio               Fahim Rahman           Federico               Five Year Guy
Frank Brevoort         GarethY                GeorgeSpinner          GigaBoots
Girth305               Glenn                  Glenn Percival         Gord Allott
Gordon Coughlin        Grant McNaught         Gregory Val            Grummkol
Guillermo Tunon        Guy Taylor             HamsoloPlays           Harmonica
Heinz Stampfli         Henry                  Henry R                Hermes Yan
Hugo Pinto             Ian Kester-Haney       ItalianGrandma         ItsBobDudes
JAMES D BOOTH          JSwan                  Jack Follansbee        Jack Sammons
Jacob Hoffman          Jakob Schmid           James Boone            James Dingo
James Ervin            James Miller           James Trautner         James Wilson
Janne Heikkarainen     Jason Baker            Jason Dee              Jason Jacobs
Javier Heredia         Jayson Larose          Jeff Roberts           Jeremie Barnes
Jeremy Hopkins         Jerry Langwell         Jerry Suggs            Jesse Clark
Jesse Rankin           Jesus Garcia           Jim Hendricks          Jim Knowler
JimLahey               Jimmy Ecker            Jimmy Kim              Jimmy Richards
Jms                    Jockel                 Joe Dinges             Joe Giuliano
Joel Albino            John Dawson            John Fletcher          John Hood
John K                 John T. Keen           John Torn              John Wilson
John Woods             Johnny harvick         Jonathan               Joost Peters
Jork Sonkinfield       Jose Perez             Josep Barbie           Joseph Campo
Joseph Kulinski        Joseph Milazzo         Josh Yates-Walker      Juan Barriga
Juan E. Gayon          Juan Pablo             Justin D'Arcangelo     Kai Cherry
Kai Luotojoki          Kaiosten               Keith Gordon           Kellerkind
Ken B                  Ken Scott              Kevin Dayton           Kevin Miller
Kike Alcor             Kimberley Fisher       KnC                    Konrad
Kricys                 Krisztian Lanyi        KrzysFR                Kyle Pedersen
Kyle Peters            Kyo Kim                L.Rapter               Lakeside
Lance Bohy             Lars Vonhof-Hunold     Lee Osborne            LoBai Zen
Luc JOLY               Lucian                 Lucius Bono            Luis F Giron
M Reznor               MaDDoG                 Mack H                 Madox
Magnus Aspling         Magnus Kvevlander      Mane Function          Manfred Müller
Manksalot              Marcello Medini        Mark Floyd             Mark Jeffers
Mark Saunders          MarthSR                Matt Bouverie          Matt Evans
Matt McCarthy          Matt Simonds           Matt Vulcano           Matthew Compston
Matthew Heyman         Matthew Woodford       Matthieu Marchione     Max
Max Power              MechaGG                Mehdi Daouas           MiSTer Retro
Michael Bariszlovits   Michael Eggers         Michael Jahosky        Michael Maple
Michael Petri          Michael Rea            Mickaël Renou          Mike Holzinger
Mike Jegenjan          Mottzilla              Mysterious Benefactor  Nadir Shabazz
Nailbomb               NerdyNester            Nic B.                 Nic Kaiman
Nicholas Bold          Nick Daniels           Nick Delia             Nick Gudauskas
Nico Stamp             Niko                   Nolan                  Noyman29
Obvious Fakename       Odilio FRAGATA         Oliver Heilmann        Omar Najera
Omega16bit             OnkelPipi              Oriez                  Oskar Maria
Oskar Sigvardsson      Oyvind Christiansen    Pablo Avila-Estevez    Patrick Roman
Paul Cunningham        Paul Jr                Paulo M.               Paulo Nascimento
Paweł Mandes           PeFClic                Pedro Santiago         Per Ole
Peter Mehes            Philip Lai             Philip Lawson          Potato
Prime1984              ProfessorAnon          Pumpy Crumpy           Ralph Barbagallo
Ramon Gamaliel         Ramon jimenez          RandomRetro            Raphael Melgar
Raul3D                 Rautz                  RayGun                 Reborn 187
RetroRGB               Rex Kung               Richard Murillo        Richard Simpson
Richard Smith          Rob Mossefin           Robert Hayes           Roberto Bava
Roberto Mercado        Robin Hertzberg        Rog                    Romain Dijoux
Romier Silvera         Ronald Dean            Ronan Amicel           Ronin Yojimbo
RoryDropkick           Rufo Sanchez           Rune P                 Russ Crandall
Ryan                   Ryan Clark             Ryan Kasper            Ryne Weiss
Sam Hall               Samuel Pizarro         Samuel Warner          Sang Hee
Sascha Zupanek         Sayit BELET            Schnookums             Scott Bender
Sean Lake              Sean Quinn             Ser Erris              Shad Uttam
Shannon King           Shen mue               Sherwood Hachtman      Shon Garraway
Sigmund68k             Skeletex               Sonthayaya Siha        Spank Minister
StealthCT              SteelRush              Stefan Krueger         Stephen
Stephen Pagenstecher   Stephen R Price        Steve Lin              Steve Skrzyniarz
Steve Tack             Steven A               Steven Hansen          Stuart Morton
Sunder Raj             Synbios                TAKA Hara              TMoney
Taehyun Kim            Tales Dilli            Terse                  TgrMstr
That's A               The Collector          The Video              Thomas Attanasio
Thomas Popper          Thomas Ruf             Thorias                Timothy Bearup
Timothy Latunde        Tobias Dossin          Tom Milner             Tony Shong
Topher Campbell        Transientfire          Trifle                 Two Bards
Ty B                   Tyson Hanes            Unlovedhomie           VERHILLE Arnaud
VickiViperZabel        Victor Fontanez        Victor Yoon            Vincent Lietart
Wesley Lyons           Will Abbott            William Clemens        William Roussin
XC-3730C               Xaxius                 Yunus Soğukkanlı       Zack Fawley
Zoltan Kovacs          aguijon                alejandro carlos       amdrgn
angel_killah           arcadebros             blackwine              brian burney
charlysan              chauviere benjamin     dARKrEIGn              dECKARD (Daniel
datajerk               derFunkenstein         elsee2                 eltee
fbmg                   ill_deez               joe figueroa           jonathan capparelli
kccheng                kernelchagi            kerobaros              keropi
liphy                  mattyhochs             metal                  moalthan
myusernamewastaken     ogge_leander           ojwales                ordigdug
raoulvp                respergu               retroboi               robert rodgers
rsn8887                slayer213              sourdille              spaceduck
tim rogers             troy coberly           turbochop3300          twilitezoner
type78                 vampsthevampyre        yoaarond               Δlain
```