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

Some of the MRA files provided may not work as there is some variation in Bubble Bobble bootleg hardware which is not implemented. Official Tokio MRA file will not work because the MCU hardware is not yet implemented in the core. Only the bootleg MRA for Tokio works.

Note for developers: Tokio hangs up after a life is lost if the RBF is compiled without sound.

## Documentation

The cores have been developed by combining information in the MAME drivers with PLD dumps from the PLD archive and with full schematic extraction from the PCBs.

## Schematics

Schematics have been extracted from PCB and are available in the several sch folders. Schematic are drawn using KiCAD 5.

PCB                    |  sch location            | Author              | PDF
-----------------------|--------------------------|---------------------|------
Extermination          | cores/kiwi/sch/exterm    | JOTEGO (E. Triana)  | [pdf](https://github.com/jotego/jtbin/tree/master/sch/exterm.pdf)
Insector X             | cores/kiwi/sch/insectx   | Skutis              | [pdf](https://github.com/jotego/jtbin/tree/master/sch/insectx.pdf)
The New Zealand Story  | cores/kiwi/sch/tnzs      | Skutis              | [pdf](https://github.com/jotego/jtbin/tree/master/sch/tnzs.pdf)

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
0x157fae8              3style                 8bits4ever             A Hernandez
A Murder               Aaron Ray              Adam Foster            Adam Leslie
Adam Small             Adam Zorzin            Adrian Labastida       Alan McGrath
Alan Shurvinton        Alberta Dave           Alda Alesio            Alden
Alec Peden             Alex Baldwin           Alex Mandic            Alexander Facchini
Alexander Lash         Alexander Upton        Alfonso Clemente       Alfredo Henriquez
AllDarnDavey           Allen Tipper           Allen Tulowitzki       Allister Fiend
Alvaro Paniagua        Andrea Chiavazza       Andreas Micklei        Andrew Boudreau
Andrew Hannan          Andrew Kaczrowski      Andrew P Gibson        Andrew Schmidt
Angel Aguinaga         Angelfred              Angelo Kanaris         AnotherJoe
Anselmo Moreno         Anthony Cheng          Anthony Monaco         Antoine Mariette
Anton Gale             Antwon                 Aquijacks (Flashjacks  Arend Pronk
Arkadiusz              Armin Hierstetter      Arnulf Eide            Arthur Blough
Arthur Fung            Aunaste                Aurich Lawson          AzathothCultist
BRCDEvg                Banane                 Barley Cheezers        Bear S
Ben                    Ben Cullen             Ben Mininberg          Ben Tiefert
Ben Toman              BigRedPimp             Bit2018                Bitmap Bureau
Bitmaps Retro          Bliz 452               Boris Pruessmann       Brad Higginbotham
Brandon Lennie         Brandon Peach          Brandon Smith          Brandon Thomas
Brandon Yoder          Brandoon               Brent Fraser           Brian Birkinbine
Brian Peek             Brian Plummer          Brian Shiver           Brianna Cluck
Bruce Fontaine         Bruno Freitas          Bruno Meyere           Bruno Silva
Bryan Evans            Byshop303              C                      Cameron Berkenpas
Cameron Tinker         Carlos Bailleres       Carlos Gruberman       Casey Hamann
Cedric Vioget          Cesar Sandoval         Chad Page              Charles
Chris                  Chris Angelini         Chris Babishoff        Chris Brentano
Chris Chung            Chris Coughlan         Chris D                Chris Davis
Chris Hauk             Chris Hoff             Chris King             Chris Maguire
Chris Mzhickteno       Chris Petroni          Chris Scully           Chris Sewell
Chris Tuckwell         Chris W Miller         Chris keesler          Chris smith
Christophe GARDES      Chuong Dang            Clayton Anderson       Clinton Cronin
Clinton McCarty        Cobra Clips            Coldheat007            Colin Colehour
Collidingforces        Cory Sizemore          Cosmic Savant          Craig McLaughlin
Crystal Cauley         Dakken                 Damien D               Dan Kelley
Dane Biegert           Daniel                 Daniel .               Daniel Dongil
Daniel Flowers         Daniel Fowler          Daniel Ibanez          Daniel Page
Daniel Zee             Daniel Zetterman       Daniele Pellegrini     Danny Garfield
Darren Attwood         Darren Wootton         Daryll David           Dasutin
Dave Bennett           Dave Douglas           Dave Nice              David
David Drury            David Fleetwood        David Frost            David Osborne
David Stone            DeanoC                 Denis Brækhus          Dennis Ranker
Denny Letourneau       Devon Meunier          Diana2Carolina         Didgeridoo
Didier Malenfant       Didier Touron          Dimitris Zongas        Douglas Alves
Dr Catjail             Dr. Octagon            DrMnike                Dre137
Drew Roberts           Dubesinhower           Dward Venegas          Ed
Edgar Fuentes          EdgarsDouble           Edward Mallett         Emile Denichaud
Enthropy               Epixjava               Eren Kotan             Eric
Eric Gutt              Eric J Faulkes         Eric Schlappi          Eric Schneider
Eric Sorensen          Erik                   F34R                   FROELIGER
Fabio Michelin         Fabrice Odero          Fabricio               Fahim Rahman
Federico               Fernando Irons         Five Year Guy          Florian Raoult
Focux                  Francis B              Franco Catrin          Frank Brevoort
Frank Hoedemakers      Frank Schwab           Fred Rojas             GA
Gavin C                Geddon                 GeorgeSpinner          GigaBoots
Girth305               Glenn Percival         Gluthecat              GohanX
Gord Allott            Gordon Coughlin        Grant McNaught         Greg
Greg Sargent           Gregory Val            Grummkol               Grzegorz {NineX}
Guillermo Tunon        GuitarJedi             Gutxi Haitz            Guy Taylor
Gwaland                HFSPlay                HamsoloPlays           Handheld Obsession
Hans Baier             Harmonica              Heinz Stampfli         Henry
Henry R                Hermes Yan             Hilton Price           Hugo Pinto
Hunter                 Ibrahim                Igor Brodecki          IndieKebab
ItalianGrandma         ItsBobDudes            JAMES D BOOTH          JOSE LUIS
JR                     JSwan                  Jack Sammons           Jacob Hoffman
Jacob Lawter           Jakob Schmid           James Boone            James Dingo
James Mann             James Miller           James Nivin            James Trautner
James Wilson           Janne Heikkarainen     Jason Baker            Jason Dee
Jason Jacobs           Javier Heredia         Jayson Larose          Jeff Roberts
Jeremie Barnes         Jeremy Hopkins         Jeremy Kelaher         Jerry Langwell
Jerry Suggs            Jerry Yuan             Jesse Clark            Jesse Rankin
Jesus Garcia           Jesus Rodriguez        Jim Hendricks          Jim Knowler
JimLahey               Jimmy Dozier           Jimmy Ecker            Jimmy Richards
Jindo Fox              Job van                Jockel                 Joe Dinges
Joe Giuliano           Joel Albino            Johan Smolinski        John Dawson
John Figueroa          John Fletcher          John Hood              John K
John T. Keen           John Torn              John Wilson            John Woods
Johnny harvick         Jon Prusik             Jonah Phillips         Jonathan
Jonathan Brochu        Jonathan Loor          Jonathan Tuttle        JonathanValls
Joost Peters           Jorge                  Jorge Crisostomo       Jork Sonkinfield
Jose L                 Jose Perez             Josep Barbie           Joseph Campo
Joseph Johnston        Joseph Kulinski        Joseph Milazzo         Joseph Mogavero
Josh Hogan             Josh Yates-Walker      Juan Barriga           Juan Pablo
Julian Baptiste        Justin D'Arcangelo     Justin Rudebaugh       Kai Cherry
Kai Luotojoki          Kaiosten               Kaya Bear              Keith Duncan
Keith Gordon           Kellerkind             Ken B                  Ken Scott
Kendrick Hughes        Kevin Dayton           Kevin Gudgeirsson      Kevin Miller
Kike Alcor             Kimberley Fisher       KnC                    Konrad
Kricys                 Kristian.              KrzysFR                Kyle Pedersen
Kyo Kim                L.Rapter               LFT                    Lakeside
Lance Bohy             Lars Vonhof-Hunold     Lee Grocott            Lee Osborne
LoBai Zen              Luc JOLY               Lucian                 Lucius Bono
Luis F Giron           M Reznor               MaDDoG                 Mack H
Madox                  Magnus Aspling         Magnus Kvevlander      Mane Function
Manksalot              Manuel Astudillo       Marc Nuernberger       Marcello Medini
Marco                  Marco Cuevas           Marco Emparan          Mark Baffa
Mark Floyd             Mark Jeffers           Mark R                 Mark Saunders
Markonnen              MarthSR                Matheus                Matt Bouverie
Matt Elder             Matt Evans             Matt Hargett           Matt Heinrich
Matt McCarthy          Matt Postema           Matt Simonds           Matt Vulcano
Matthew Compston       Matthew Heyman         Matthew J              Matthew Woodford
Matthieu Marchione     Max                    Max Power              MechaGG
Megan Alnico           Mehdi Daouas           MiSTer Retro           Michael Anderson
Michael Bariszlovits   Michael Berger         Michael Eggers         Michael Petri
Michael Rea            Michael_DKT            Mick Stone             Mickaël Renou
Mike Holzinger         Mike Jegenjan          Mike Olson             Mottzilla
Mysterious Benefactor  NINE                   Nadir Shabazz          Nailbomb
Narugawa               Nathan Souris          Neil St Clair          NerdyNester
Nic B.                 Nic Kaiman             Nicholas Bold          Nick Daniels
Nick Delia             Nick Gudauskas         Nico Stamp             Nicolas Hurtado
Niko                   NonstopXiaowei         Norman Wehrle          Noyman29
Obvious Fakename       Odilio FRAGATA         Oliver Heilmann        Omar Najera
OopsAllBerrys          Oriez                  Oskar Maria            Oskar Sigvardsson
OtakuAnthony           Oyvind Christiansen    Pablo Avila-Estevez    Parker Blackman
Pascal Courtois        Patrick McCarron       Patrick Roman          Paul Cunningham
Paul Hoggett           Paul Jr                Paulo M.               Paulo Nascimento
Paweł Mandes           PeFClic                Pedro Santiago         Per Ole
Peter Mehes            Philip Lai             Philip Lawson          Piafoman
Pierre-Emmanuel Martin Pontus Nyholm          Potato                 Prime1984
ProfessorAnon          Pumpy Crumpy           R Omar Leal            Rachel Schaeffer
Ralph Barbagallo       Ramon Gamaliel         Ramon jimenez          RandomRetro
Raph_friend            Raphael Melgar         Raul3D                 Rautz
RayGun                 ReTr0~g!GGles          Reborn 187             RetroRGB
Retro_Brewz            Rex Kung               Rex Willer             Richard Eng
Richard Murillo        Richard Simpson        Richard Smith          Rick Ochoa
Riyad Twair            Rob Mossefin           Robert Hayes           Robin Hertzberg
Romain Dijoux          Romier Silvera         Ronald Dean            Ronan Amicel
Ronin Yojimbo          Roro                   RoryDropkick           Ruben
Rufo Sanchez           Rune P                 Russ Crandall          Ryan
Ryan Clark             Ryan Fig               Ryan Kasper            Ryne Weiss
SIDKidd64              Saiyan                 Sam Hall               Samuel Pizarro
Samuel Warner          Sang Hee               Sascha Zupanek         Sayit BELET
Schnookums             Scott Bender           Sean Quinn             Ser Erris
Seth Wickline          Shad Uttam             Shannon King           Shen mue
Sherwood Hachtman      Shon Garraway          Sigmund68k             Simon Osborne
Skeletex               Sonthaya Sonthaya      Sonthayaya Siha        Spank Minister
Stadium ARTs           SteelRush              Stefan Krueger         Stephen
Stephen Pagenstecher   Stephen R Price        Steve Ikeguchi         Steve Lin
Steve Skrzyniarz       Steve Tack             Steven A               Steven Hansen
Stoneman               Stuart Morton          Sunder Raj             SuperBabyHix
Sweaty McNasty         Synbios                TM421                  TMoney
Taehyun Kim            Tales Dilli            Terse                  The Collector
The Video              TheLevelOfDetail .     Thomas Attanasio       Thomas Irwin
Thomas Popper          Thomas Ruf             Thorias                Tim Inman
Timothy Bearup         Tobias Dossin          Tom Milner             Tony Shong
Travis Brown           Trifle                 Troy                   Trucker 69
Two Bards              Ty B                   Tyson Hanes            VERHILLE Arnaud
VickiViperZabel        Victor Bly             Victor Emmanuel        Victor Fontanez
Vincent Lietart        Wesley Lyons           Weston Boldt           Will Abbott
William Clemens        William Roussin        William Tryon          XC-3730C
Xaxius                 Yonghan                Yoshi9288              Yunus Soğukkanlı
Zach Marquette         Zane                   Zoltan Kovacs          aguijon
alejandro carlos       alexcom                amdrgn                 angel_killah
arcadebros             benedict lindley       blackwine              brian burney
cbab                   chauviere benjamin     circletheory           dARKrEIGn
dECKARD                dannahan               datajerk               deathwombat
derFunkenstein         dzponce11              eclipse                eltee
fbmg                   ill_deez               iunno                  jbrlll
jim br                 jonathan capparelli    jose luis              jp
juan jesus             kadybat                kccheng                kernelchagi
kerobaros              keropi                 liphy                  mattcurrie
mattyhochs             meijin3                metal                  myusernamewastaken
natalie                ogge_leander           ohmy                   ojwales
olivier bernhard       patrick pejic          patrick woodburn       raoulvp
retroboi               rsn8887                slayer213              sourdille
spaceduck              starman_jr             thomas winfrey         tim rogers
tonitellezb            troy coberly           turbochop3300          twilitezoner
type78                 vampsthevampyre        yoaarond               Δlain
종규 박
```