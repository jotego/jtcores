# NeoGeo Pocket Compatible FPGA core by Jotego

Please support the project
* Patreon: https://patreon.com/jotego
* Paypal: https://paypal.me/topapate

# System Details

| unit    | memory (kB) | remarks        |
|:--------|:------------|:---------------|
| T800H   | 12+4        | upper 4 shared |
| Z80     |  4          | shared         |
| Fix     |  8          |                |
| Scroll  |  4          | 2kB per layer  |
| Objects |   .25       |                |
| Total   | 32          |                |

- Is the video chip connection to the data bus 16 or 8 bits?
- Palette RAM is 16-bit access only and has no wait states

Because of the awkward video timing, the system needs some sort of buffer to output analog video. It is not clear whether it can be done with the amount of BRAM available in MiST/SiDi. That's why the core only targets MiSTer and Pocket right now.

# Key Mapping

- A, B buttons are mapped to the first two buttons in the gamepad
- Start button is mapped to _1P_ (keyboard key `1` or gamepad _select_)
- Power button is mapped to _coin_ (keyboard key `5` or gamepad _start_)

# Cartridge Loading

The first time you insert batteries into a NGP, the system will boot and present a menu. You can go through the set-up process or not. What matters is that when you press the power button in the actual machine, it will suspend the system but keep the memory alive. When you press the power button again, if there is a cartridge, it will not show the setup menu. The core needs the user to replicate this procedure in order to play games.

1. Load the core
2. Use the virtual power button to _turn off_ the NGP
3. Load the cartridge through the OSD menu

If you want to load a new game while the core is working, go directly to step 2.

# Simulation & Debugging

In order to simulate with a cartridge, this has to be named `cart.bin`. The firmware should be called `rom.bin`. Check out [JTFRAME documentation](../../modules/jtframe/doc/sdram.md)

The system can reset from two locations:

- FF1DE8 		reset vector interrupt
- FF1800		power-button interrupt

See more simulation setup notes [here](ver/game/README.md).

## MiSTer

MiSTer scaler automatically handles the awkward video format. This means that the core will only work via HDMI. MiSTer's analog output may work if it is configured to output the scaler video. Compiling the sound CPU is most likely needed for the system to work correctly. All this means that you need to run full compilations for all tests: `jtcore ngp -mr`

The analog video output will not work without a frame buffer because the line period is 83.82us, very far from the typical 64us required. If the system was ignorant of the video output, it would be possible to output at a different rate but the CPU has access to the video circuitry internals and knows at which point of the line the graphics hardware is working. Therefore, only HDMI output is supported.

## MAME

Supply the cartridge name with `-cart`. It is possible to boot with no cartridge too.

`mame ngp -cart cartridge.ngp`

F1 serves as the power button. You probably need to press F1 if the emulator shows a blank screen on start up.

MAME may save the main CPU RAM (12kB) to `~/.mame/nvram/ngp`. Then it will boot from it the next time MAME is run. When it boots from NVRAM, it starts at a different PC address (PC=FF1800). This skips the configuration screen and tries to emulate the standby mode of the original hardware.

You may have NVRAM savings enabled by default, which can make the boot process confusing. Disable it in the `~/.mame/mame.ini` by setting `nvram_save 0`. If you want to save the NVRAM at some point, call MAME with `-nvram_save` and press F1 to power off the device. Then quit MAME and a valid NVRAM should have been generated at `~/.mame/nvram`.

# Cartridge

Manufacturer ID 0x98

Size (kB) | Device ID | Chip count
----------|-----------|-----------
32~512    |   0xAB    |    1
1024      |   0x2C    |    1
2048      |   0x2F    |    1
4096      |   0x2F    |    2

## NGP Compatible Games

According to MAME:

**Purely monochrome**
| Short name | full name                                                                |
|:-----------|:-------------------------------------------------------------------------|
| kofr1      | Pocket Fighting Series - King of Fighters R-1 (Euro, Jpn)                |
| kof_mlon   | King of Fighters R-1 & Melon-chan no Seichou Nikki (Jpn, Prototype)      |
| samsho     | Pocket Fighting Series - Samurai Spirit! (Jpn) ~ Samurai Shodown! (Euro) |
| shougi     | Shougi no Tatsujin (Jpn)                                                 |
| neocup98   | Pocket Sports Series - Neo Geo Cup '98 (Euro, Jpn)                       |
| neocher    | Pocket Casino Series - Neo Cherry Master (Euro, Jpn)                     |
| melonchn   | Melon-chan no Seichou Nikki (Jpn)                                        |
| tsunapn    | Renketsu Puzzle Tsunagete Pon! (Jpn)                                     |
| bstars     | Pocket Sports Series - Baseball Stars (Euro, Jpn)                        |
| ptennis    | Pocket Sports Series - Pocket Tennis (Euro, Jpn)                         |

**Compatible color games**

| Short name | full name                                                   |
|:-----------|:------------------------------------------------------------|
| snkgalsj   | SNK Gals' Fighters (Jpn)                                    |
| kofr2      | Pocket Fighting Series - King of Fighters R-2 (World)       |
| rockmanb   | Rockman - Battle & Fighters (Jpn)                           |
| bigbang    | Big Bang Pro Wrestling (Jpn)                                |
| divealrmj  | Dive Alert - Barn Hen (Jpn)                                 |
| memories   | Memories Off - Pure (Jpn)                                   |
| rockmanbd  | Rockman - Battle & Fighters (Jpn, Demo)                     |
| samsho2    | Pocket Fighting Series - Samurai Shodown! 2 (World)         |
| svccardp   | SNK vs. Capcom - Gekitotsu Card Fighters (Jpn, Demo)        |
| kofpara    | The King of Fighters - Battle de Paradise (Jpn)             |
| dynaslug   | Dynamite Slugger (Euro, Jpn)                                |
| pachinko   | Pachinko Hisshou Guide - Pocket Parlor (Jpn)                |
| kofr2d     | Pocket Fighting Series - King of Fighters R-2 (World, Demo) |
| magdropj   | Magical Drop Pocket (Jpn)                                   |
| cotton     | Fantastic Night Dreams Cotton (Euro)                        |
| infinity   | Infinity Cure (Jpn)                                         |

# Contact

* https://twitter.com/topapate
* https://twitter.com/jotegojp
* https://github.com/jotego/jtcores/issues

# Thanks to December 2023 Patrons
```
3style                 4Slippy                8bits4ever             A Hernandez
A Murder               Aaron Ray              Adam Leslie            Adam Small
Adrian Labastida       Alan Kebab             Alan McGrath           Alan Michael
Alan Shurvinton        Alberto                Alejandro Escobedo     Alejandro Fajardo
Alex Baldwin           Alex Mandic            Alex Smith             Alexander Facchini
Alexander Lash         Alexander Upton        Alfonso Clemente       AllDarnDavey
Allen Tipper           Allister Fiend         Alvaro Paniagua        Andrea Chiavazza
Andreas Micklei        Andrew Boudreau        Andrew Hannan          Andrew Schmidt
Andrew Zah             Angelfred              Angelo Kanaris         AnotherJoe
Anselmo Moreno         Anthony Archer         Anthony Monaco         Anton Gale
Arend Pronk            Ariel Mendoza          Arjan de Lang          Armin Hierstetter
Arthur Fung            Aurich Lawson          B A                    BRCDEvg
Banane                 Barley Cheezers        Basti                  Batlab Electronics
Bear S                 Ben Cullen             Ben Toman              BigRedPimp
Birrdman               Bit2018                Bitmap Bureau          Bitmaps Retro
Blayke                 Bliz 452               Bluezer222             Boris Prüßmann
Borja Burgos           Brandon Arnold         Brandon Peach          Brandon Thomas
Brandoon               Brent Fraser           Brian Birkinbine       Brian Horne
Brian Peek             Brian Shiver           Brianna Cluck          Bruce Fontaine
Bruno Meyere           Bruno Silva            Bryan Evans            Byshop303
CF                     Cameron Berkenpas      Cameron Tinker         Carlos Gruberman
Chad Page              Charles Dreiss         Charles Paek           Chris
Chris Angelini         Chris Babishoff        Chris C                Chris Chappell
Chris D                Chris Hauk             Chris Hoff             Chris Jardine
Chris Maguire          Chris Mzhickteno       Chris Petroni          Chris Ryan
Chris S                Chris Scully           Chris Tuckwell         Chris W Miller
Chris Waltham          Christophe GARDES      Claudio Fortuna        Clayton Anderson
Clinton Cronin         Clinton McCarty        Cobra Clips            Cody Gray
Colin Colehour         Collidingforces        Cosmic Savant          Craig Kergald
Craig McLaughlin       D S                    Dallas Grant           Damien D
Dan Anderson           Dan Kelley             Daniel Dongil          Daniel Flowers
Daniel Page            Daniel Zee             Daniele Pellegrini     Danny Austin
Danny Garfield         Darren Wootton         Daryll David           DasGutt
Dave Bennett           Dave Douglas           Dave Nice              David Drury
David Fleetwood        David Gallène          David Guida            David Osborne
David Stone            DenizB                 Dennis Ranker          Denny Letourneau
Devon Meunier          Devon Shaw             Diana2Carolina         Didier Touron
Diego                  Douglas Alves          Dr Catjail             DrMnike
Dre137                 DrewtoriousFGC         E M                    Ed
EdgarsDouble           Edward Cartier         Edward Kim             Edward Mallett
Edward Williams        Emile Denichaud        Enzo                   Eren Kotan
Eric J Faulkes         Eric Schneider         Eric Sorensen          Erik
Ethan Foley            F34R                   FROELIGER              Fabian L
Fabio Michelin         Fabrice Odero          Fabricio               Fahim Rahman
Federico               Fergal Byrne           Five Year Guy          Frank Brevoort
Gabe Larios            GarethY                Gaussian Llama         Gene Starwind
GeorgeSpinner          GigaBoots              Girth305               Glenn
Glenn Percival         Gord Allott            Gordon Coughlin        Gregory Val
Gregory VanNostrand    Grummkol               Guillermo Tunon        H G
HamsoloPlays           Harmonica              HawkManHawk            Heinz Stampfli
HendrixTrog            Henry                  Henry R                Hermes Yan
Hugo Pinto             Ian Guebert            Ian Kester-Haney       Ian King
Isles487               Isra T.G.              Issiah                 ItalianGrandma
ItsBobDudes            JBrent                 JPanic666              JSwan
Jack Follansbee        Jacob Hoffman          Jakob Schmid           James Bamford
James Boone            James Butler           James Dingo            James Ervin
James Mayes            James Miller           James Trautner         James Wilson
Janne Heikkarainen     Jared M                Jason Baker            Jason Dee
Jason Jacobs           Jason Moskowitz        Jason Robinson         Javier Heredia
Jayson Larose          Jeff Roberts           Jeremie Barnes         Jerry Langwell
Jerry Suggs            Jesse Clark            Jesse Rankin           Jesus Garcia
Jim Hendricks          Jim Knowler            JimLahey               Jimmy Dozier
Jimmy Ecker            Jimmy Kim              Jimmy Richards         Jms
Jochen Koerner         Jockel                 Joe Dinges             Joe Giuliano
Joe Naberhaus          Joel Albino            Johan Smolinski        John Dawson
John Fletcher          John Hood              John K                 John Paul Luna
John T. Keen           John Torn              John Wilson            John Woods
Johnny harvick         Jonathan               Joost Peters           Jork Sonkinfield
Jose Antonio           Jose Perez             Josep Barbie           Joseph Kulinski
Joseph Milazzo         Josh Davis             Josh Yates-Walker      Joshua Kubeczka
Joshua Wordlaw         Juan Barriga           Juan E. Gayon          Jukka Hast
Justin D'Arcangelo     Justin Wynn            Kael Spencer           Kai Cherry
Keith Gordon           Kellerkind             Ken B                  Ken Scott
Kevin Brown            Kevin Dayton           Kevin Miller           Kike Alcor
Kimberley Fisher       KnC                    Konrad                 Kricys
Krisztian Lanyi        KrzysFR                Kyle Peters            L.Rapter
LL                     Lakeside               Lance Bohy             Lance Linimon
Lars Peter             Lee G                  Lee Huggett            Lee Osborne
LoBai Zen              Lost Retro             Luc JOLY               Lucian
Lucius Bono            Luis F Giron           M Reznor               MaDDoG
Mack H                 Madox                  Magnus Aspling         Magnus Kvevlander
Mane Function          Manfred Müller         Manksalot              Marcello Medini
Marco Feder            Mark Floyd             Mark Jeffers           Mark Saunders
MarthSR                Matt Bouverie          Matt Evans             Matt Howard
Matt McCarthy          Matt Postema           Matt Simonds           Matt Vulcano
Matthew Heyman         Matthew Schrader       Matthew Woodford       Max
MechaGG                Mehdi Daouas           Meloyelo51             MiSTer Retro
Michael Bariszlovits   Michael Eggers         Michael Jones          Michael Maple
Michael Petri          Michael Rea            Michael V.             Mickaël Renou
Miguel Mendez          Mike Baldwin           Mike Holzinger         Mike Jegenjan
Mottzilla              Mysterious Benefactor  Nadir Shabazz          Nailbomb
Nando Iron             NeTaXe                 Nic B.                 Nicholas Bold
Nick Daniels           Nick Delia             Nick Gudauskas         Nico Stamp
Night Thief            Niko                   Nolan                  NonstopXiaowei
Notaturnip             Noyman29               Odilio FRAGATA         Olivier Latignies
Omar Najera            Omega16bit             Oriez                  Oskar Maria
Oyvind Christiansen    Pablo Avila-Estevez    Packetfetcher          Patrick Roman
Paul Cunningham        Paul PIROTTE           Paulo M.               Paulo Nascimento
PeFClic                Pedro Delao            Pedro Santiago         Per Ole
Peter Coleman          Peter Mehes            Peter Olsen            Philip Lai
Philip Lawson          Potato                 Pretendo               Prime1984
ProfessorAnon          Pumpy Crumpy           R Omar Leal            Rainier Taufik
Ralph Barbagallo       Ramon                  Ramon Gamaliel         Ramon jimenez
RandomRetro            Raphael Melgar         Raul3D                 Rautz
Reborn 187             Retro Ralph            RetroRGB               Rex Kung
Ricardo Ramirez        Richard Murillo        Richard Simpson        Rob Mossefin
Robert Hayes           Roberto Garcia         Roberto Mercado        Robin Hertzberg
RoboyZHunter           Rodney Larsen          Rog                    Roger Ong
Romain Dijoux          Romier Silvera         Ronald Dean            Ronan Amicel
RoryDropkick           Rufo Sanchez           Rune P                 Russ Crandall
Ryan                   Ryan Clark             Ryne Weiss             Sam Hall
Samuel Pizarro         Samuel Schwager        Sang Hee               Sascha Zupanek
Schnookums             Scott Bender           Sean Lake              Sean Quinn
Ser Erris              Seth Callaway          Shad Uttam             Shannon King
Sherwood Hachtman      Shon Garraway          Sigmund68k             Simon Dukes
Skeletex               Sonthayaya Siha        Spank Minister         StealthCT
SteelRush              Stefan Krueger         Step 3                 Stephan Allen
Stephen                Stephen Pagenstecher   Stephen R Price        Steve Lin
Steve Skrzyniarz       Steven Hansen          Steven Keller          Stuart Morton
Supaslicer             Synbios                TAKA Hara              TMoney
Terse                  TgrMstr                That's A               The Collector
The Video              TheGodsGuitar          TheVoiceOver           Thomas Attanasio
Thomas Popper          Thomas Ruf             Thorias                Timothy Bearup
Timothy Latunde        Tobias Dossin          Tom Milner             Tony Shong
Topher Campbell        Trifle                 Twipp                  Two Bards
Ty                     Tyler Shumpert         Tyson Hanes            Unlovedhomie
VERHILLE Arnaud        VickiViperZabel        Victor Fontanez        Victor Yoon
Vincent Lietart        Visa-Valtteri Pimiä    Wayne Lymbery          Wesley Lyons
William C.             William Clemens        William Roussin        XC-3730C
Xaxius                 Yunus Soğukkanlı       Zack Fawley            Zoltan Kovacs
aguijon                alejandro carlos       amdrgn                 angel_killah
arcadebros             bitwalk                blackwine              brian burney
budude2                charlysan              chauviere benjamin     dARKrEIGn
dECKARD (Daniel        datajerk               dc9884                 derFunkenstein
elsee2                 eltee                  fbmg                   iunno
jimmysombrero          joe figueroa           kccheng                kerobaros
keropi                 lcscape                liphy                  mattyhochs
metal                  mike roach             moalthan               moises lopez
myusernamewastaken     ogge_leander           ojwales                ordigdug
pixelhans              raoulvp                respergu               retroboi
robert james           robert rodgers         rsn8887                simon black
singularwit            slayer213              snickersnag            sourdille
spaceduck              tim rogers             turbochop3300          twilitezoner
type78                 vampsthevampyre        yoaarond               zombiex123xkill xxx
Δlain                  一樹 原                   민주 김
```
