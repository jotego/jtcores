# Aliens Compatible FPGA core by Jotego

# Technical Details

The PALs were dumped by Caius and are published [here](https://wiki.pldarchive.co.uk/index.php?title=Aliens). They can be found in the _doc_ folder and follow the GAL16V8 format.

The video chips were reversed engineering by Furrtek and published [here](https://github.com/furrtek/VGChips/tree/master/Konami)

## Video

- Pixel clock 12MHz
- Frame period 16.895ms => 59.18 Hz
- Tile map bandwidth = 384x4x3/64us = 72 Mbit/s
- Tile map 2.25 Mreq/s (SDRAM requests) = 144 req/line
- Hcnt from 20 to 19F. 20-60 = HB (64 pixels). 40-5A = HS
- Vcnt from F8 to 1FF. 1F0 -> F8 -> 110 = VB. F8-100 = VS

## RAM Usage

Item        | RAM size (kB)
------------|-----------
KCPU        |  8
Z80         |  2
Tile mapper | 16
OBJ         |  2
Total       | 28

The 051960 has an embedded double line buffer

## PAL Equations

### Super Contra

From H15, 052125
```
/ROMEN = /NAS & NINITSET & /A15 & A14
  + /NAS & /A15 & /A13
  + /NAS & /A15 & /A14;
/ROM1CS =/NAS & A15
  + /NAS & /NINITSET & A14 & A13 & /BK3;
/ROM2CS = /NAS & /NINITSET & /A15 &  A14 &  A13 &  BK3;
/CHAIN = NRMRD & /A15 & /A14 &  A13 & A12;
/INCS =  NINITSET & /A15 &  A14 &  A13;
/IOOUT = /A15 & /A14 & /A13;
/WORKCS =/NAS & /A15 & A14 & /A13 & /A12 & A11
  + /NAS & /A15 & A14 & /A13 & WORK_COL
  + /NAS & /A15 & A14 & /A13 & /A11;
/COLORSEL = /NAS & /A15 &  A14 & /A13 &  A12 &  A11 & /WORK_COL;
/COLORCS  = /NAS & /A15 &  A14 & /A13 &  A12 &  A11 & /WORK_COL;
 SYCS = NINITSET & /A15 & A14 & A13 & NIOCS
  + /A15 & /A14 & NIOCS;
```

From H13, 052124

```
NVRAMEN= o18 = !(
      NAS + INCS & (
              (A15+A14) +
              /CHAIN & A11 & ( A10 +
                              (/A9 & /A8 & /A7 & /A6 & /A5 & /A4 & /A3)) +
              A12 & A11 & A10 & A9 & A8 & A7 & /IOOUT
      ))

NOBJEN=/o19 = /NAS & /CHAIN & A11 & A10 +
       /NAS & /CHAIN & A11 & /A9 & /A8 & /A7 & /A6 & /A5 & /A4 & /A3
NIOCS= A12 & A11 & A10 & A9 & A8 & A7 & /IOOUT

```


### Aliens

From D21

```
/WORK = /AS & /A15 & /A14 & /A13 & /A12 & /A11 & A10 +
        /AS & /A15 & /A14 & /A13 & /A12 & A11 +
        /AS & /A15 & /A14 & /A13 &  A12 +
        /AS & /A15 & /A14 & /A13 & /A12 & /A11 & /A10 & /W0C0

/BANK = /AS & /BK4 & /A15 & /A14 & A13 = /BK4 & A[15:14]==001

/x = /o15 = /AS & /A15 & A14 & /A13 & A12 & A11 & A10

/z = /o16 = INIT & /A15 & A14 & A13 & A12 & A11

/y = /o12 = /A15 & /A14 & /A13 & /A12 & /A11 & /A10 & W0C0

/p = /o17 = /AS & /A15 & A14 +
       /AS & /A15 & /A14 & /A13 & /A12 & /A11 & /A10 & W0C0

/PROG = /AS & A15 +
       /AS & BK4 & /A15 & /A14 & A13

/o19 = /AS & A15 +
       /AS & BK4 & /A15 & /A14 & A13 +
       /AS & /A15 & /A14 & /A13 & /A12 & /A11 & A10 +
       /AS & /A15 & /A14 & /A13 & /A12 & A11 +
       /AS & /A15 & /A14 & /A13 & A12 +
       /AS & /A15 & /A14 & /A13 & /A12 & /A11 & /A10 & /W0C0 +
       /AS & /BK4 & /A15 & /A14 & A13
```

- /p' is /p sampled at CLKQ, reset when /AS goes high.

From D20

```
/DTAC' = /p' & /RMRD & /A10 & /A9 & /A8 & /A7 & /(A6+A5) & /(A4+A3) & /z +
       /p' & /RMRD & A10 & /z +
       /p' & /p & IOCS & aux

/IOCS = A9 & A8 & A7 & /(A6+A5) & /x

/aux = /p' & /RMRD & /z & /A10 & /A9 & /A8 & /A7 & /(A6+A5) & /(A4+A3) +
       /p' & /RMRD & /z &  A10

/CRAMCS = /p' & /y

/VRAMCS = /p' & /p & y & IOCS & aux

/OBJCS = /p' & /RMRD & /z & /A10 & /A9 & /A8 & /A7 & /(A6+A5) & /(A4+A3)  +
         /p' & /RMRD & /z &  A10

```

### Crime Fighters

From Caius equivalent equations [here](https://wiki.pldarchive.co.uk/index.php?title=Crime_Fighters).

From E19
```
/o12 = A[15:10]==0 & W0C0

/WORK = (/AS && A[15:13]==0) && (A[12:10]!=0 || /W0C0)
/BANK = /AS & ( A15 || (INIT && A[14:13]==2'b11) )

/o15 = /AS && INIT && A[15:10]==6'b001111

/o16 = INIT && A[15:11]==5'b01011

/o17 = /AS & /A15 & ( A14 & /INIT |
                     /A14 &  A13  |
                      A14 & /A13  |
                     /A14 & /A12 & /A11 & /A10 & W0C0 )

// o19 only used for DTAC generation
/o19 = /AS & ( A15 |
       INIT & A14 &  A13 |
             /A14 & /A13 & A12 |
             /A14 & /A13 & A11 |
             /A14 & /A13 & A10 |
             /A14 & /A13 & /W0C0 )
```

From E18
```
// o12 only used for DTAC generation
/o12 = /E19_o17l & /RMRD & A10 & /E19_o16 |
       /E19_o17l & /RMRD & /A9 & /A8 & /A7 & /(A6|A5) & /(A4|A3) & /E19_o16 |
       /E19_o17l & /E19_o17 & /A9 |
       /E19_o17l & /E19_o17 & /A8 |
       /E19_o17l & /E19_o17 & /A7 |
       /E19_o17l & /E19_o17 & (A6|A5) |
       /E19_o17l & /E19_o17 & E19_o15

/IOCS = A9 & A8 & A7 & /(A6|A5) & /E19_o15

// unconnected
/o15 = /E19_o17l & /RMRD & A10 & /E19_o16 |
       /E19_o17l & /RMRD & /A9 & /A8 & /A7 & /(A6|A5) & /(A4|A3) & /E19_o16

/CRAMCS = /E19_o17l & /E19_o12

// must invert later:
VRAMCS = E19_o17l |
      /RMRD & A10 & /E19_o16 |
      /RMRD & /A9 & /A8 & /A7 & /(A6|A5) & /(A4|A3) & /E19_o16 |
      E19_o17 |
      /E19_o12 |
      A9 & A8 & A7 & /(A6|A5) & /E19_o15

/OBJCS = /E19_o17l & /RMRD & A10 & /E19_o16 |
         /E19_o17l & /RMRD & /A9 & /A8 & /A7 & /(A6|A5) & /(A4|A3) & /E19_o16
```

### Gang Busters / Thunder Force

The equations are not available

# Game Library

The following games used the 052001 CPU as the main processor and have a very similar board design. The main differences are related to memory decoding and GFX chip connectivity. JTALIENS is planned to support the following titles

Games                          | Konami Code    | CPU           | Schematics
-------------------------------|----------------|---------------|------------
Aliens                         | GX875          | 052256        |  Yes
Super Contra                   | GX775          | 052001        |  Yes
Thunder Cross                  | GX873          | 052526/052001 |  Yes
Gang Busters / Crazy Cop       | GX878          | 052526        |  Yes (same as GX873)

# Support

The *jotego* nickname had already been used by other people so on some networks
you will find me as *topapate*.

Contact via:
* https://twitter.com/topapate
* https://github.com/jotego

You can show your appreciation through
* Patreon: https://patreon.com/jotego
* Paypal: https://paypal.me/topapate

# Thanks to May 2023 Patrons
```
3style                 8bits4ever             A Hernandez            A Murder
Aaron Ray              Aaron S                Adam Foster            Adam Leslie
Adam Small             Adrian Labastida       Adrien Pestel          Alan Shurvinton
Alda Alesio            Alec Peden             Alex Baldwin           Alex Mandic
Alexander Facchini     Alexander Lash         Alexander Upton        Alfonso Clemente
AllDarnDavey           Allen Tipper           Allister Fiend         Alvaro Paniagua
Andrea Chiavazza       Andreas Micklei        Andrew Boudreau        Andrew Hannan
Andrew Kaczrowski      Andrew Schmidt         Angel Aguinaga         Angelo Kanaris
AnotherJoe             Anselmo Moreno         Anthony Monaco         Anton Gale
Antwon                 Arend Pronk            Arjan de Lang          Arkadiusz
Armin Hierstetter      Arnulf Eide            Arthur Fung            Aurich Lawson
BRCDEvg                Banane                 Barley Cheezers        Bear S
Ben Cullen             Ben Tiefert            Ben Toman              BigRedPimp
Bit2018                Bitmap Bureau          Bitmaps Retro          Bliz 452
Bluezer222             Boris Pruessmann       Brad Higginbotham      Brandon Lennie
Brandon Peach          Brandon Thomas         Brandoon               Brent Fraser
Brian Birkinbine       Brian Peek             Brian Shiver           Brianna Cluck
Bruce Fontaine         Bruno Meyere           Bruno Silva            Bryan Evans
Byshop303              Cameron Berkenpas      Cameron Tinker         Carlos Bailleres
Carlos Gruberman       Cesar Sandoval         Chad Page              Charles
Charles Paek           Chris                  Chris Angelini         Chris Babishoff
Chris Brentano         Chris D                Chris Davis            Chris Hauk
Chris Hoff             Chris Maguire          Chris Mzhickteno       Chris Petroni
Chris S                Chris Scully           Chris Tuckwell         Chris W Miller
Chris Waltham          Chris smith            Christophe GARDES      Chuong Dang
Clayton Anderson       Clinton Cronin         Clinton McCarty        Cobra Clips
Colin Colehour         Collidingforces        Cory Sizemore          Cosmic Savant
Craig McLaughlin       Damien D               Dan Kelley             Dane Biegert
Daniel                 Daniel .               Daniel Dongil          Daniel Flowers
Daniel Fowler          Daniel Page            Daniel Zee             Daniele Pellegrini
Danny Austin           Danny Garfield         Darren Wootton         Daryll David
Dave Douglas           Dave Nice              David                  David Fleetwood
David Frost            David Gallène          David Osborne          David Stone
Denis Brækhus          Dennis Ranker          Denny Letourneau       Devon Meunier
Diana2Carolina         Didier Touron          Diego Farrell          Dimitris Zongas
Douglas Alves          Dr Catjail             Dr. Octagon            DrMnike
Dubesinhower           Dward Venegas          EDDY                   Ed
EdgarsDouble           Edward Mallett         Emile Denichaud        Enzo
Epixjava               Eren Kotan             Eric                   Eric Gutt
Eric J Faulkes         Eric Schneider         Eric Sorensen          Erik
F Iron                 F34R                   FROELIGER              Fabian L
Fabio Michelin         Fabrice Odero          Fabricio               Fahim Rahman
Federico               Five Year Guy          Florian Raoult         Frank Brevoort
Frank Schwab           GarethY                GeorgeSpinner          GigaBoots
Girth305               Glenn Percival         Gord Allott            Gordon Coughlin
Grant McNaught         Gregory Val            Grummkol               Grzegorz {NineX}
Guillermo Tunon        Guy Taylor             HamsoloPlays           Harmonica
Heinz Stampfli         Henry                  Henry R                Hermes Yan
Hugo Pinto             Ian Kester-Haney       ItalianGrandma         ItsBobDudes
Ivan Vodopiviz         JAMES D BOOTH          JSwan                  Jack Follansbee
Jack Sammons           Jacob Hoffman          Jakob Schmid           James Boone
James Dingo            James Ervin            James Miller           James Trautner
James Wilson           Janne Heikkarainen     Jason Baker            Jason Dee
Jason Jacobs           Javier Heredia         Jayson Larose          Jeff Roberts
Jeremie Barnes         Jeremy Hopkins         Jerry Langwell         Jerry Suggs
Jesse Clark            Jesse Rankin           Jesus Garcia           Jim Hendricks
Jim Knowler            JimLahey               Jimmy Ecker            Jimmy Kim
Jimmy Richards         Jms                    Jockel                 Joe Dinges
Joe Giuliano           Joel Albino            John Dawson            John Fletcher
John Hood              John K                 John T. Keen           John Torn
John Wilson            John Woods             Johnny harvick         Jonathan
Joost Peters           Jork Sonkinfield       Jose Gabriel           Jose Perez
Josep Barbie           Joseph Campo           Joseph Kulinski        Joseph Milazzo
Joseph Mogavero        Josh Yates-Walker      Juan Barriga           Juan E. Gayon
Juan Pablo             Julien Perrot          Justin D'Arcangelo     Kai Cherry
Kai Luotojoki          Kaiosten               Kaya Bear              Keith Gordon
Kellerkind             Ken B                  Ken Scott              Kevin Dayton
Kevin Miller           Kike Alcor             Kimberley Fisher       KnC
Konrad                 Kricys                 Krisztian Lanyi        KrzysFR
Kyle Pedersen          Kyle Peters            Kyo Kim                L.Rapter
Lakeside               Lance Bohy             Lars Vonhof-Hunold     Lee Osborne
LoBai Zen              Luc JOLY               Lucian                 Lucius Bono
Lucky                  Luis F Giron           Luke Rowe              M Reznor
MaDDoG                 Mack H                 Madox                  Magnus Aspling
Magnus Kvevlander      Mane Function          Manfred Müller         Manksalot
Marcello Medini        Mark Floyd             Mark Jeffers           Mark Saunders
MarthSR                Matt Bouverie          Matt Evans             Matt McCarthy
Matt Simonds           Matt Vulcano           Matthew Compston       Matthew Heyman
Matthew Woodford       Matthieu Marchione     Max                    Max Power
MechaGG                Mehdi Daouas           MiSTer Retro           Michael Anderson
Michael Bariszlovits   Michael Eggers         Michael Maple          Michael Petri
Michael Rea            Mickaël Renou          Mike Holzinger         Mike Jegenjan
Mottzilla              Murray Sneddon         Mysterious Benefactor  Nadir Shabazz
Nailbomb               NerdyNester            Nic B.                 Nic Kaiman
Nicholas Bold          Nick Daniels           Nick Delia             Nick Gudauskas
Nico Stamp             Niko                   Nolan                  NonstopXiaowei
Noyman29               Obvious Fakename       Odilio FRAGATA         Oliver Heilmann
Omar Najera            Omega16bit             OopsAllBerrys          Oriez
Oskar Maria            Oskar Sigvardsson      Oyvind Christiansen    Pablo Avila-Estevez
Patrick Roman          Paul Cunningham        Paul Jr                Paulo M.
Paulo Nascimento       Paweł Mandes           PeFClic                Pedro Santiago
Per Ole                Peter Mehes            Philip Lai             Philip Lawson
Potato                 Prime1984              ProfessorAnon          Pumpy Crumpy
R Omar Leal            Ralph Barbagallo       Ramon Gamaliel         Ramon jimenez
RandomRetro            Raphael Melgar         Raul3D                 Rautz
RayGun                 Reborn 187             RetroRGB               Rex Kung
Richard Murillo        Richard Simpson        Richard Smith          Rob Mossefin
Robert Hayes           Robin Hertzberg        Romain Dijoux          Romier Silvera
Ronald Dean            Ronan Amicel           Ronin Yojimbo          RoryDropkick
Rufo Sanchez           Rune P                 Russ Crandall          Ryan
Ryan Clark             Ryan Kasper            Ryne Weiss             Saiyan
Sam Hall               Samuel Pizarro         Samuel Warner          Sang Hee
Sascha Zupanek         Sayit BELET            Schnookums             Scott Bender
Sean Lake              Sean Quinn             Ser Erris              Shad Uttam
Shannon King           Shen mue               Sherwood Hachtman      Shon Garraway
Sigmund68k             Skeletex               Sonthayaya Siha        Spank Minister
Stadium ARTs           SteelRush              Stefan Krueger         Stephen
Stephen Pagenstecher   Stephen R Price        Steve Lin              Steve Skrzyniarz
Steve Tack             Steven A               Steven Hansen          Stoneman
Stuart Morton          Sunder Raj             Synbios                TAKA Hara
TMoney                 Taehyun Kim            Tales Dilli            Terse
TgrMstr                The Collector          The Video              Thomas Attanasio
Thomas Popper          Thomas Ruf             Thorias                Timothy Bearup
Timothy Latunde        Tobias Dossin          Tom Milner             Tony Shong
Topher Campbell        Travis Kennington      Trifle                 Two Bards
Ty B                   Tyson Hanes            VERHILLE Arnaud        VickiViperZabel
Victor Fontanez        Victor Yoon            Vincent Lietart        Wesley Lyons
Will Abbott            William Clemens        William Roussin        XC-3730C
Xaxius                 Yunus Soğukkanlı       Zack Fawley            Zoltan Kovacs
aguijon                alejandro carlos       alexcom                amdrgn
angel_killah           arcadebros             blackwine              brian burney
chauviere benjamin     dARKrEIGn              dECKARD (Daniel        datajerk
derFunkenstein         eclipse                eltee                  fbmg
ill_deez               jim br                 jonathan capparelli    kadybat
kccheng                kernelchagi            kerobaros              keropi
liphy                  mattyhochs             metal                  moalthan
myusernamewastaken     ogge_leander           ohmy                   ojwales
raoulvp                respergu               retroboi               robert rodgers
rsn8887                slayer213              sourdille              spaceduck
starman_jr             thomas winfrey         tim rogers             troy coberly
turbochop3300          twilitezoner           type78                 vampsthevampyre
yoaarond
```
