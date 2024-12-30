# JTTMNT FPGA core Compatible with Konami's TMNT hardware

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

This core is based on the official schematics for this system and the [reverse engineering work done by Furrtek](https://github.com/furrtek/SiliconRE/tree/master/Konami). Contrary to Furrtek's own FPGA core, this implementation tries to make the RTL code more readable and targeted to modern hardware. Both implementations should be equivalent in the critical aspects.

# Service Mode

When entering service mode, the system will go into a lengthy video ROM check process. At some point, it will look like the screen just went crazy. That is normal. If you wait long enough, the check results will be presented and you can on with the rest of the service menu.

The core does not currently support video ROM checks, so the ROMs will be reported as BAD. This does not affect gameplay.

# Credits

Special thanks to [Furrtek](http://furrtek.free.fr/) for all his open source research. Thanks too to DJ Hardrich for lending this PCB for analysis.

Thanks to August 2023 Patreon supporters


```
3style                 8bits4ever             A Hernandez            A Murder
Aaron Ray              Aaron S                Adam Leslie            Adam Small
Adrian Labastida       Adrien Pestel          Alan Shurvinton        Alec Peden
Alex Mandic            Alexander Facchini     Alexander Lash         Alexander Upton
Alfonso Clemente       AllDarnDavey           Allen Tipper           Allister Fiend
Alvaro Paniagua        Andrea Chiavazza       Andreas Micklei        Andrew Boudreau
Andrew Hannan          Andrew Schmidt         Angel Aguinaga         Angelfred
Angelo Kanaris         AnotherJoe             Anselmo Moreno         Anthony Archer
Anthony Monaco         Anton Gale             Antwon                 Arend Pronk
Arjan de Lang          Arkadiusz              Armin Hierstetter      Arthur Fung
Aurich Lawson          BRCDEvg                Banane                 Barley Cheezers
Batlab Electronics     Bear S                 Ben Cullen             Ben Toman
BigRedPimp             Birrdman               Bit2018                Bitmap Bureau
Bitmaps Retro          Bluezer222             Boris Prüßmann         Brandon Arnold
Brandon Peach          Brandon Thomas         Brandoon               Brent Fraser
Brian Birkinbine       Brian Nagel            Brian Peek             Brian Shiver
Brianna Cluck          Bruce Fontaine         Bruno Meyere           Bruno Silva
Bryan Evans            Byshop303              CF                     Cameron Berkenpas
Cameron Tinker         Carlos Gruberman       Chad Page              Charles
Charles Paek           Chris                  Chris Angelini         Chris Babishoff
Chris D                Chris Davis            Chris Hauk             Chris Hoff
Chris Jardine          Chris Maguire          Chris Mzhickteno       Chris Petroni
Chris S                Chris Scully           Chris Tuckwell         Chris W Miller
Chris Waltham          Christophe GARDES      Clinton Cronin         Clinton McCarty
Cobra Clips            Colin Colehour         Collidingforces        Cosmic Savant
Craig Kergald          Craig McLaughlin       Damien D               Dan Anderson
Dan Kelley             Dane Biegert           Daniel .               Daniel Dongil
Daniel Flowers         Daniel Page            Daniel Zee             Daniele Pellegrini
Danny Austin           Danny Garfield         Darren Wootton         Daryl Boothe
Daryll David           Dave Douglas           Dave Nice              David
David Fleetwood        David Gallène          David Osborne          David Stone
DenizB                 Dennis Ranker          Denny Letourneau       Devon Meunier
Diana2Carolina         Didier Touron          Diego Farrell          Douglas Alves
Dr Catjail             Dr. Octagon            DrMnike                Dre137
DrewtoriousFGC         Dward Venegas          EDDY                   Ed
EdgarsDouble           Edward Mallett         Emile Denichaud        Enzo
Epixjava               Eren Kotan             Eric Gutt              Eric J Faulkes
Eric Schneider         Eric Sorensen          Erik                   F Iron
F34R                   FROELIGER              Fabian L               Fabio Michelin
Fabrice Odero          Fabricio               Fahim Rahman           Federico
Five Year Guy          Frank Brevoort         GarethY                GeorgeSpinner
GigaBoots              Girth305               Glenn                  Glenn Percival
Gord Allott            Gordon Coughlin        Grady Leer             Grant McNaught
Gregory Val            Grummkol               Guillermo Tunon        Guy Taylor
HamsoloPlays           Harmonica              Heinz Stampfli         Henry
Henry R                Hermes Yan             Hugo Pinto             Ian Kester-Haney
ItalianGrandma         ItsBobDudes            JAMES D BOOTH          JSwan
Jack Follansbee        Jack Sammons           Jacob Hoffman          Jakob Schmid
James Boone            James Dingo            James Ervin            James Mayes
James Miller           James Trautner         James Wilson           Janne Heikkarainen
Jason Baker            Jason Dee              Jason Jacobs           Javier Heredia
Jayson Larose          Jeff Roberts           Jeremie Barnes         Jeremy Hopkins
Jerry Langwell         Jerry Suggs            Jesse Clark            Jesse Rankin
Jesus Garcia           Jim Hendricks          Jim Knowler            JimLahey
Jimmy Dozier           Jimmy Ecker            Jimmy Kim              Jimmy Richards
Jms                    Jockel                 Joe Dinges             Joe Giuliano
Joel Albino            Johan Smolinski        John Dawson            John Fletcher
John Hood              John K                 John T. Keen           John Torn
John Wilson            John Woods             Johnny harvick         Jonathan
Joost Peters           Jork Sonkinfield       Jose Perez             Josep Barbie
Joseph Campo           Joseph Kulinski        Joseph Milazzo         Josh Yates-Walker
Juan Barriga           Juan E. Gayon          Juan Pablo             Jukka Hast
Justin D'Arcangelo     Kael Spencer           Kai Cherry             Kai Luotojoki
Kaiosten               Keith Gordon           Kellerkind             Ken B
Ken Scott              Kevin Dayton           Kevin Miller           Kike Alcor
Kimberley Fisher       KnC                    Konrad                 Kricys
Krisztian Lanyi        KrzysFR                Kyle Pedersen          Kyle Peters
Kyo Kim                L.Rapter               Lakeside               Lance Bohy
Lars Vonhof-Hunold     Lee Osborne            LoBai Zen              Luc JOLY
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
Nadir Shabazz          Nailbomb               NerdyNester            Nic B.
Nic Kaiman             Nicholas Bold          Nick Daniels           Nick Delia
Nick Gudauskas         Nico Stamp             Niko                   Nolan
NonstopXiaowei         Noyman29               Obvious Fakename       Odilio FRAGATA
Oliver Heilmann        Omar Najera            Omega16bit             OnkelPipi
Oriez                  Oskar Maria            Oskar Sigvardsson      Oyvind Christiansen
Pablo Avila-Estevez    Patrick Roman          Paul Cunningham        Paul Jr
Paulo M.               Paulo Nascimento       Paweł Mandes           PeFClic
Pedro Delao            Pedro Santiago         Per Ole                Peter Mehes
Philip Lai             Philip Lawson          Potato                 Prime1984
ProfessorAnon          Pumpy Crumpy           Ralph Barbagallo       Ramon Gamaliel
Ramon jimenez          RandomRetro            Raphael Melgar         Raul3D
Rautz                  RayGun                 Reborn 187             RetroRGB
Rex Kung               Richard Murillo        Richard Simpson        Richard Smith
Rob Mossefin           Robert Hayes           Roberto Mercado        Robin Hertzberg
Rog                    Romain Dijoux          Romier Silvera         Ronald Dean
Ronan Amicel           Ronin Yojimbo          RoryDropkick           Rufo Sanchez
Rune P                 Russ Crandall          Ryan                   Ryan Clark
Ryan Kasper            Ryne Weiss             Sam Hall               Samuel Pizarro
Samuel Warner          Sang Hee               Sascha Zupanek         Sayit BELET
Schnookums             Scott Bender           Sean Lake              Sean Quinn
Ser Erris              Shad Uttam             Shannon King           Shen mue
Sherwood Hachtman      Shon Garraway          Sigmund68k             Skeletex
Sonthayaya Siha        Spank Minister         StealthCT              SteelRush
Stefan Krueger         Stephen                Stephen Pagenstecher   Stephen R Price
Steve Lin              Steve Skrzyniarz       Steve Tack             Steven A
Steven Hansen          Steven Keller          Stuart Morton          Sunder Raj
Synbios                TAKA Hara              TMoney                 Taehyun Kim
Tales Dilli            Terse                  TgrMstr                That's A
The Collector          The Video              Thomas Attanasio       Thomas Popper
Thomas Ruf             Thorias                Timothy Bearup         Timothy Latunde
Tobias Dossin          Tom Milner             Tony Shong             Topher Campbell
Transientfire          Trifle                 Two Bards              Ty B
Tyson Hanes            Unlovedhomie           VERHILLE Arnaud        VickiViperZabel
Victor Fontanez        Victor Yoon            Vincent Lietart        Wesley Lyons
Will Abbott            Will Summerville       William Clemens        William Roussin
XC-3730C               Xaxius                 Yunus Soğukkanlı       Zack Fawley
Zoltan Kovacs          aguijon                alejandro carlos       amdrgn
angel_killah           arcadebros             blackwine              brian burney
charlysan              chauviere benjamin     dARKrEIGn              dECKARD (Daniel
datajerk               derFunkenstein         elsee2                 eltee
fbmg                   ill_deez               joe figueroa           jonathan capparelli
kccheng                kernelchagi            kerobaros              keropi
liphy                  mattyhochs             metal                  moalthan
myusernamewastaken     ogge_leander           ojwales                ordigdug
raoulvp                respergu               retroboi               robert rodgers
rsn8887                slayer213              sourdille              spaceduck
tim rogers             troy coberly           turbochop3300          twilitezoner
type78                 vampsthevampyre        yoaarond               Δlain
```