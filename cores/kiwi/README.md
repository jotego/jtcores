# FPGA Clone of TNZS Arcade Game

By Jose Tejada (aka jotego - @topapate)

You can show your appreciation through
* [Patreon](https://patreon.com/jotego)
* [Paypal](https://paypal.me/topapate)

Yes, you always wanted to have a The New Zealand Story arcade board at home. First you couldn't get it because your parents somehow did not understand you. Then you grow up and your wife doesn't understand you either. Don't worry, MiST(er) is here to the rescue.

I hope you will have as much fun with it as I had it while making it!

## Supported Games

In chronological order:

 1. Extermination
 2. Insector X
 3. The New Zealand Story
 4. Kageki
 5. Arkanoid Revenge of Doh

**Arkanoid 2** supports spinner on the MiSTer and joystick controls on both MiSTer and Pocket. On the MiSTer the joystick control will require setting the sensitivity to low on the OSD menu. The spinner will likely need a higher setting.

MiSTer forces you to map the joystick directions to spinner buttons. Because of that, you may run out of buttons on the spinner before mapping the coin inputs. Enabling the *button aid* option in the OSD will map the coin button to the up/down buttons, letting you use those forced mappings.

Arkanoid 2 uses a homebrew firmware for the microcontroller ROM as there is no ROM dump available for it. This firmware works ok most of the time but it may produce a **COIN OVERFLOW** error some times and you will need to reboot the game. You can reboot through the OSD on MiSTer. On the Pocket, you can reboot by changing any game setting through the OSD or simply by re-loading the game.

## Documentation

The cores have been developed by combining information in the MAME drivers with PLD dumps from the PLD archive and with full schematic extraction from the PCBs.

## Schematics

Schematics have been extracted from PCB and are available in the several sch folders. Schematic are drawn using KiCAD 5.

PCB                    |  sch location            | Author              | PDF
-----------------------|--------------------------|---------------------|------
Extermination          | cores/kiwi/sch/exterm    | JOTEGO (E. Triana)  | [pdf](https://github.com/jotego/jtbin/tree/master/sch/exterm.pdf)
Insector X             | cores/kiwi/sch/insectx   | Skutis              | [pdf](https://github.com/jotego/jtbin/tree/master/sch/insectx.pdf)
The New Zealand Story  | cores/kiwi/sch/tnzs      | Skutis              | [pdf](https://github.com/jotego/jtbin/tree/master/sch/tnzs.pdf)
Arkanoid Revenge of Doh| cores/kiwi/sch/arknoid2  | Skutis              | [pdf](https://github.com/jotego/jtbin/tree/master/sch/arknoid2.pdf)

## PLD Data

There are dumps of the PLD logic in

1. [Insector X](https://wiki.pldarchive.co.uk/index.php?title=Insector_X)
2. [The New Zealand Story](https://wiki.pldarchive.co.uk/index.php?title=The_New_Zealand_Story)

## Keyboard

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


# ROM Generation

Use the MRA files available in the rom/mra folder. MRA files are the recommended way. Use the MRA-to-ROM converter from Sebdel if your device does not accept MRA files natively.

# Compilation

Refer to [JTFRAME](https://github.com/jotego/jtframe) for compilation instructions.

# SD Card

For MiST copy the file core.rbf to the SD card at the root directory. Copy also the rom you have generated with the name JTGNG.rom. It will get loaded at start. Make sure to have a recent version of MiST/SiDi firmware.

For Analogue Pocket FPGA, check out a short tutorial [here](https://github.com/jotego/jtbin/wiki/Analogue-Pocket-Cores) and a video [here](https://www.youtube.com/watch?v=PdcOtLS2KWE).

# Modules

The FPGA clone uses the following modules:

JT12: For YM2203 sound synthesis. From the same author.
JTFRAME: A common framework for MiST(er) arcades. From the same author.
T80: originally from Daniel Wallner
6801: unknown author

Use `git clone --recurse-submodules` in order to get all submodules when you clone the repository.

# Compilation

Please check [the compilation guide in JTFRAME](modules/jframe/doc/compilation.md)

# Credits

Jose Tejada Gomez. Twitter @topapate
Project is hosted in http://www.github.com/jotego/jt_gng
License: GPL3, you are obligued to publish your code if you use mine

# JTKIWI Supporters

Thank you to Dec 2022-Feb 2023 patrons for supporting **JTKIWI** development and especially to:

```
3style                 8bits4ever             A Hernandez            A Murder
Aaron Ray              Adam Foster            Adam Leslie            Adam Small
Adrian Labastida       Alan Shurvinton        Alda Alesio            Alec Peden
Alex Baldwin           Alex Mandic            Alexander Facchini     Alexander Lash
Alexander Upton        Alfonso Clemente       AllDarnDavey           Allen Tipper
Allister Fiend         Alvaro Paniagua        Andrea Chiavazza       Andreas Micklei
Andrew Boudreau        Andrew Hannan          Andrew Kaczrowski      Andrew P Gibson
Andrew Schmidt         Angel Aguinaga         Angelo Kanaris         AnotherJoe
Anselmo Moreno         Anthony Cheng          Anthony Monaco         Anton Gale
Arend Pronk            Arkadiusz              Armin Hierstetter      Arnulf Eide
Arthur Fung            Aurich Lawson          BRCDEvg                Banane
Barley Cheezers        Bear S                 Ben Cullen             Ben Tiefert
Ben Toman              BigRedPimp             Bit2018                Bitmap Bureau
Bitmaps Retro          Bliz 452               Boris Pruessmann       Brad Higginbotham
Brandon Lennie         Brandon Peach          Brandon Thomas         Brandoon
Brent Fraser           Brian Birkinbine       Brian Peek             Brian Shiver
Brianna Cluck          Bruce Fontaine         Bruno Meyere           Bruno Silva
Bryan Evans            Byshop303              Cameron Berkenpas      Cameron Tinker
Carlos Bailleres       Carlos Gruberman       Cesar Sandoval         Chad Page
Charles                Chris                  Chris Angelini         Chris Babishoff
Chris Brentano         Chris D                Chris Davis            Chris Hauk
Chris Hoff             Chris Maguire          Chris Mzhickteno       Chris Petroni
Chris Scully           Chris Sewell           Chris Tuckwell         Chris W Miller
Chris smith            Christophe GARDES      Chuong Dang            Clayton Anderson
Clinton Cronin         Clinton McCarty        Cobra Clips            Colin Colehour
Collidingforces        Cory Sizemore          Cosmic Savant          Craig McLaughlin
Damien D               Dan Kelley             Dane Biegert           Daniel
Daniel .               Daniel Dongil          Daniel Flowers         Daniel Fowler
Daniel Page            Daniel Zee             Daniele Pellegrini     Danny Garfield
Darren Wootton         Daryll David           Dave Bennett           Dave Douglas
Dave Nice              David                  David Drury            David Fleetwood
David Frost            David Osborne          David Stone            Denis Brækhus
Dennis Ranker          Denny Letourneau       Devon Meunier          Diana2Carolina
Didier Malenfant       Didier Touron          Dimitris Zongas        Douglas Alves
Dr Catjail             Dr. Octagon            DrMnike                Dubesinhower
Dward Venegas          Ed                     Edward Mallett         Emile Denichaud
Epixjava               Eren Kotan             Eric                   Eric Gutt
Eric J Faulkes         Eric Schneider         Eric Sorensen          Erik
F34R                   FROELIGER              Fabio Michelin         Fabrice Odero
Fabricio               Fahim Rahman           Federico               Fernando Irons
Five Year Guy          Florian Raoult         Franco Catrin          Frank Brevoort
Frank Schwab           Gavin C                GeorgeSpinner          GigaBoots
Girth305               Glenn Percival         Gord Allott            Gordon Coughlin
Grant McNaught         Gregory Val            Grummkol               Grzegorz {NineX}
Guillermo Tunon        Guy Taylor             HamsoloPlays           Hans Baier
Harmonica              Heinz Stampfli         Henry                  Henry R
Hermes Yan             Hugo Pinto             Igor Brodecki          ItalianGrandma
ItsBobDudes            JAMES D BOOTH          JR                     JSwan
Jack Sammons           Jacob Hoffman          Jakob Schmid           James Boone
James Dingo            James Mann             James Miller           James Nivin
James Trautner         James Wilson           Janne Heikkarainen     Jason Baker
Jason Dee              Jason Jacobs           Javier Heredia         Jayson Larose
Jeremie Barnes         Jeremy Hopkins         Jerry Langwell         Jerry Suggs
Jerry Yuan             Jesse Clark            Jesse Rankin           Jesus Garcia
Jim Hendricks          Jim Knowler            JimLahey               Jimmy Ecker
Jimmy Richards         Jockel                 Joe Dinges             Joe Giuliano
Joel Albino            John Dawson            John Figueroa          John Fletcher
John K                 John T. Keen           John Torn              John Wilson
John Woods             Johnny harvick         Jonah Phillips         Jonathan
Jonathan Tuttle        Joost Peters           Jorge Crisostomo       Jork Sonkinfield
Jose Perez             Josep Barbie           Joseph Campo           Joseph Kulinski
Joseph Milazzo         Joseph Mogavero        Josh Yates-Walker      Juan Barriga
Juan Pablo             Justin D'Arcangelo     Kai Cherry             Kai Luotojoki
Kaiosten               Kaya Bear              Keith Gordon           Kellerkind
Ken B                  Ken Scott              Kevin Dayton           Kevin Miller
Kike Alcor             Kimberley Fisher       KnC                    Konrad
Kricys                 Kristian.              KrzysFR                Kyle Pedersen
Kyo Kim                L.Rapter               Lakeside               Lance Bohy
Lars Vonhof-Hunold     Lee Grocott            Lee Osborne            LoBai Zen
Lucian                 Lucius Bono            Luis F Giron           M Reznor
MaDDoG                 Mack H                 Madox                  Magnus Aspling
Magnus Kvevlander      Mane Function          Manksalot              Manuel Astudillo
Marcello Medini        Mark Floyd             Mark Jeffers           Mark Saunders
Markonnen              MarthSR                Matt Bouverie          Matt Evans
Matt Hargett           Matt McCarthy          Matt Postema           Matt Simonds
Matt Vulcano           Matthew Compston       Matthew Heyman         Matthew Woodford
Matthieu Marchione     Max                    Max Power              MechaGG
MiSTer Retro           Michael Anderson       Michael Bariszlovits   Michael Petri
Michael Rea            Michael_DKT            Mickaël Renou          Mike Holzinger
Mike Jegenjan          Mottzilla              Mysterious Benefactor  Nadir Shabazz
Nailbomb               Nathan Souris          NerdyNester            Nic B.
Nicholas Bold          Nick Daniels           Nick Delia             Nick Gudauskas
Nico Stamp             Niko                   NonstopXiaowei         Noyman29
Obvious Fakename       Odilio FRAGATA         Oliver Heilmann        Omar Najera
OopsAllBerrys          Oriez                  Oskar Maria            Oskar Sigvardsson
Oyvind Christiansen    Pablo Avila-Estevez    Patrick McCarron       Patrick Roman
Paul Cunningham        Paul Jr                Paulo M.               Paulo Nascimento
Paweł Mandes           PeFClic                Pedro Santiago         Per Ole
Peter Mehes            Philip Lai             Philip Lawson          Pierre-Emmanuel Martin
Potato                 Prime1984              ProfessorAnon          Pumpy Crumpy
R Omar Leal            Rachel Schaeffer       Ralph Barbagallo       Ramon Gamaliel
Ramon jimenez          RandomRetro            Raphael Melgar         Raul3D
Rautz                  RayGun                 Reborn 187             RetroRGB
Retro_Brewz            Rex Kung               Rex Willer             Richard Eng
Richard Murillo        Richard Simpson        Richard Smith          Rob Mossefin
Robert Hayes           Robin Hertzberg        Romain Dijoux          Romier Silvera
Ronald Dean            Ronan Amicel           Ronin Yojimbo          Roro
RoryDropkick           Ruben                  Rufo Sanchez           Rune P
Russ Crandall          Ryan                   Ryan Clark             Ryan Kasper
Ryne Weiss             SIDKidd64              Saiyan                 Sam Hall
Samuel Pizarro         Samuel Warner          Sang Hee               Sascha Zupanek
Sayit BELET            Schnookums             Scott Bender           Sean Quinn
Ser Erris              Seth Wickline          Shad Uttam             Shannon King
Shen mue               Sherwood Hachtman      Shon Garraway          Sigmund68k
Skeletex               Sonthayaya Siha        Spank Minister         Stadium ARTs
SteelRush              Stefan Krueger         Stephen                Stephen Pagenstecher
Stephen R Price        Steve Lin              Steve Skrzyniarz       Steve Tack
Steven A               Steven Hansen          Stoneman               Stuart Morton
Sunder Raj             SuperBabyHix           Synbios                TMoney
Taehyun Kim            Tales Dilli            Terse                  The Collector
The Video              Thomas Attanasio       Thomas Popper          Thomas Ruf
Thorias                Tim Inman              Timothy Bearup         Tobias Dossin
Tom Milner             Tony Shong             Trifle                 Two Bards
Ty B                   Tyson Hanes            VERHILLE Arnaud        VickiViperZabel
Victor Bly             Victor Emmanuel        Victor Fontanez        Vincent Lietart
Wesley Lyons           Will Abbott            William Clemens        William Roussin
William Tryon          XC-3730C               Xaxius                 Yunus Soğukkanlı
Zoltan Kovacs          aguijon                alejandro carlos       alexcom
amdrgn                 angel_killah           arcadebros             blackwine
brian burney           cbab                   chauviere benjamin     dARKrEIGn
dECKARD                datajerk               deathwombat            eclipse
eltee                  fbmg                   ill_deez               jim br
jonathan capparelli    kadybat                kccheng                kernelchagi
kerobaros              keropi                 liphy                  mattcurrie
mattyhochs             meijin3                metal                  myusernamewastaken
ogge_leander           ohmy                   ojwales                raoulvp
retroboi               rsn8887                slayer213              sourdille
spaceduck              starman_jr             thomas winfrey         tim rogers
troy coberly           turbochop3300          twilitezoner           type78
vampsthevampyre        yoaarond               Δlain
```
