JTExed FPGA clone of Exed Exes arcade faithful to original hardware
==========================================================================

Please, read the main README file too.

You have just got a middle priced €200 arcade PCB. You have in your hands
a faithful conversion of the circuits on the Exed Exes PCB to FPGA. If you come from
the emulation world here are some of the things different from emulators:

-Real CPU/GPU bus sharing with accurate delays
-Sprites handled with DMA exactly as in the original hardware
-Graphics priority handled as the original PROMs indicate
-Palette registers and bits as the original hardware
-No lag between image and input. Data is being sent to the screen in real time.
-Sound sampling rate: exactly the original
-Video timing accurate
-All interrupts for both CPUs generated at the exact time
-Accurate FPS 100% same as real hardware

These technical aspects mean that the game play will be different from an emulator
in a number of ways and that some hardware tricks that were not emulated will work
here as in the original hardware.

Hardware
========

-Two Z80 CPUs, like Commando
-Basic sprite hardware, same as GnG
-16x16 foreground tilemap with hardware mapper
-32x32 background tilemap (hardware mapper), only 2 bits per pixel!
-Interesting mix of PSG chips

Schematics were not available, so I extracted them from the PCB. They are
available in the schematics folder. The core is made based on the actual
schematics, not emulators. Emulators miss a few points, but some of the
missing hardware features seem not to be used by the game software.

Note: to advance through the test screen press the fire button, except for
the input screen, that requires fire+UP to advance. There is no music selection
in the test menu, only a fixed tune is played in the output test screen.

CREDITS
=======

Brought to you by Jose Tejada, aka jotego. Meet me in twitter @topapate
Checkout my patreon page here: http://patreon.com/jotego

When the game is in pause, the credit screen is shown. You can disable it
by pressing 1P or 2P.

Special thanks to all August '21 patrons.

Tier +5 Patrons Thanks!!
========================

                     80's spaceman        Adam Leslie          Adam Small
Adam Zorzin          Adrian Labastida     Adrian Nabarro       Alan Shurvinton
Alexander Lash       Alexander Upton      Alfonso Clemente     Alvaro Paniagua
Andrea Chiavazza     Andreas Micklei      Andrew Boudreau      Andrew Schmidt
Angelo Kanaris       Anthony Monaco       Antoine Mariette     Anton Gale
Antwon               Aquijacks (Flashjacks Arend Pronk          Arthur Blough
Arthur Fung          BRCDEvg              Banane               Bear S
Ben Toman            Bitmap Bureau        Bitmaps Retro        Bliz 452
Brandon Peach        Brandon Smith        Brandon Thomas       Brent Fraser
Brian Peek           Brian Plummer        Bruno Freitas        Bruno M
C                    Cameron Tinker       Carrboroman          Cesar Sandoval
Charles              Chris Chung          Chris Mzhickteno     Chris Tuckwell
Chris W              Chris smith          Christian Bailey     Clinton Cronin
Cobra Clips          Colin Colehour       Colt83               DARK WEB
Dan Doyle            Daniel               Daniel Casadevall    Daniel Fowler
Daniel Page          Daniel Zetterman     Darren Wootton       Dasutin
David Drury          David Filskov        David Fleetwood      David Jones
Denis Brækhus        Diana Carolina       Dimitris Zongas      Dr Catjail
DrMnike              Dre137               Eren Kotan           Eric J
Eric Schlappi        Federico             Five Year            Florian Raoult
Focux                GeorgeSpinner        Gluthecat            GohanX
Gonzalo Lopez        Goolio               Greg                 Gregory Val
HFSPlay              Handheld Obsession   Henry                Ibrahim
ItsBobDudes          JOSE LUIS            JR                   Jack Sammons
Jacob Hoffman        Jacob Lawter         James B              James Dingo
James Kilgore        Javier Rodas         Jeff Roberts         Jeremy Hasse
Jerry Suggs          Jesse Clark          Jesus Rodriguez      Jim Knowler
Jimmy Dozier         Jockel               Johan Smolinski      John Figueroa
John Fletcher        John Hood            John Silva           John T.
John Wilson          Jonah Phillips       Jonathan Brochu      Jonathan Loor
Jonathan Tuttle      Joost Peters         Jootec from          Jorge
Jork Sonkinfield     Joseph Kulinski      Joseph Milazzo       Joseph Mogavero
Josh Emery           Josh Mayer           Josiah Wilson        Justin D'Arcangelo
Kai Cherry           Keith Gordon         Kem Yos              Ken Scott
Kendrick Hughes      Kevin Gudgeirsson    KnC                  KrzysFR
L.Rapter             LFT                  Laurent Cooper       Lee Grocott
Lee Osborne          Luc JOLY             MaDDoG               Mack H
Magnus Kvevlander    Manuel Astudillo     Marco Emparan        Mark Baffa
Mark Davidson        MarthSR              Martin Ansin         Matheus
Matt Elder           Matt Evans           Matt Lichtenberg     Matt McCarthy
Matt ODonnell        Matthew Humphrey     Matthew Woodford     MechaGG
Megan Alnico         Michael Anderson     Michael Berger       Michael C
Michael Deshaies     Michael Rea          Mick Stone           Mike Holzinger
Mike Jegenjan        Mike Olson           Mike Parks           Mottzilla
NINE                 Nailbomb             Narugawa             Neil St
NerdyNester          Nick Delia           Nick G               Nico Stamp
Nicolas Hurtado      Niko                 NonstopXiaowei       Norman Wehrle
OopsAllBerrys        Oriez                Oskar Sigvardsson    Parker Blackman
Pascal Courtois      Patrick Roman        Paul Cunningham      Paul M
Paulo M.             Paweł Mandes         PeFClic              Per Ole
Philip Lai           Philip Lawson        Piafoman             Pierre-Emmanuel Martin
Pontus Nyholm        Rachael Netz         Rachel Schaeffer     RayGun
RetroRGB             Richard Eng          Richard Murillo      Richard Simpson
Rick Ochoa           Romain Dijoux        Ronald Dean          Ronan Amicel
Roro                 Ryan                 Ryan O'Malley        Sam Hall
Samuel Warner        Schnookums           Shannon King         Spank Minister
SteelRush            Stefan Krueger       Stephen R            Steve Ikeguchi
Steve Skrzyniarz     Steve Tack           Steven Hansen        Steven Yedwab
Stuart Morton        SuperBabyHix         Taehyun Kim          Tales Dilli
Tatton Partington    TealShark            Terse                The Collector
The Video            TheLevelOfDetail .   Thomas Attanasio     Thomas Capetanakis
Thomas Irwin         Timothy Bearup       Tired Crusty         Tobias Dossin
Travis Brown         Trifle               Turboman UK          Ty B
VickiViperZabel      Victor Bly           Victor Fontanez      Will Abbott
William Clemens      Yunus Soğukkanlı     Zach Marquette       Zoltan Kovacs
albertprime          alejandro carlos     angel_killah         arcadebros
benedict lindley     blackwine            brian burney         cbab
chauviere benjamin   datajerk             deathwombat          derFunkenstein
gunmakuma            joshewah777          kccheng              kernelchagi
liphy                meng po              natalie              nonamebear
qzxcvbn              retrod00d            rsn8887              slayer213
taal.M               tonitellezb          troy coberly         yoaarond
종규 박