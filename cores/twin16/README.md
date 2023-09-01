# JTTWIN16 FPGA core Compatible with Konami's Twin16 hardware

By Jose Tejada (@topapate)

You can show your appreciation through
* [Patreon](https://patreon.com/jotego)
* [Paypal](https://paypal.me/topapate)
* [Github](https://github.com/sponsors/jotego)

Project source code hosted at http://www.github.com/jotego/jtcores
License: GPL3, you are obligued to publish your code if you use mine


Yes, you always wanted to have an arcade board at home. First you couldn't get it because your parents somehow did not understand you. Then you grow up and your wife doesn't understand you either. Don't worry, JT cores are here to the rescue.

I hope you will have as much fun with this project as I had while working on it!

# Hardware Information

This core is based on the official schematics for this system and the reverse engineering work done by Skutis on them. It is also based on our own lab measurements of a working board.

# Graphic Chips

This system seems to implement many of the ideas seen in the TMNT/Aliens sprite chipset. However, instead of using two pairs of chips, one for sprites and one for tilemaps, this early implementation uses many more custom and discrete chips.

Not all the information on these chips is known at the moment. The following is either known or speculative information:

- Tilemap chip 0077'79 holds the scroll register values, regardless of the lower bits connecting directly to 0077'81 through external registers
- 0077'79 must have a memory mapper feature so AB[12:11] will be used to drive the external RAM depending upon configuration
- Objects use two frame buffers, contrary to the line buffers seen in TMNT/Aliens
- Object chip 0077'83 parses object data during DMA, by checking only the priority byte
- Object data takes 8kB for 512 sprites x 16 bytes. Then gets parsed down to 2kB

Comparing this chipset with TMNT/Aliens:

- There is no hardware zoom for sprites
- There is no row/column scroll for tile maps
- There is no H/V flip for the fixed layer

# Credits

Special thanks to Skutis for all his open source research and for lending us the board.

Thanks to September 2023 Patreon supporters

```
3style                 8bits4ever             A Hernandez            A Murder
Aaron Ray              Adam Leslie            Adam Small             Adebola Adeniran
Adrian Labastida       Alan McGrath           Alan Shurvinton        Alec Peden
Alex Baldwin           Alex Mandic            Alexander Facchini     Alexander Lash
Alexander Upton        Alfonso Clemente       AllDarnDavey           Allen Tipper
Allister Fiend         Alvaro Paniagua        Andrea Chiavazza       Andreas Micklei
Andrew Boudreau        Andrew Hannan          Andrew Schmidt         Angel Aguinaga
Angelfred              Angelo Kanaris         AnotherJoe             Anselmo Moreno
Anthony Archer         Anthony Bruscella      Anthony Monaco         Anton Gale
Antwon                 Arend Pronk            Arjan de Lang          Arkadiusz
Armin Hierstetter      Arthur Fung            Aurich Lawson          BRCDEvg
Banane                 Barley Cheezers        Batlab Electronics     Bear S
Ben Cullen             Ben Toman              BigRedPimp             Birrdman
Bit2018                Bitmap Bureau          Bitmaps Retro          Bluezer222
Boris Prüßmann         Brandon Arnold         Brandon Peach          Brandon Thomas
Brandoon               Brent Fraser           Brian Birkinbine       Brian Nagel
Brian Peek             Brian Shiver           Brianna Cluck          Bruce Fontaine
Bruno Meyere           Bruno Silva            Bryan Evans            Byshop303
CF                     Cameron Berkenpas      Cameron Tinker         Carlos Gruberman
Chad Page              Charles                Charles Paek           Chris
Chris Angelini         Chris Babishoff        Chris C                Chris D
Chris Davis            Chris Hauk             Chris Hoff             Chris Jardine
Chris Maguire          Chris Mzhickteno       Chris Petroni          Chris S
Chris Scully           Chris Tuckwell         Chris W Miller         Chris Waltham
Christophe GARDES      Clayton Anderson       Clinton Cronin         Clinton McCarty
Cobra Clips            Colin Colehour         Collidingforces        Cosmic Savant
Craig Kergald          Craig McLaughlin       Damien D               Dan Anderson
Dan Kelley             Dane Biegert           Daniel .               Daniel Dongil
Daniel Flowers         Daniel Page            Daniel Zee             Daniele Pellegrini
Danny Austin           Danny Garfield         Darren Wootton         Daryl Boothe
Daryll David           Dave Bennett           Dave Douglas           Dave Nice
David                  David Fleetwood        David Gallène          David Osborne
David Stone            DenizB                 Dennis Ranker          Denny Letourneau
Devon Meunier          Diana2Carolina         Didier Touron          Diego Farrell
Douglas Alves          Dr Catjail             Dr. Octagon            DrMnike
Dre137                 DrewtoriousFGC         E M                    Ed
EdgarsDouble           Edward Mallett         Emile Denichaud        Enzo
Epixjava               Eren Kotan             Eric Gutt              Eric J Faulkes
Eric Schneider         Eric Sorensen          Erik                   F Iron
F34R                   FROELIGER              Fabian L               Fabio Michelin
Fabrice Odero          Fabricio               Fahim Rahman           Federico
Five Year Guy          Frank Brevoort         GarethY                GeorgeSpinner
GigaBoots              Girth305               Glenn                  Glenn Percival
Gord Allott            Gordon Coughlin        Grant McNaught         Gregory Val
Grummkol               Guillermo Tunon        Guy Taylor             H G
HamsoloPlays           Harmonica              Heinz Stampfli         Henry
Henry R                Hermes Yan             Hugo Pinto             Ian Kester-Haney
ItalianGrandma         ItsBobDudes            JAMES D BOOTH          JSwan
Jack Follansbee        Jack Sammons           Jacob Hoffman          Jakob Schmid
James Boone            James Dingo            James Ervin            James Mayes
James Miller           James Trautner         James Wilson           Janne Heikkarainen
Jason Baker            Jason Dee              Jason Jacobs           Javier Heredia
Jayson Larose          Jeff Roberts           Jeremie Barnes         Jerry Langwell
Jerry Suggs            Jesse Clark            Jesse Rankin           Jesus Garcia
Jim Hendricks          Jim Knowler            JimLahey               Jimmy Dozier
Jimmy Ecker            Jimmy Kim              Jimmy Richards         Jms
Jockel                 Joe Dinges             Joe Giuliano           Joel Albino
Johan Smolinski        John Dawson            John Fletcher          John Hood
John K                 John T. Keen           John Torn              John Wilson
John Woods             Johnny harvick         Jonathan               Joost Peters
Jork Sonkinfield       Jose Perez             Josep Barbie           Joseph Campo
Joseph Kulinski        Joseph Milazzo         Josh Yates-Walker      Juan Barriga
Juan E. Gayon          Juan Pablo             Jukka Hast             Justin D'Arcangelo
Kael Spencer           Kai Cherry             Kai Luotojoki          Kaiosten
Keith Gordon           Kellerkind             Ken B                  Ken Scott
Kevin Dayton           Kevin Miller           Kike Alcor             Kimberley Fisher
KnC                    Konrad                 Kricys                 Krisztian Lanyi
KrzysFR                Kyle Pedersen          Kyle Peters            Kyo Kim
L.Rapter               Lakeside               Lance Bohy             Lars Vonhof-Hunold
Lee Osborne            LoBai Zen              Lost Retro             Luc JOLY
Lucian                 Lucius Bono            Luis F Giron           M Reznor
MaDDoG                 Mack H                 Madox                  Magnus Aspling
Magnus Kvevlander      Mane Function          Manfred Müller         Manksalot
Marcello Medini        Mark Floyd             Mark Jeffers           Mark Saunders
MarthSR                Matt Bouverie          Matt Evans             Matt McCarthy
Matt Postema           Matt Simonds           Matt Vulcano           Matthew Compston
Matthew Heyman         Matthew Woodford       Matthieu Marchione     Max
Max Power              MechaGG                Mehdi Daouas           MiSTer Retro
Michael Bariszlovits   Michael Eggers         Michael Jahosky        Michael Maple
Michael Petri          Michael Rea            Michael V.             Mickaël Renou
Mike Holzinger         Mike Jegenjan          Mottzilla              Mysterious Benefactor
Nadir Shabazz          Nailbomb               Neo Noon               NerdyNester
Nic B.                 Nic Kaiman             Nicholas Bold          Nick Daniels
Nick Delia             Nick Gudauskas         Nico Stamp             Night Thief
Niko                   Nolan                  NonstopXiaowei         Noyman29
Obvious Fakename       Odilio FRAGATA         Oliver Heilmann        Omar Najera
Omega16bit             OnkelPipi              Oriez                  Oskar Maria
Oskar Sigvardsson      Oyvind Christiansen    Pablo Avila-Estevez    Patrick Roman
Paul Cunningham        Paul Jr                Paulo M.               Paulo Nascimento
Paweł Mandes           PeFClic                Pedro Delao            Pedro Santiago
Per Ole                Peter Mehes            Peter Olsen            Philip Lai
Philip Lawson          Potato                 Prime1984              ProfessorAnon
Pumpy Crumpy           R Omar Leal            Ralph Barbagallo       Ramon Gamaliel
Ramon jimenez          RandomRetro            Raphael Melgar         Raul3D
Rautz                  RayGun                 Reborn 187             RetroRGB
Rex Kung               Richard Murillo        Richard Simpson        Richard Smith
Rob Mossefin           Robert Hayes           Roberto Mercado        Robin Hertzberg
Rog                    Roger Ong              Romain Dijoux          Romier Silvera
Ronald Dean            Ronan Amicel           Ronin Yojimbo          RoryDropkick
Rufo Sanchez           Rune P                 Russ Crandall          Ryan
Ryan Clark             Ryan Kasper            Ryne Weiss             Sam Hall
Samuel Pizarro         Samuel Warner          Sang Hee               Sascha Zupanek
Schnookums             Scott Bender           Sean Lake              Sean Quinn
Ser Erris              Shad Uttam             Shannon King           Shen mue
Sherwood Hachtman      Shon Garraway          Sigmund68k             Skeletex
Sonthayaya Siha        Spank Minister         StealthCT              SteelRush
Stefan Krueger         Step 3                 Stephen                Stephen Pagenstecher
Stephen R Price        Steve Lin              Steve Skrzyniarz       Steve Tack
Steven A               Steven Hansen          Steven Keller          Stuart Morton
Sunder Raj             Supaslicer             Synbios                TAKA Hara
TMoney                 Taehyun Kim            Tales Dilli            Terse
TgrMstr                That's A               The Collector          The Video
Thomas Attanasio       Thomas Popper          Thomas Ruf             Thorias
Timothy Bearup         Timothy Latunde        Tobias Dossin          Tom Milner
Tony Shong             Topher Campbell        Transientfire          Trifle
Twipp                  Two Bards              Ty B                   Tyson Hanes
Unlovedhomie           VERHILLE Arnaud        VickiViperZabel        Victor Fontanez
Victor Yoon            Vincent Lietart        Vinn Svy               Visa-Valtteri Pimiä
Wesley Lyons           Will Abbott            Will Summerville       William C.
William Clemens        William Laughner       William Roussin        XC-3730C
Xaxius                 Yunus Soğukkanlı       Zack Fawley            Zoltan Kovacs
aguijon                alejandro carlos       amdrgn                 angel_killah
arcadebros             bitwalk                blackwine              brian burney
charlysan              chauviere benjamin     dARKrEIGn              dECKARD (Daniel
datajerk               dc9884                 derFunkenstein         elsee2
eltee                  fbmg                   ill_deez               iunno
joe figueroa           jonathan capparelli    kccheng                kernelchagi
kerobaros              keropi                 liphy                  mattyhochs
metal                  moalthan               myusernamewastaken     ogge_leander
ojwales                ordigdug               raoulvp                respergu
retroboi               robert rodgers         rsn8887                singularwit
slayer213              sourdille              spaceduck              tim rogers
troy coberly           turbochop3300          twilitezoner           type78
vampsthevampyre        yoaarond               Δlain
```