# FPGA Clone of Early Arcade Games by Jose Tejada (aka jotego - @topapate)

You can show your appreciation through
* Patreon: https://patreon.com/jotego
* Paypal: https://paypal.me/topapate
* Github: https://github.com/sponsors/jotego

Yes, you always wanted to have a Pang! arcade board at home. First you couldn't get it because your parents somehow did not understand you. Then you grow up and your wife doesn't understand you either. Don't worry, MiST(er) is here to the rescue.

What you get with this is an extremely accurate (allegedly 100% accurate) clone of the original hardware. You will notice differences from emulation if you compare.

I hope you will have as much fun with it as I had it while making it!

# Acknowledgements

Thanks to Ulf Sktunabba for extracting the schematics from an original Pang! board. Those are available in [his repository](https://github.com/skutis/Pang-Schematics). There is also a copy in [this repository](doc/sch/Pang.PDF).

# Supported Games

 1. Pang!
 2. Super Pang!
 3. Block Block

# Keyboard

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


# ROM Generation

There are MRA files available in the [rom/mra](rom/mra) folder. MRA files are the recommended way to boot the core in MiSTerFPGA. Use the [MRA-to-ROM converter](https://github.com/sebdel/mra-tools-c/) from Sebdel if your device does not accept MRA files natively.

# Binary Files

MiSTerFPGA, MiST, SiDi, NeptUNO and MC+/2 platforms are supported. Look for your platform binary files in [JTBIN](https://github.com/jotego). For MiSTerFPGA, the recommended way to get the core binary files is the [update_all](https://github.com/theypsilon/Update_All_MiSTer) script.

# Compilation

This project uses the [JTFRAME](https://github.com/jotego/JTFRAME) framework. Please refer to it.

# Special thanks to Patreon subscribers
```
8bits4ever             Adam Leslie            Adam Small             Adrian Labastida
Alan Shurvinton        Alda Alesio            Alden                  Alex Mandic
Alexander Facchini     Alexander Lash         Alexander Upton        Alfonso Clemente
Allen Tipper           Allister Fiend         Alvaro Paniagua        Andrea Chiavazza
Andreas Micklei        Andrew Boudreau        Andrew Hannan          Andrew P Gibson
Andrew Schmidt         Angel Aguinaga         Angelfred              Angelo Kanaris
Anselmo Moreno         Anthony Monaco         Antoine Mariette       Anton Gale
Aquijacks (Flashjacks  Arend Pronk            Arkadiusz              Arthur Fung
Aurich Lawson          BRCDEvg                Banane                 Bear S
Ben Toman              BigRedPimp             Bitmap Bureau          Bitmaps Retro
Bliz 452               Blue Abs               Boris Pruessmann       Brandon Lennie
Brandon Peach          Brandon Smith          Brandon Thomas         Brent Fraser
Brian Peek             Bruce Fontaine         Bruno Meyere           Bruno Silva
Bryan Adams            Bryan Evans            Byshop303              Cameron Berkenpas
Cameron Tinker         Carlos Bailleres       Carlos Gruberman       Carrboroman
Cesar Sandoval         Charles                Chris                  Chris Angelini
Chris Babishoff        Chris Coughlan         Chris D                Chris Hoff
Chris Maguire          Chris Mzhickteno       Chris Scully           Chris Tuckwell
Chris W Miller         Chris smith            Christian Bailey       Clinton Cronin
Cobra Clips            Colin Colehour         Cory Stargel           Dan Doyle
Daniel .               Daniel Casadevall      Daniel Dongil          Daniel Fowler
Daniel Ibanez          Daniel Page            Daniele Pellegrini     Darren Attwood
Darren Wootton         Daryll David           Dasutin                Dave Bennett
Dave Douglas           David Drury            David Filskov          David Fleetwood
David Jones            Denis Brækhus          Denny Letourneau       Diana Carolina
Didgeridoo             Didier Touron          Dimitris Zongas        Dr Catjail
Dr. Octagon            DrMnike                Dre137                 Edward Mallett
Enthropy               Eren Kotan             Eric                   Eric Gutt
Eric J Faulkes         Eric Sorensen          Fabio Michelin         Fabricio
Federico               Five Year Guy          Florian Raoult         Fred Rojas
Gavin C                GeorgeSpinner          GohanX                 Grant McNaught
Greg                   Greg Sargent           Gregory Val            Guillermo Tunon
Handheld Obsession     Harmonica              Henry                  Henry R
Hentai Joe             Hugo Pinto             ItsBobDudes            JOSE LUIS
JR                     JSwan                  Jack Sammons           Jacob Hoffman
Jacob Lawter           James Dingo            James Kilgore          James Wilson
Janne Heikkarainen     Jason Baker            Jerry Suggs            Jesse Clark
Jim Knowler            JimLahey               Jimmy Richards         Jockel
Joe Dinges             Joe Giuliano           Joel Albino            Johan Smolinski
John Figueroa          John Fletcher          John Silva             John T. Keen
John Wilson            Johnny harvick         Jonah Phillips         Jonathan
Jonathan Brochu        Jonathan Tuttle        JonathanValls          Joost Peters
Jootec from            Jorge                  Jork Sonkinfield       Jose Perez
Josep Barbie           Joseph Kulinski        Joseph Milazzo         Joseph Mogavero
Josh Mayer             Josh Yates-Walker      Josiah Wilson          Justin D'Arcangelo
Justin Rudebaugh       Kai Cherry             Kai Luotojoki          Keith Gordon
Ken B                  Ken Scott              Kevin Dayton           Kike Alcor
KnC                    Kricys                 KrzysFR                Kyle Pedersen
L.Rapter               Lakeside               Lee Grocott            Lee Osborne
Lucius Bono            Luis F Giron           M Reznor               MaDDoG
Mack H                 Madox                  Magnus Kvevlander      Manuel Astudillo
Marcello Medini        Marco                  Marco Emparan          Mark Floyd
MarthSR                Martin Ansin           Matt Elder             Matt Evans
Matt Hargett           Matt Heinrich          Matt McCarthy          Matt Postema
Matthew Pollard        Matthew Woodford       MechaGG                Michael Anderson
Michael Bariszlovits   Michael Berger         Michael C              Michael Eggers
Michael Martin         Michael Rea            Michael_DKT            Mike Holzinger
Mike Jegenjan          Mike Olson             Mottzilla              Nailbomb
Nando Iron             Nathan Souris          Neil St Clair          NerdyNester
Nic Kaiman             Nick Daniels           Nick Delia             Nick G
Nick Gudauskas         Nico Stamp             Niko                   NonstopXiaowei
Noyman29               Obvious Fakename       OopsAllBerrys          Oriez
Oskar Sigvardsson      Pascal Courtois        Patrick McCarron       Patrick Roman
Paul                   Paul Cunningham        Paul Hoggett           Paulo M.
Paweł Mandes           PeFClic                Pedro Santiago         Per Ole
Peter Mehes            Philip Lai             Philip Lawson          Pierre-Emmanuel Martin
ProfessorAnon          R D                    Rachael Netz           Rachel Schaeffer
Ralph Barbagallo       Ramon Gamaliel         RandomRetro            Raphael Melgar
Raul3D                 RayGun                 RetroRGB               Rex Kung
Rex Willer             Richard Eng            Richard Murillo        Richard Simpson
Riyad Twair            Robert Daniel          Robert Hayes           Romain Dijoux
Ronald Dean            Ronan Amicel           Ruben                  Ryan
Ryan O'Malley          SIDKidd64              Saiyan                 Sam Hall
Samuel Pizarro         Samuel Warner          Sang Hee               Sascha Zupanek
Sayit BELET            Schnookums             Ser Erris              Seth Wickline
Shad Uttam             Shannon King           Sherwood Hachtman      Sigmund68k
Skeletex               Spank Minister         Stadium ARTs           SteelRush
Stefan Krueger         Stephen R Price        Steve Ikeguchi         Steve Lin
Steve Skrzyniarz       Steve Tack             Steven A               Steven Hansen
Steven Yedwab          Stuart Morton          Sunder Raj             SuperBabyHix
Synbios                Taehyun Kim            Tales Dilli            Terse
The Collector          The Video              Thomas Attanasio       Thomas Irwin
Thorias                Timothy Bearup         Tobias Dossin          Tom Milner
Tony Shong             Topher Campbell        Trifle                 Tulio Adriano
Two Bards              Ty B                   VickiViperZabel        Victor Bly
Victor Fontanez        Will Abbott            William Clemens        William Tryon
Yunus Soğukkanlı       Zane                   Zoltan Kovacs          albertprime
alejandro carlos       amdrgn                 angel_killah           arcadebros
benedict lindley       blackwine              brian burney           cbab
chauviere benjamin     circletheory           dARKrEIGn              datajerk
deathr0w               deathwombat            derFunkenstein         gunmakuma
jbrlll                 jim br                 jonathan capparelli    kamel rasennadja
kccheng                kernelchagi            kerobaros              keropi
liphy                  mattcurrie             meng po                metal
natalie                pacoarcade             raoulvp                retrod00d
rsn8887                slayer213              sourdille              tim rogers
tonitellezb            troy coberly           turbochop3300          twilitezoner
type78                 vampsthevampyre        yoaarond               Δlain
```
