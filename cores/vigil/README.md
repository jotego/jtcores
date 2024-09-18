# JTVIGIL FPGA core compatible with the Vigilante hardware

You have in your hands a faithful reproduction of Vigilante's hardware. We have analysed the PCB and the official schematics. This verilog implementation is compatible with all major retro FPGA platforms, particularly MiSTerFPGA.

You can show your appreciation through
* Patreon: https://patreon.com/jotego
* Paypal: https://paypal.me/topapate
* Github: https://github.com/sponsors/jotego

# Disclaimer

This work is for research and historical purposes. This work itself does not contain copyrighted software and should not be packed or distributed with illegal copies of the copyright-protected software.

# Known Issues

None.

# Compilation

Refer to [JTFRAME](https://github.com/jotego/jtframe) for compilation instructions.

# Video Timing

Measured on PCB and verified on the schematics, which are a bit hard to read but putting everything together, it makes sense.

- Pixel clock is 6.144MHz
- H: 256 active pixels, 128 blank pixels
- HSync lasts for 32 pixels, from pixel 40 to 72.
- V blank lasts for 28 lines
- V sync starts 8 lines after Vblank and lasts for 6 lines
- H freq 16.00 kHz
- V freq 56.34  Hz

# Acknowledgement

This development has been possible thanks to the following patrons:

```
8bits4ever             Adam Leslie            Adam Small             Adrian Labastida
Alan Shurvinton        Alex Mandic            Alexander Facchini     Alexander Lash
Alexander Upton        Alfonso Clemente       Allen Tipper           Allister Fiend
Alvaro Paniagua        Andrea Chiavazza       Andreas Micklei        Andrew Boudreau
Andrew Hannan          Andrew P Gibson        Andrew Schmidt         Angel Aguinaga
Angelfred              Angelo Kanaris         Anselmo Moreno         Anthony Monaco
Antoine Mariette       Anton Gale             Antwon                 Aquijacks (Flashjacks
Arend Pronk            Arkadiusz              Arthur Fung            Aurich Lawson
BRCDEvg                Banane                 Bear S                 Ben Sanborn
Ben Toman              BigRedPimp             Bitmap Bureau          Bitmaps Retro
Bliz 452               Blue Abs               Boris Pruessmann       Brandon Lennie
Brandon Peach          Brandon Smith          Brandon Thomas         Brent Fraser
Brian Peek             Bruce Fontaine         Bruno Meyere           Bryan Adams
Bryan Evans            Byshop303              Cameron Berkenpas      Cameron Tinker
Carlos Bailleres       Carlos Gruberman       Carrboroman            Cesar Sandoval
Charles                Chris                  Chris Angelini         Chris Babishoff
Chris D                Chris Hoff             Chris Maguire          Chris Mzhickteno
Chris Scully           Chris Tuckwell         Chris W Miller         Chris smith
Christian Bailey       Clinton Cronin         Cobra Clips            Colin Colehour
Cory Stargel           Dan Doyle              Daniel .               Daniel Casadevall
Daniel Dongil          Daniel Fowler          Daniel Ibanez          Daniel Page
Daniele Pellegrini     Darren Wootton         Daryll David           Dasutin
Dave Bennett           Dave Douglas           David Drury            David Filskov
David Fleetwood        David Jones            Denis Brækhus          Denny Letourneau
Diana Carolina         Didgeridoo             Didier Touron          Dimitris Zongas
Dr Catjail             Dr. Octagon            DrMnike                Dre137
Edward Mallett         Enthropy               Eren Kotan             Eric
Eric Gutt              Eric J Faulkes         Eric Sorensen          Eric Walklet
Fabio Michelin         Fabricio               Federico               Five Year Guy
Florian Raoult         Fred Rojas             GeorgeSpinner          GohanX
Goolio                 Grant McNaught         Greg                   Greg Sargent
Gregory Val            Grumpy Old             Guillermo Tunon        GuitarJedi
Handheld Obsession     Harmonica              Henry                  Henry R
Hentai Joe             Hugo Pinto             ItsBobDudes            JOSE LUIS
JR                     JSwan                  Jack Sammons           Jacob Hoffman
Jacob Lawter           James Dingo            James Kilgore          James Mann
James Wilson           Jason Baker            Jerry Suggs            Jesse Clark
Jim Knowler            JimLahey               Jimmy Richards         Jockel
Joe Giuliano           Joel Albino            Johan Smolinski        John Figueroa
John Fletcher          John Hood              John Silva             John T. Keen
John Wilson            Johnny harvick         Jonah Phillips         Jonathan
Jonathan Brochu        Jonathan Tuttle        JonathanValls          Joost Peters
Jootec from            Jorge                  Jork Sonkinfield       Josep Barbie
Joseph Kulinski        Joseph Milazzo         Joseph Mogavero        Josh Mayer
Josh Yates-Walker      Josiah Wilson          Justin D'Arcangelo     Justin Rudebaugh
Kai Cherry             Kai Luotojoki          Keith Gordon           Ken Scott
Kevin Dayton           Kike Alcor             KnC                    Kricys
KrzysFR                Kyle Pedersen          L.Rapter               Lakeside
Lee Grocott            Lee Osborne            Lucius Bono            Luis F Giron
M Reznor               MaDDoG                 Mack H                 Madox
Magnus Kvevlander      Manuel Astudillo       Marcello Medini        Marco
Marco Emparan          Mark Floyd             MarthSR                Martin Ansin
Matt Elder             Matt Evans             Matt Hargett           Matt Heinrich
Matt McCarthy          Matt Postema           Matthew Pollard        Matthew Woodford
MechaGG                MiSTer Retro           Michael Anderson       Michael Bariszlovits
Michael Berger         Michael C              Michael Eggers         Michael Martin
Michael Rea            Michael_DKT            Mike Holzinger         Mike Jegenjan
Mike Olson             Mottzilla              Nailbomb               Nando Iron
Nathan Souris          Neil St Clair          NerdyNester            Nic Kaiman
Nick Daniels           Nick Delia             Nick Gudauskas         Nico Stamp
Nicolas Hurtado        Niko                   Noyman29               Obvious Fakename
OopsAllBerrys          Oriez                  Pascal Courtois        Patrick McCarron
Patrick Roman          Paul                   Paul Cunningham        Paul Hoggett
Paulo M.               Paweł Mandes           PeFClic                Pedro Santiago
Per Ole                Peter Mehes            Philip Lai             Philip Lawson
Pierre-Emmanuel Martin Rachael Netz           Rachel Schaeffer       Ralph Barbagallo
Ramon Gamaliel         RandomRetro            Raphael Melgar         Raul3D
RayGun                 RetroPrez              RetroRGB               Rex Kung
Rex Willer             Richard Eng            Richard Murillo        Richard Simpson
Riyad Twair            Robert Daniel          Robert Hayes           Romain Dijoux
Ronald Dean            Ronan Amicel           Ruben                  Ryan
Ryan O'Malley          SIDKidd64              Saiyan                 Sam Hall
Samuel Warner          Sang Hee               Sascha Zupanek         Sayit BELET
Schnookums             Ser Erris              Seth Wickline          Shad Uttam
Shannon King           Sigmund68k             Skeletex               Spank Minister
Stadium ARTs           SteelRush              Stefan Krueger         Stephen R Price
Steve Ikeguchi         Steve Lin              Steve Skrzyniarz       Steve Tack
Steven A               Steven Hansen          Steven Yedwab          Stuart Morton
Sunder Raj             SuperBabyHix           Synbios                Taehyun Kim
Tales Dilli            Terse                  The Collector          The Video
Thomas Attanasio       Thomas Irwin           Thorias                Timothy Bearup
Tobias Dossin          Tom Milner             Topher Campbell        Trifle
Tulio Adriano          Two Bards              Ty B                   VickiViperZabel
Victor Bly             Victor Fontanez        Will Abbott            William Clemens
William Tryon          Yunus Soğukkanlı       Zach Marquette         Zoltan Kovacs
albertprime            alejandro carlos       amdrgn                 angel_killah
arcadebros             benedict lindley       blackwine              brian burney
cbab                   chauviere benjamin     circletheory           dARKrEIGn20xx
datajerk               deathr0w               deathwombat            derFunkenstein
gunmakuma              jbrlll                 jim br                 kamel rasennadja
kccheng                kernelchagi            kerobaros              keropi
liphy                  mattcurrie             meng po                metal
natalie                pacoarcade             patrick pejic          raoulvp
retrod00d              rsn8887                slayer213              sourdille
starman_jr             taal.M                 tim rogers             tonitellezb
troy coberly           turbochop3300          twilitezoner           type78
vampsthevampyre        yoaarond
```