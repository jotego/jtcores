# FPGA Clone of Early Arcade Games

Designed by Jose Tejada (jotego - @topapate). PCB donated by **DJ HARDRICH**.

You can show your appreciation through
* [Patreon](https://patreon.com/jotego)
* [Paypal] (https://paypal.me/topapate)

Yes, you always wanted to have a Karate Champ arcade board at home. First you couldn't get it because your parents somehow did not understand you. Then you grow up and your wife doesn't understand you either. On top of that, an original PCB from Japan costs $500. Don't worry, MiST(er) is here to the rescue.

I hope you will have as much fun with it as I had it while making it!

## Known issues

The FPGA clone has been designed around the [schematics available online](https://archive.org/details/karatechampinstallationinstructions) as well as an original PCB. Yet, that covered the 2-player version of the game. The single player version was derived from the MAME driver and the 2P version. Apparently there were several changes in the hardware, making the 2P version a bit more complex. It would be interesting to gain access to the 1P version PCB. But, I do not think the accuracy is compromised for it.

## Keyboard

On MiSTer keyboard control is configured through the OSD.

For MiST and MiSTer: games can be controlled with both game pads and keyboard. The keyboard follows the same layout as MAME's default.

    F2      Test
    F3      Game reset
    P       Pause (press 1p or 2P during pause to hide the credits)
    1,2     1P, 2P start buttons
    5,6     Left and right coin inputs
    9       Service

    cursors 1P direction
    CTRL    1P button 1
    ALT     1P button 2
    space   1P button 3

    R,F,G,D 2P direction
    Q,S,A   2P buttons 3,2 and 1


## ROM Generation

There are MRA files available in the [rom/mra](rom/mra) folder. MRA files are the recommended way to boot the core in MiSTerFPGA. Use the [MRA-to-ROM converter](https://github.com/sebdel/mra-tools-c/) from Sebdel if your device does not accept MRA files natively.

## Binary Files

MiSTerFPGA, MiST, SiDi, NeptUNO and MC+/2 platforms are supported. Look for your platform binary files in [JTBIN](https://github.com/jotego). For MiSTerFPGA, the recommended way to get the core binary files is the [update_all](https://github.com/theypsilon/Update_All_MiSTer) script.

The **Analogue Pocket** version is supported for [Patreon](https://patreon.com/jotego) subscribers only.

## Compilation

This project uses the [JTFRAME](https://github.com/jotego/JTFRAME) framework. Please refer to it for compilation instructions.

## Special thanks to Patreon subscribers

```
8bits4ever             Aaron Ray              Adam Leslie            Adam Rykowski
Adam Small             Adrian Labastida       Alan Shurvinton        Alda Alesio
Alec Peden             Alex Baldwin           Alex Mandic            Alexander Facchini
Alexander Lash         Alexander Upton        Alfonso Clemente       Allen Tipper
Allen Tulowitzki       Allister Fiend         Alvaro Paniagua        Andrea Chiavazza
Andreas Micklei        Andrew Boudreau        Andrew Hannan          Andrew P Gibson
Andrew Schmidt         Angel Aguinaga         Angelfred              Angelo Kanaris
AnotherJoe             Anselmo Moreno         Anthony Monaco         Anton Gale
Aquijacks (Flashjacks  Arend Pronk            Arkadiusz              Arthur Fung
Aunaste                Aurich Lawson          BRCDEvg                Banane
Bear S                 Ben Cullen             Ben Mininberg          Ben Tiefert
Ben Toman              BigRedPimp             Bit2018                Bitmap Bureau
Bitmaps Retro          Bliz 452               Blue Abs               Boris Pruessmann
Brandon Lennie         Brandon Peach          Brandon Thomas         Brandon Yoder
Brandoon               Brent Fraser           Brian Peek             Brian Shiver
Brianna Cluck          Bruce Fontaine         Bruno Meyere           Bruno Silva
Bryan Evans            Byshop303              Cameron Berkenpas      Cameron Tinker
Carlos Bailleres       Carlos Gruberman       Cedric Vioget          Cesar Sandoval
Chad Page              Charles                Chris                  Chris Angelini
Chris Babishoff        Chris D                Chris Davis            Chris Hauk
Chris Hoff             Chris Maguire          Chris Mzhickteno       Chris O'Neil
Chris Petroni          Chris Scully           Chris Tuckwell         Chris W Miller
Chris smith            Christian Bailey       Christophe GARDES      Clayton Anderson
Clinton Cronin         Cobra Clips            Colin Colehour         Cory Stargel
Cosmic Savant          Damien D               Daniel                 Daniel .
Daniel Casadevall      Daniel Dongil          Daniel Fowler          Daniel Page
Daniele Pellegrini     Danny Garfield         Darren Attwood         Darren Wootton
Daryll David           Dasutin                Dave                   Dave Bennett
Dave Douglas           Dave Nice              David Drury            David Fleetwood
David Jones            David Stone            DeanoC                 Denis Brækhus
Dennis Ranker          Denny Letourneau       Devon Meunier          Diana Carolina
Didgeridoo             Didier Touron          Dimitris Zongas        Dr Catjail
Dr. Octagon            DrMnike                Dre137                 Dubesinhower
Ed                     Edward Mallett         Emilio Fahr            Enthropy
Epixjava               Eren Kotan             Eric                   Eric Gutt
Eric J Faulkes         Eric Schneider         Eric Sorensen          F34R
FROELIGER              Fabio Michelin         Fabricio               Federico
Five Year Guy          Flavio Real            Florian Raoult         Fred Rojas
Gareth Jones           Gavin C                GeorgeSpinner          Gord Allott
Grant McNaught         Greg Sargent           Gregory Val            Guillermo Tunon
Gutxi Haitz            Guy Taylor             Gwaland                HamsoloPlays
Handheld Obsession     Harmonica              Henry                  Henry R
Hentai Joe             Hilton Price           Hugo Pinto             ItalianGrandma
ItsBobDudes            JR                     JSwan                  Jack Sammons
Jacob Hoffman          Jacob Lawter           James Dingo            James Kilgore
James Mann             James Wilson           Janne Heikkarainen     Jason Baker
Javier Heredia         Jayson Larose          Jerry Langwell         Jerry Suggs
Jesse Clark            Jim Knowler            Jimmy Richards         Jockel
Joe Dinges             Joe Giuliano           Joel Albino            Johan Smolinski
John Figueroa          John Fletcher          John Silva             John T. Keen
John Wilson            John Woods             Johnny harvick         Jonah Phillips
Jonathan               Jonathan Tuttle        JonathanValls          Joost Peters
Jork Sonkinfield       Jose Perez             Josep Barbie           Joseph Johnston
Joseph Kulinski        Joseph Milazzo         Joseph Mogavero        Josh Hogan
Josh Mayer             Josh Yates-Walker      Juan Pablo             Justin D'Arcangelo
Kai Cherry             Kai Luotojoki          Kaiosten               Keith Gordon
Kellerkind             Ken B                  Ken Scott              Kevin Dayton
Kike Alcor             KnC                    Kricys                 Kristian.
KrzysFR                Kyle Pedersen          L.Rapter               Lakeside
Lee Grocott            Lee Osborne            Lucian                 Lucius Bono
Luis F Giron           M Reznor               MaDDoG                 Mack H
Madox                  Magnus Kvevlander      Manksalot              Manuel Astudillo
Marcello Medini        Mark Saunders          MarthSR                Matt Bouverie
Matt Elder             Matt Evans             Matt Hargett           Matt Heinrich
Matt McCarthy          Matt Postema           Matt Vulcano           Matthew Woodford
Matthieu Marchione     Max                    Max Power              MechaGG
MiSTer Retro           Michael Anderson       Michael Bariszlovits   Michael Berger
Michael Eggers         Michael Martin         Michael Rea            Michael_DKT
Mickaël Renou          Mike Holzinger         Mike Jegenjan          Mike Olson
Mottzilla              Nadir Shabazz          Nailbomb               Nando Iron
Nathan Souris          Neil St Clair          NerdyNester            Nic Kaiman
Nick Daniels           Nick Delia             Nick Gudauskas         Nico Stamp
Niko                   NonstopXiaowei         Noyman29               Obvious Fakename
Omar                   Omar Najera            OopsAllBerrys          Oriez
Oskar Sigvardsson      Oyvind Christiansen    Pablo Avila-Estevez    Patrick McCarron
Patrick Roman          Paul                   Paul Cunningham        Paulo M.
Paulo Nascimento       Paweł Mandes           PeFClic                Pedro Santiago
Per Ole                Peter Mehes            Philip Lai             Philip Lawson
Pierre-Emmanuel Martin ProfessorAnon          R D                    R Omar Leal
Rachael Netz           Rachel Schaeffer       Ralph Barbagallo       Ramon Gamaliel
RandomRetro            Raphael Melgar         Raul3D                 RayGun
RetroRGB               Rex Kung               Rex Willer             Richard Eng
Richard Murillo        Richard Simpson        Robert Daniel          Robert Hayes
Romain Dijoux          Romier Silvera         Ronald Dean            Ronan Amicel
Ruben                  Rune P                 Ryan                   Ryan Clark
Ryne Weiss             SIDKidd64              Saiyan                 Sam Hall
Samuel Pizarro         Samuel Warner          Sang Hee               Sascha Zupanek
Schnookums             Scott Bender           Ser Erris              Seth Wickline
Shad Uttam             Shannon King           Shen mue               Sherwood Hachtman
Sigmund68k             Skeletex               Spank Minister         Stadium ARTs
SteelRush              Stefan Krueger         Stephen                Stephen Pagenstecher
Stephen R Price        Steve Fish             Steve Lin              Steve Skrzyniarz
Steve Tack             Steven A               Steven Hansen          Stuart Morton
Sunder Raj             SuperBabyHix           Synbios                TM421
TMoney                 Taehyun Kim            Tales Dilli            Terse
The Collector          The Video              Thomas Attanasio       Thomas Irwin
Thorias                Timothy Bearup         Tobias Dossin          Tom Milner
Tony Shong             Trifle                 Two Bards              Ty B
Tyson Hanes            VickiViperZabel        Victor Bly             Victor Fontanez
Wesley Lyons           Will Abbott            William Clemens        William Tryon
Yonghan                Yunus Soğukkanlı       Zoltan Kovacs          aguijon
albertprime            alejandro carlos       alexcom                amdrgn
angel_killah           arcadebros             benedict lindley       blackwine
brian burney           cbab                   chauviere benjamin     dARKrEIGn
dECKARD                datajerk               deathwombat            eltee
gunmakuma              jbrlll                 jim br                 jonathan capparelli
kamel rasennadja       kccheng                kernelchagi            kerobaros
keropi                 liphy                  mattcurrie             mattyhochs
meng po                metal                  ojwales                pacoarcade
patrick woodburn       raoulvp                retrod00d              rsn8887
slayer213              sourdille              thomas winfrey         tim rogers
tonitellezb            troy coberly           turbochop3300          twilitezoner
type78                 vampsthevampyre        yoaarond               Δlain
```