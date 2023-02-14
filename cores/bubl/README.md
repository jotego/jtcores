# FPGA Clone of Bubble Bobble Arcade Game

By Jose Tejada (aka jotego - @topapate)

You can show your appreciation through
* [Patreon](https://patreon.com/jotego)
* [Paypal](https://paypal.me/topapate)

Yes, you always wanted to have a Bubble Bobble arcade board at home. First you couldn't get it because your parents somehow did not understand you. Then you grow up and your wife doesn't understand you either. Don't worry, MiST(er) is here to the rescue.

I hope you will have as much fun with it as I had it while making it!

## Supported Games

In chronological order:

 1. Tokio (Scrambled Formation)
 2. Bubble Bobble
 3. Extermination
 4. Insector X
 5. The New Zealand Story
 6. Kageki

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

### Bubble Bobble

Set mode to Japanese and test on to enter the test screen. Press 1P start to advance to the input and sound test screen.

Sound codes for music

Sound Code   | Music
-------------|------------
  7          | intro + main theme
  8          | credits
  9          | Super drunk
 10          | Bonus
 11          | Game over
 15          | hurry theme
 16          | Extend
 20          | Real ending

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

## JTBUBL Supporters

Thank you to June 2020 patrons for supporting **JTBUBL** development and especially to:

```
Alonso J. Núñez       Filip Kindt         Michael Fuerst
Andrea Chiavazza      Francis B           Michael Yount
Andreas Micklei       Frank Hoedemakers   Mike Jegenjan
Andrew Boudreau       Gavin               Mike Parks
Andy Palmer           Greg                Nailbomb
Angelo Kanaris        Gregory Val         natalie
Anthony Monaco        HFSPlay             Neil St Clair
atrac17               Human0Target        Nico Stamp
Ben Toman             hyp36rmax           Paweł Mandes
Bob G                 Jesse Clark         Richard Eng
Brent Fraser W.       Johan Smolinski     Richard Murillo
Carrboroman           Justin D'Arcangelo  SNIPERMikeUK
Clinton Cronin        Keith Duncan        Spank Minister
Daniel Estreito       KnC                 Stephen Goldberg
Darren Wootton        Lee Osborne         Steven Yedwab
David Fleetwood       Luc JOLY            taal.M
David Jones           Magnus Kvevlander   Thomas Irwin
DrMnike               Matthew Woodford    Trifle
Eric J Faulkes        M. Penkert-Hennig   VickiViperZabel
Fabio Michelin        Michael Deshaies    Victor Bly
                           XC-3730C
```

## JTKIWI Supporters

Thank you to Dec 2022 patrons for supporting **JTKIWI** development and especially to:

```
3style                 8bits4ever             Aaron Ray              Adam Leslie
Adam Rykowski          Adam Small             Adrian Labastida       Alan Shurvinton
Alda Alesio            Alec Peden             Alex Baldwin           Alex Mandic
Alexander Facchini     Alexander Lash         Alexander Upton        Alfonso Clemente
Allen Tipper           Allister Fiend         Alvaro Paniagua        Andrea Chiavazza
Andreas Micklei        Andrew Boudreau        Andrew Hannan          Andrew P Gibson
Andrew Schmidt         Angel Aguinaga         Angelfred              Angelo Kanaris
AnotherJoe             Anselmo Moreno         Anthony Cheng          Anthony Monaco
Anton Gale             Arend Pronk            Arkadiusz              Armin Hierstetter
Arthur Fung            Aurich Lawson          BRCDEvg                Banane
Barley Cheezers        Bear S                 Ben Cullen             Ben Tiefert
Ben Toman              BigRedPimp             Bit2018                Bitmap Bureau
Bitmaps Retro          Bliz 452               Boris Pruessmann       Brandon Lennie
Brandon Peach          Brandon Thomas         Brandoon               Brent Fraser
Brian Peek             Brian Shiver           Brianna Cluck          Bruce Fontaine
Bruno Meyere           Bruno Silva            Bryan Evans            Byshop303
Cameron Berkenpas      Cameron Tinker         Carlos Bailleres       Carlos Gruberman
Casey Hamann           Cedric Vioget          Cesar Sandoval         Chad Page
Charles                Chris                  Chris Angelini         Chris Babishoff
Chris Brentano         Chris D                Chris Davis            Chris Hauk
Chris Hoff             Chris Maguire          Chris Mzhickteno       Chris O'Neil
Chris Petroni          Chris Scully           Chris Sewell           Chris Tuckwell
Chris W Miller         Chris smith            Christophe GARDES      Clayton Anderson
Clinton Cronin         Cobra Clips            Colin Colehour         Collidingforces
Cory Sizemore          Cosmic Savant          Craig McLaughlin       Damien D
Dan Kelley             Daniel                 Daniel .               Daniel Dongil
Daniel Fowler          Daniel Page            Daniele Pellegrini     Danny Garfield
Darren Wootton         Daryll David           Dasutin                Dave Bennett
Dave Douglas           Dave Nice              David                  David Drury
David Jones            David Stone            Denis Brækhus          Dennis Ranker
Denny Letourneau       Devon Meunier          Diana Carolina         Didier Touron
Dimitris Zongas        Douglas Alves          Dr Catjail             DrMnike
Dubesinhower           Ed                     Edward Mallett         Epixjava
Eren Kotan             Eric                   Eric Gutt              Eric J Faulkes
Eric Schneider         Eric Sorensen          F34R                   FROELIGER
Fabio Michelin         Fabrice Odero          Fabricio               Federico
Five Year Guy          Flavio Real            Florian Raoult         Franco Catrin
Fred Rojas             Gareth Jones           Gavin C                GeorgeSpinner
GigaBoots              Girth305               Glenn Percival         Gord Allott
Grant McNaught         Gregory Val            Grummkol               Guillermo Tunon
Gutxi Haitz            Guy Taylor             HamsoloPlays           Hans Baier
Harmonica              Henry                  Henry R                Hentai Joe
Hugo Pinto             ItalianGrandma         ItsBobDudes            JR
JSwan                  Jack Sammons           Jacob Hoffman          Jakob Schmid
James Boone            James Dingo            James Mann             James Miller
James Nivin            James Trautner         James Wilson           Janne Heikkarainen
Jason Baker            Jason Dee              Javier Heredia         Jayson Larose
Jeremie Barnes         Jeremy Hopkins         Jerry Langwell         Jerry Suggs
Jerry Yuan             Jesse Clark            Jesse Rankin           Jim Knowler
JimLahey               Jimmy Ecker            Jimmy Richards         Job van
Jockel                 Joe Dinges             Joe Giuliano           Joel Albino
John Dawson            John Figueroa          John Fletcher          John K
John Silva             John T. Keen           John Torn              John Wilson
John Woods             Johnny harvick         Jonah Phillips         Jonathan
Jonathan Tuttle        JonathanValls          Joost Peters           Jork Sonkinfield
Jose Perez             Josep Barbie           Joseph Kulinski        Joseph Milazzo
Joseph Mogavero        Josh Hogan             Josh Yates-Walker      Juan Barriga
Juan Pablo             Justin D'Arcangelo     Kai Cherry             Kai Luotojoki
Kaiosten               Kaya Bear              Keith Gordon           Kellerkind
Ken B                  Ken Scott              Kevin Dayton           Kevin Miller
Kike Alcor             Kimberley Fisher       KnC                    Konrad
Kricys                 Kristian.              KrzysFR                Kyle Pedersen
L.Rapter               Lakeside               Lee Grocott            Lee Osborne
LoBai Zen              Lucian                 Lucius Bono            Luis F Giron
M Reznor               MaDDoG                 Mack H                 Madox
Magnus Aspling         Magnus Kvevlander      Mane Function          Manksalot
Manuel Astudillo       Marcello Medini        Mark Floyd             Mark Saunders
MarthSR                Matt Bouverie          Matt Evans             Matt Hargett
Matt Heinrich          Matt McCarthy          Matt Postema           Matt Simonds
Matt Vulcano           Matthew Compston       Matthew Woodford       Matthieu Marchione
Max                    Max Power              MechaGG                MiSTer Retro
Michael Anderson       Michael Bariszlovits   Michael Martin         Michael Rea
Michael_DKT            Mickaël Renou          Mike Holzinger         Mike Jegenjan
Mottzilla              Mysterious Benefactor  Nadir Shabazz          Nailbomb
Nando Iron             Nathan Souris          NerdyNester            Nicholas Bold
Nick Delia             Nick Gudauskas         Nico Stamp             Niko
NonstopXiaowei         Noyman29               Obvious Fakename       Oliver Heilmann
Omar                   Omar Najera            OopsAllBerrys          Oriez
Oskar Maria            Oskar Sigvardsson      Oyvind Christiansen    Pablo Avila-Estevez
Patrick McCarron       Patrick Roman          Paul                   Paul Cunningham
Paul Jr                Paulo M.               Paulo Nascimento       Paweł Mandes
PeFClic                Pedro Santiago         Per Ole                Peter Mehes
Philip Lai             Philip Lawson          Pierre-Emmanuel Martin Potato
ProfessorAnon          R Omar Leal            Rachel Schaeffer       Ralph Barbagallo
Ramon Gamaliel         RandomRetro            Raphael Melgar         Raul3D
RayGun                 RetroRGB               Retro_Brewz            Rex Kung
Rex Willer             Richard Eng            Richard Murillo        Richard Simpson
Robert Hayes           Robin Hertzberg        Romain Dijoux          Romier Silvera
Ronald Dean            Ronan Amicel           Roro                   RoryDropkick
Ruben                  Rune P                 Russ Crandall          Ryan
Ryan Clark             Ryan Kasper            Ryne Weiss             SIDKidd64
Saiyan                 Sam Hall               Samuel Pizarro         Samuel Warner
Sang Hee               Sascha Zupanek         Schnookums             Scott Bender
Ser Erris              Seth Wickline          Shad Uttam             Shannon King
Shen mue               Sherwood Hachtman      Shon Garraway          Sigmund68k
Skeletex               Spank Minister         Stadium ARTs           SteelRush
Stefan Krueger         Stephen                Stephen Pagenstecher   Stephen R Price
Steve Lin              Steve Skrzyniarz       Steve Tack             Steven A
Steven Hansen          Stoneman               Stuart Morton          Sunder Raj
SuperBabyHix           Synbios                TMoney                 Taehyun Kim
Tales Dilli            Terse                  The Collector          The Video
Thomas Attanasio       Thorias                Tim Inman              Timothy Bearup
Tobias Dossin          Tom Milner             Tony Shong             Trifle
Two Bards              Ty B                   Tyson Hanes            VickiViperZabel
Victor Bly             Victor Emmanuel        Victor Fontanez        Vincent Lietart
Wesley Lyons           Will Abbott            William Clemens        William Roussin
William Tryon          XC-3730C               Xaxius                 Yunus Soğukkanlı
Zoltan Kovacs          aguijon                alejandro carlos       alexcom
amdrgn                 angel_killah           arcadebros             blackwine
brian burney           cbab                   chauviere benjamin     dARKrEIGn
dECKARD                datajerk               deathwombat            eclipse
eltee                  fbmg                   ill_deez               jbrlll
jim br                 jonathan capparelli    kadybat                kccheng
kernelchagi            kerobaros              keropi                 liphy
mattcurrie             mattyhochs             meijin3                metal
myusernamewastaken     ogge_leander           ojwales                patrick woodburn
raoulvp                retroboi               rsn8887                slayer213
sourdille              thomas winfrey         tim rogers             tonitellezb
troy coberly           turbochop3300          twilitezoner           type78
vampsthevampyre        yoaarond               Δlain
```
