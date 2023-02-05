*This repository has been consolidated in [JTGNG](https://github.com/jtgng)*
# JTKICKER/JTYIEAR FPGA core compatible with Kicker/Yie Ar Kung-fu hardware

You have in your hands a faithful reproduction of Kicker's hardware. We have analysed the PCB and extracted full schematics from it. We burnt EPROMs with specific code designed to test the custom chips functionality. The discoveries found during this process have been reported to the MAME team. So we can improve the experience in emulators where possible too.

You can show your appreciation through
* [Patreon](https://patreon.com/jotego)
* [Paypal](https://paypal.me/topapate)

# Known Issues

It hasn't been possible to assess whether the INTSHOW custom chip outputs the current scan line or the current vertical scroll position, as these values are the same for over a third of the line. And it is at that time when when the INTSHOW value is easy to read, as it is when the NMI interrupt comes in. In practice, it doesn't seem to matter.

The relays used in the sound signal path in some games may be for altering the filter response or for shutting off a channel. The purpose is not clear and I still have to measure the effect on the board.

# System Comparison

Games based on 082, 083 and 503 graphic chips. All have a pixel clock of 6.144MHz derived from a 18.432MHz oscillator.

Game            | Date       | ID  | Palette PROM  | 085 | CPU1 | CPU2     | PSG   | VLM5030  | Sch                         | eBay price    |     YT views      |
----------------|------------|-----|---------------|-----|------|----------|-------|----------|-----------------------------|---------------|-------------------|
Mega Zone       |       1983 | No  |  Only output  | No  | 6809 | Z80+8039 | x1    | No       | Yes, only 083               |25€            |10.614(2016)       |
Yie Ar Kungfu   |19/Nov/1984 |GX407|  Only output  | No  | 6809 |          | 74689 | Yes      | Yes, only 082,083           |15€ cart       |3.6 M (2013) NES   |
Shaolin's Road  |22/Mar/1985 |GX477| All elements  | Yes | 6809 |          | 74689 | No       | Yes                         |97.13€         |27.664(2018)       |
Track'n Field   |10/Oct/1983 | No  | All elements  | No  |      |          |       | Yes      | Partial-Blurred             |7 a 60€ cart   |2.7 M (2015) NES   |
Hyper Sports    |31/May/1984 | No  | All elements  | Yes |      |          |       | Yes      | Same as Road Fighter        |80€            |41.562(2012)       |
Road Fighter    |22/Nov/1984 |GX461| All elements  |     | 6809 | Z80      | 74689 | Yes      | Yes                         |15 a 70€ cart  |4 M (2010) NES     |
Super Basketball|       1984 |GX405| All elements  | Yes | 6809 | Z80      | 74689 | Yes      | Yes,with labels             |159€           |23.494 (2014)      |
Mikie           |15/Nov/1984 | No  | All elements  | Yes | 6809 | Z80      |2x74689| No       | Yes,with labels, small      |11€     cart   |50.381 (2010)      |
Pandora's Palace|       1984 | No  | Only output   | Yes |      |          |       | No       | Yes,with labels             |      €        |14.167 (2010)      |
Ping Pong       |            |GX555|               |     |      |          |       |          | Extracted by JOTEGO         |60€            |8.530 (2012) NES   |
Roc'n Rope      |       1984 | No  | Only output   | No  |      |          | 8910  | No       | Yes, only 082,083           |350€PCB 50€cart|43.873 (2011)      |
Circus Charlie  |       1984 |     |               | No  | 6809 | Z80      | 74689 | No       | Yes, 082, 602               |350€PCB 50€cart| 107k              |

Road Fighter uses the same board as Hyper Sports, but a ROM jumper in the video board is different, changing the ROM mapping. Road Fighter does not have the VLM5030 section soldered.

# Test Mode

* Super Basketball test mode is enabled by holding 1P and 2P while the game boots
* The upper 3 bits for DIP switches in Road Fighter/Hyper Sports are undocumented. Bit 16 sets the flip mode in Road Fighter and a different ROM mapping in Hyper Sports

# Acknowledgement

This development has been possible thanks to the board donated by Brian Schinzel and the following patrons:

```
8bits4ever             Adam Leslie            Adam Small             Adam Zorzin
Adrian Labastida       Alan Shurvinton        Alda Alesio            Alden
Alex Mandic            Alexander Lash         Alexander Upton        Alfonso Clemente
Alvaro Paniagua        Andrea Bogazzi         Andrea Chiavazza       Andreas Micklei
Andrew Boudreau        Andrew Hannan          Andrew P Gibson        Andrew Schmidt
Angel Aguinaga         Angelfred              Angelo Kanaris         Anselmo Moreno
Anthony Monaco         Antoine Mariette       Anton Gale             Antwon
Aquijacks (Flashjacks  Arend Pronk            Arthur Blough          Arthur Fung
Aurich Lawson          BRCDEvg                Banane                 Bear S
Ben                    Ben Sanborn            Ben Toman              Bitmap Bureau
Bitmaps Retro          Bliz 452               Blue Abs               Boris Pruessmann
Brandon Lennie         Brandon Peach          Brandon Smith          Brandon Thomas
Brent Fraser           Brian Peek             Brian Plummer          Bruno M
Bryan Adams            Bryan Evans            C                      Cameron Berkenpas
Cameron Tinker         Carrboroman            Cesar Sandoval         Charles
Chris                  Chris Chung            Chris D                Chris Hoff
Chris Maguire          Chris Mzhickteno       Chris Tuckwell         Chris W Miller
Chris smith            Christian Bailey       Clinton Cronin         Cobra Clips
Colin Colehour         Colin Edwards          Colt83                 Cory Stargel
DARK WEB DANGer        Dan Doyle              Daniel                 Daniel .
Daniel Casadevall      Daniel Dongil          Daniel Fowler          Daniel Page
Daniel Tibi            Daniel Zetterman       Darren Newman          Darren Wootton
Daryll David           Dasutin                Dave Douglas           Dave Test
David Drury            David Filskov          David Fleetwood        David Jones
Denis Brækhus          Denny Letourneau       Diana Carolina         Didgeridoo
Didier Touron          Dimitris Zongas        Dr Catjail             Dr. Octagon
DrMnike                Dre137                 Edward Mallett         Eren Kotan
Eric                   Eric Gutt              Eric J Faulkes         Eric Walklet
Fabio Michelin         Federico               Five Year Guy          Florian Raoult
Frank Schwab           Fred Rojas             Geddon                 GeorgeSpinner
Gluthecat              GohanX                 Goolio                 Grant McNaught
Greg                   Greg Sargent           Gregory Val            HFSPlay
Handheld Obsession     Henry                  Henry R                Hentai Joe
Hugo Pinto             ItsBobDudes            JOSE LUIS              JR
Jack Sammons           Jacob Hoffman          Jacob Lawter           James Dingo
James Durden           James Kilgore          James Wilson           Jason Baker
Jeff Roberts           Jeremy Hasse           Jerry Suggs            Jesse Clark
Jim Knowler            JimLahey               Jimmy Dozier           Jimmy Richards
Jockel                 Joel Albino            Johan Smolinski        John Figueroa
John Fletcher          John Hood              John Silva             John T. Keen
John Wilson            Johnny harvick         Jonah Phillips         Jonathan
Jonathan Brochu        Jonathan Loor          Jonathan Tuttle        JonathanValls
Joost Peters           Jootec from            Jorge                  Jork Sonkinfield
Jose L                 Jose Lopez             Josep Barbie           Joseph Kulinski
Joseph Milazzo         Joseph Mogavero        Josh Emery             Josh Mayer
Josh Yates-Walker      Josiah Wilson          Julian Baptiste        Justin D'Arcangelo
Kai Cherry             Kai Luotojoki          Keith Gordon           Kem Yos
Ken Scott              Kevin Dayton           Kevin Gudgeirsson      KnC
Kricys                 KrzysFR                Kyle Pedersen          L.Rapter
Lakeside               Laurent Cooper         Lee Grocott            Lee Osborne
Luis F Giron           M Reznor               MaDDoG                 Mack H
Madox                  Magnus Kvevlander      Manuel Astudillo       Marco Emparan
Mark Baffa             Mark DeRidder          MarthSR                Martin Ansin
Matt Elder             Matt Evans             Matt Hargett           Matt Heinrich
Matt Lichtenberg       Matt McCarthy          Matt Postema           Matthew Pollard
Matthew Woodford       MechaGG                MiSTer Retro           Michael Anderson
Michael Bariszlovits   Michael Berger         Michael C              Michael Eggers
Michael Ferguson       Michael Rea            Michael_DKT            Mike Holzinger
Mike Jegenjan          Mike Olson             Mike Parks             Mottzilla
My War                 Nailbomb               Narugawa               Neil St Clair
NerdyNester            Nic Kaiman             Nick Delia             Nick Gudauskas
Nico Stamp             Nicolas Hurtado        Niko                   NonstopXiaowei
Norman Wehrle          Obvious Fakename       OopsAllBerrys          Or even
Oriez                  Oskar Sigvardsson      PANICKED SCREECHING.   Pascal Courtois
Patrick Roman          Paul                   Paul Cunningham        Paul Hoggett
Paulo M.               Paweł Mandes           PeFClic                Pedro Santiago
Per Ole                Philip Lai             Philip Lawson          Piafoman
Pierre-Emmanuel Martin Pontus Nyholm          Rachael Netz           Rachel Schaeffer
Ramon Gamaliel         RandomRetro            Raphael Melgar         Raul3D
RayGun                 RetroRGB               Rex Kung               Rex Willer
Richard Eng            Richard Murillo        Richard Simpson        Rick Ochoa
Riyad Twair            Robert Daniel          Robert Hayes           Romain Dijoux
Ronald Dean            Ronan Amicel           Ruben                  Ryan
Ryan O'Malley          SIDKidd64              Sam Hall               Samuel Warner
Sang Hee               Sascha Zupanek         Schnookums             Ser Erris
Shannon King           Simon Osborne          Spank Minister         SteelRush
Stefan Krueger         Stephen R Price        Steve Ikeguchi         Steve Lin
Steve Skrzyniarz       Steve Tack             Steven Hansen          Steven Yedwab
Stuart Morton          Sunder Raj             SuperBabyHix           Synbios
Syrotuck               Taehyun Kim            Taiki Hosoda           Tales Dilli
Terse                  The Collector          The Video              TheLevelOfDetail .
Thomas Attanasio       Thomas Irwin           Thorias                Timothy Bearup
Tobias Dossin          Tom Milner             Topher Campbell        Travis Brown
Trifle                 Turboman UK            Ty B                   VickiViperZabel
Victor Bly             Victor Fontanez        Will Abbott            William Clemens
William Tryon          Yunus Soğukkanlı       Zach Marquette         Zoltan Kovacs
albertprime            alejandro carlos       angel_killah           arcadebros
benedict lindley       blackwine              brian burney           cbab
chauviere benjamin     circletheory           datajerk               deathr0w
deathwombat            derFunkenstein         gunmakuma              jbrlll
jim br                 joshewah777            kamel rasennadja       kccheng
kernelchagi            keropi                 liphy                  meng po
metal                  natalie                nonamebear             pacoarcade
patrick pejic          qzxcvbn                retroPREZ              retrod00d
rsn8887                slayer213              taal.M                 tonitellezb
troy coberly           turbochop3300          type78                 yoaarond
```
