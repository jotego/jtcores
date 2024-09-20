# JTCPS - FPGA Arcade Hardware

You can show your appreciation through
* Patreon: https://patreon.com/jotego
* Paypal: https://paypal.me/topapate

Capcom System 1/1.5/2 compatible verilog core for FPGA by Jose Tejada (jotego).

# Original Documentation

[The internet archive](www.archive.org) holds some schematics related to this work.

* [Forgotten Worlds manual](https://archive.org/details/arcademanual_forgotten-worlds/page/n15/mode/2up)

# Memory Requirements

All CPS1 and CPS1.5 operate correctly on a 32MB SDRAM system. Some CPS2 games may require a 64MB module. Those games are listed as having a GFX ROM of 16MB or more below. Please check the CPS2 ROM size section.

# Control

MiSTer allows for gamepad redifinition. However, the keyboard can be used with more or less the same layout as MAME for MiST(er) platforms. Some important keys:

-F12 OSD menu
-P   Pause. Press 1P during pause to toggle the credits on and off
-5,6 1P coin, 2P coin
-1,2 1P, 2P

For MiST, the first 6 gamepad buttons are used for game buttons, the next 2 buttons are used for credit and start buttons. If there is still one button left in the gamepad, it will be used for pause.

There is an option to slow down the game (available only for CPS2). If you enable the 1P_hold_for_slow setting on the OSD, then while the 1P button is held the game will run at half the speed. Release the 1P button to go back to normal speed or disable the option in the OSD. Note that if the option is enabled the 2P, 3P and 4P buttons will also activate the slow down effect.

# Setup

## MiSTer

Copy the RBF file to `_Arcade/cores` and the MRA files to `_Arcade`. Copy zipped MAME romsets to `_Arcade/mame`. Enjoy.

It is also possible to keep the MAME romsets in `_Arcade/mame` but have the MRA files in `_CPS` and the RBF files in `_CPS/cores`

The _rotate screen_ OSD option is ignored for horizontal games.

## MiST

You need to generate the .rom file using this (tool)[https://github.com/sebdel/mra-tools-c/tree/master/release]. Basically call it like this:

`mra ghouls.mra -z rompath -A`

And that will produce the .rom file and a .arc file. The .arc file can be used to start the core and directly load the game rom file. Note that the RBF name must be JTCPS1.RBF for it to work. The three files must be in the root folder.

*Important*: make sure to have the latest firmware and latest version of the mra tool.

Copy the RBF, .arc and .rom files to MiST and enjoy!

Note that there is no screen rotation in MiST. Vertical games require you to turn your screen around. You can however flip the image through the OSD.

Pang! 3 and all CPS 1.5/2 games did not use DIP switches to configure the game, but a small non-volatile RAM. You have to enter the test menu to configure it (via OSD). After you have configured the settings, save the contents using the OSD option *Save NVRAM*. A file will be created at the root of your SD card called game.RAM, where game will match the name of the .ROM file used with the game.

# Issues

Please report issues (here)[https://github.com/jotego/jtcores/issues].

## QSound Hiss

The DSP16A clock enable must be an exact multiple of 30MHz. Otherwise the sampling period will not be constant, generating jitter. The effect of jitter is very obvious in the DAC used on MiST because when all sound goes silent an ugly transient occurs. That effect was not noticeable in MiSTer, which uses a different DAC.

Even with the right clock enable, there is still hiss occasionally in MiST(er). Using the FPGA logic analyzer I could check that the period was indeed constant but hiss was present.

# CPS-1 Audio

The OKI PCM input clock is 1MHz, depending on the SS input setting, this gives two sampling frequencies:

SS | Fs (Hz) |
---|---------|
0  | 6097.5  |
1  | 7575.7  |

The original board has a first-order low pass filter at 770 Hz, this can be implemented with a first order IIR filter:

y[k] = a * y[k-1] + (1-a) * x[k]

where a = exp(-wc/T )
wc = 2*pi*770 = 4838 rad/s
T  = 1/Fs

SS | Fs (kHz) |    a    |  1-a
---|----------|---------|--------
0  | 48.0     | 0.9041  | 0.0959

As an 8-bit decimal number, _a_ would be $E7

The filtering must be done at a higher sampling rate and should be independent of the SS input.

# QSound

QSound requires its own firmware rom to work. In MAME this is called qsound.zip. QSound sampling frequency is 3746 ticks of the input clock, when the clock enable applied is 2/3. For a 90MHz input clock, this will result in the correct internal 30MHz and in a sampling frequency of 90MHz/3747=24,019.2Hz

The original board had a digitally controlled amplifier. The volume set on this amplifier could be read back by the CPU and DSP. In order to control the value read by these devices, press and hold the coin button for 1P while pressing up or down (for more or less volume). Note that this does not have an actual effect on the sound output.

# PAL Dumps
PAL dumps cam be obtained from MAME rom sets directly. Use the tool jedutil in order to extract the equations from them. The device is usually a gal16v8. For instance:

```
jedutil -view wl24b.1a gal16v8
```

In order to see the equations for Willow's PAL.

# Compilation
The core is compiled using jtcore from **JTFRAME**. Follow the instructions in the README file of (JTFRAME)[https://github.com/jotego/jtframe] and then:

```
source setprj.sh
jtcore cps1 -mister
```

This will produce the mister file.

## Static Time Analysis (STA)

MiST and SiDi compilations produce STA clean files with the default seed. However the MiSTer RBF file with everything enabled doesn't always come STA clean. If you disable HDMI or sound during compilation the RBF file will normally be STA clean. Public binary distribution in [jtbin](https://github.com/jotego/jtbin) are either STA clean or violations are below 99ps.

# MRA Format

Offset    | Length | Use
----------|--------|-------------
 0  /  0o |  2     | Sound CPU ROM*
 2  /  2o |  2     | PCM data*
 4  /  4o |  2     | GFX ROM*
 6  /  6o |  2     | QSound firmware*
10h / 20o | 18     | CPS-B configuration
22h / 42o |  1     | Game ID
23h / 43o |  2     | Bank offset
25h / 45o |  2     | Bank mask
27h / 47o |  1     | CPS-A board type (Pang! 3, etc.)
30h / 60o | 11     | Kabuki keys (CPS 1.5 only)
28h / 50o |  1     | CPS2 board type
2ch / 54o | 20     | CPS2 keys

* All offset values are expressed in kilobytes and stored with MSB byte second

The offset for each graphic bank is comprised of two bytes. Each offset data is packed in 4 bits, with the MSB used for bank 3:

{ Offset_bank3, ..bank2, bank1, bank0 } = { byte 24h, byte 23h }

The 4-bit offset makes the MSB of the 20-bit GFX ROM address.

CPS-A board type format:

Bits   |  Use
-------|----------------------------
0      | CPU speed. 0=10MHz, 1=12MHz
3:1    | Enables additional inputs on CPS-B chip side
4      | High for charger games
5      | 0 = Disables Kabuki decryption

CPS2 board type format:

Bits   |  Use
-------|-------
1:0    | Controller type

# SDRAM Usage

## CPS 1/CPS 1.5


SDRAM bank | Usage
-----------|-------
0          | RAM/VRAM/M68000 ROM
1          | Sound CPU/PCM samples
2          | GFX
3          | GFX

## CPS 1.5 ROM Size

The SDRAM layout is the same as for CPS 1. Although samples are much larger than in CPS 1 titles, they still fit in one SDRAM bank sharing space with the Z80 ROM.

Game                  | CPU     |   Z80       | GFX     | Q-Sound |
----------------------|---------|-------------|---------|---------|
Warriors of Fate      | 1   MB  |  128 kB     | 4 MB    | 2 MB    |
Cadillacs & Dinosaurs | 1.5 MB  |  128 kB     | 4 MB    | 2 MB    |
The Punisher          | 1.5 MB  |  128 kB     | 4 MB    | 2 MB    |
S.N. Slam Masters     | 2.0 MB  |  128 kB     | 6 MB    | 4 MB    |
Muscle Bomber Duo     | 2.0 MB  |  128 kB     | 6 MB    | 4 MB    |


## CPS 2 ROM Size

It looks like the 16kB memory add-on is not used for regular games. Maybe it is used for
network connectivity only.

Game                  | CPU     |   Z80       | GFX     | Q-Sound |Obj base| Addon | Popularity
----------------------|---------|-------------|---------|---------|--------|-------|------------
19XX                  | 2.5 MB  |  128 kB     | 10 MB   | 4 MB    | 7080   |  No   | 191
1944                  | 1.5 MB  |  128 kB     | 20 MB   | 8 MB    | 7080   |  No   | 161
Alien vs Predator     | 2.0 MB  |  128 kB     | 16 MB   | 4 MB    | 7000   |  No   | 637
Armored Warriors      | 4.0 MB  |  256 kB     | 20 MB   | 4 MB    | 7000   |  No   | 278
Battle Circuit        | 3.5 MB  |  256 kB     | 16 MB   | 4 MB    | 7080   |  No   |  87
Capcom Sports Club    | 2.5 MB  |  128 kB     |  8 MB   | 4 MB    | 7080   |  No   |  20
Cyberbots             | 4.0 MB  |  256 kB     | 32 MB   | 4 MB    | 7080   |  No   | 141
Darkstalkers          | 4.0 MB  |  256 kB     | 20 MB   | 4 MB    | 7080   |       | 146
Dimahoo               | 2.0 MB  |  256 kB     | 16 MB   | 8 MB    | 7080   |  No   |  32
DnD Shadow o. Mystara | 4.0 MB  |  256 kB     | 24 MB   | 4 MB    | 7080   |  No   | 336
DnD Tower of Doom     | 2.5 MB  |  128 kB     | 12 MB   | 4 MB    | 7080   |  No   | 108
Eco Fighters          | 2.0 MB  |  128 kB     | 12 MB   | 4 MB    | 7000   |       |  64
Giga Wing             | 1.5 MB  |  128 kB     | 16 MB   | 8 MB    | 7080   |       |  66
Hyper SF II           | 4.0 MB  |  256 kB     | 32 MB   | 8 MB    | 7080   |       | 171
Janpai                | 1.0 MB  |  128 kB     | 16 MB   | 4 MB    | 7000   |       |  15
Jyangokushi           | 0.5 MB  |  128 kB     | 16 MB   | 4 MB    |        |       |   1
Mars Matrix           | 1.5 MB  |  128 kB     | 32 MB   | 8 MB    |        |  No   |  57
Marvel Super Heroes   | 4.0 MB  |  256 kB     | 32 MB   | 4 MB    |        |       | 165
Marvel vs SF          | 4.0 MB  |  256 kB     | 32 MB   | 8 MB    |        |       | 336
Marvel vs CAPCOM      | 4.0 MB  |  256 kB     | 32 MB   | 8 MB    |        |       | 377
Megaman 2             | 1.5 MB  |  256 kB     |  8 MB   | 4 MB    |        |       | 225
Darkstalker's revenge | 4.0 MB  |  256 kB     | 32 MB   | 4 MB    |        |       |  54
Progear               | 1.0 MB  |  128 kB     | 16 MB   | 8 MB    | 7080   |  No   |  72
Puzz Loop 2           | 2.0 MB  |  128 kB     | 16 MB   | 4 MB    | 7000   |       |  16
Quiz Nanairo Dreams   | 2.0 MB  |  128 kB     |  8 MB   | 4 MB    |        |       |   8
Ring of Destruction   | 3.0 MB  |  256 kB     | 18 MB   | 4 MB    |        |       | 293
Slam Masters 2        | 3.0 MB  |  256 kB     | 18 MB   | 4 MB    |        |       | 291
SF alpha 1            | 2.0 MB  |  256 kB     |  8 MB   | 4 MB    | 7000   |       | 190
SF alpha 2            | 3.0 MB  |  256 kB     | 20 MB   | 4 MB    | 7000   |       | 218
SF alpha 3            | 4.0 MB  |  256 kB     | 32 MB   | 8 MB    | 7000   |       | 456
SF zero 2 alpha       | 3.0 MB  |  256 kB     | 20 MB   | 4 MB    | 7000   |       | 293
Super Gem Fighter     | 2.5 MB  |  256 kB     | 20 MB   | 8 MB    |        |       | 252
Super Puzzle Fighter 2| 1.0 MB  |  256 kB     |  4 MB   | 4 MB    | 7000   |       | 210
SF2 New Challengers   | 2.5 MB  |  128 kB     | 12 MB   | 4 MB    | 7080   |  No   | 135
SF2 Turbo             | 3.5 MB  |  256 kB     | 16 MB   | 4 MB    | 7080   |       |1200
Vampire Savior 1      | 4.0 MB  |  256 kB     | 32 MB   | 8 MB    |        |       |  30
Vampire Savior 2      | 4.0 MB  |  256 kB     | 32 MB   | 8 MB    |        |       |  26
X-Men Children of A.  | 4.0 MB  |  256 kB     | 32 MB   | 4 MB    | 7080   |  No   | 179
X-Men vs SF           | 3.5 MB  |  256 kB     | 32 MB   | 4 MB    | 7080   |  No   | 337

# Simulation

## Game
1. Generate a rom file using the MRA tool
2. Update the symbolic link rom.bin in ver/game to point to it
3. If all goes well, `go.sh` should update the sdram.hex file
   But if sdram.hex is a symbolic link to something else it might
   fail. You can delete sdram.hex first so it gets recreated

   `go.sh` will fill up sdram.hex with zeros in order to avoid x's in
   simulation.

4. Apply patches if appropiate. The script `apply_patches.sh` can generate
   some alternative hex files which skip some of the test code of the game
   so it boots up more quickly

5. While simulation is running, it is possible to update the output video
   files by running `raw2jpg.sh`

Some Verilog macros:

1. FORCE_GRAY ignore palette and use a 4-bit gray scale for everything
2. REPORT_DELAY will print the average CPU delay at the end of each frame
   in system ticks (number of 48MHz clocks)
3. JTCPS_TURBO forces turbo mode, speeding up -slightly- the game speed, especially on boot-up

## Video

Video only simulations can be done using mame dumps. Use the tool *cfg2mame* in the *ver/video* folder
to create two *.mame* files that can invoked from mame to dump the simulation data. Run the game in debug
mode but source from MAME the register file that *cfg2mame* creates. Then at the point of interest souce *vram.mame*. That creates the file vram.bin. Copy that file to a directory with the mame name of the game. Add a numerical index (see the other folders for examples). Create a hex file following the examples in
the other files too. Now you run go.sh like this:

```
go.sh -g game -s number -frame 2
```

This will run the simulation for the folder *game* and looking for files with the *number* index. If you
 need to look at the sprites too, you need to run more than one frame as the object DMA needs a frame to
 fill in the data.

# Support

You can show your appreciation through
* Patreon: https://patreon.com/jotego
* Paypal: https://paypal.me/topapate

# Licensing

Contact the author for special licensing needs. Otherwise follow the GPLv3 license attached.

# Patron Acknowledgement

The following patrons supported the development of CPS1.5
```
3style              Chris Harvey        Joeri van Dooren    Oliver Wndmth
80's spaceman       cohge               Johan Smolinski     Oriez
Adam Davis          Coldheat007         John Casey          Oscar Laguna Garcia
Alan Shurvinton     Dakken              Jonathan Loor       Oskar Sigvardsson
Alfredo Henriquez   Dan                 Jonathan Tuttle     Patrick Roman Fabri
Alonso J. Núñez     Daniel Bauza        Jorge Slowfret      Paweł Mandes
Anders Rensberg     Daniel Estreito     Josiah Wilson       Per Sweden
Andrea Chiavazza    dannahan            JPS (RetroFPGA)     Phillip McMahon
Andreas Micklei     Darren Wootton      Juan E. Gayon       PsyFX
Andrew Ajello       Dasutin             Justin D'Arcangelo  Purple Tinker
Andrew Boudreau     David Ashby         Kitsuake            Rachael Netz
Andrew Francomb     David Fleetwood     KnC                 RandomRetro
Andrew Moore        David Jones         Kyle Good           RetroDriven
Andy Palmer         David Mills         Lee Osborne         Richard Eng
Andyways            derFunkenstein      Leslie Law          Richard Murillo
angel_killah        DJ Lethal           Lionel LENOBLE      Richard Simpson
Angelo Kanaris      Don Gafford         Louis Martinez      Robert Bergman
Anthony Monaco      DrMnike             Luc JOLY            Robert Forbes
Anton Gale          Ed Balan            Magnus Kvevlander   Robert MacLean
Antonio Villena     Edward Rana         Manuel Astudillo    Robert Mullings
Aquijacks           Eric J Faulkes      Marcus Hogue        Roman Buser
Arcade Express      Filip Kindt         Martin Di Palma     rsn8887
Arjan de Lang       Francis B           Matt Evans          Ryan Fig
asdfgasfhsn         Frank Hoedemakers   Matt ODonnell       Sassbasket Silvercloud
Bear S              Frédéric Mahé       Matthew Humphrey    Sebastien Goutal
Ben Toman           Gary Greenan        Matthew Woodford    Skeeter
Bender              Gavin               Matthew Young       Sofia Rose
Bliz 452            Greg                Max Schütz          Spank Minister
Bob Gallardo        Gregory Val         Michael Deshaies    Spencer Bradley
Brent Fraser        Gus Douboulidis     Michael Yount       Stephen Goldberg
Brett T Davis       Handheld Obsession  Mick Stone          Steven Wilson
brian burney        Hard Rich           Mike Jegenjan       Steven Yedwab
Brian Sallee        Henrik Nordström    Mike Parks          Thomas Irwin
Carrboroman         HFSPlay             MiSTerFPGA.co.uk    Toby Boreham
Charles             hyp36rmax           mottzilla .         Travis Brown
Chi Wai Tran        Jacob Hoffman       Nailbomb            Trifle
Chris Jardine       Jeff Roberts        natalie             Ulf Skutnabba
Chris smith         Jeremy Hasse        Neil St Clair       Ultrarobotninja
Chris W Miller      Jeremy Kelaher      Nico Stamp          Victor Bly
Christian           Jesse Clark         nonamebear          Victor Fontanez
Christian Bailey    Jim Knowler         nullobject          Víctor Gomariz Ladrón de Guevara
Christopher Gelatt  Jo Tomiyori         Oliver Jaksch       Xzarian
                                          yoaarond
```
The following patrons supported the development of CPS2
```
                     80's spaceman        Adam Small           Adam Zorzin
Adam is              Adan Jacquez         Adrian Labastida     Adrian Nabarro
Alan Shurvinton      Alexander Lash       Alexander Upton      Alfonso Clemente
Alonso J.            Alvaro Paniagua      Andrea Chiavazza     Andreas Micklei
Andrew Boudreau      Andrew Schmidt       Angelo Kanaris       Anthony Monaco
Anton Gale           Antwon               Aquijacks (Flashjacks Aqy
Arend Pronk          Arthur Blough        Arthur Fung          BRCDEvg
Banane               Bear S               Ben Toman            Bitmap Bureau
Bitmaps Retro        Bliz 452             Brandon Peach        Brandon Smith
Brandon Thomas       Brent Fraser         Brian Peek           Brian Plummer
Bruno Freitas        Bruno M              C                    Cameron Tinker
Carrboroman          Cesar Sandoval       Charles              Chris Chung
Chris Mzhickteno     Chris Tuckwell       Chris W              Chris smith
Christian Bailey     Clinton Cronin       Cobra Clips          Coldheat007
Colin Colehour       Colt83               DARK WEB             Dan Doyle
Daniel               Daniel Casadevall    Daniel Fowler        Daniel Page
Daniel Zetterman     Darren Wootton       Dasutin              David Drury
David Filskov        David Fleetwood      David Jones          Denis Brækhus
Diana Carolina       Dimitris Zongas      DrMnike              Dre137
Eric J               Eric Schlappi        Eric Walklet         Five Year
Flavio Real          Florian Raoult       Focux                Gluthecat
GohanX               Gonzalo Lopez        Goolio               Greg
Gregory Val          HFSPlay              Handheld Obsession   Henry
Ibrahim              ItsBobDudes          JOSE LUIS            JR
Jack Sammons         Jacob Hoffman        Jacob Lawter         James B
James Dingo          James Kilgore        Javier Rodas         Jeff Roberts
Jeremy Hasse         Jerry Suggs          Jesse Clark          Jesus Rodriguez
Jim Knowler          Jockel               Johan Smolinski      John Figueroa
John Fletcher        John Hood            John Silva           John Wilson
Jonah Phillips       Jonathan Brochu      Jonathan Loor        Jonathan Tuttle
Jootec from          Jorge                Jork Sonkinfield     Joseph Milazzo
Josh Emery           Josh Mayer           Josiah Wilson        Justin D'Arcangelo
Kai Cherry           Keith Gordon         Kem Yos              Ken Scott
Kendrick Hughes      Kevin Gudgeirsson    KnC                  KrzysFR
L.Rapter             LFT                  Laurent Cooper       Lee Grocott
Lee Osborne          Luc JOLY             Mack H               Magnus Kvevlander
Manuel Astudillo     Marco Emparan        Mark Baffa           Mark Davidson
Mark R               MarthSR              Martin Ansin         Matheus
Matsu                Matt Elder           Matt Evans           Matt Lichtenberg
Matt McCarthy        Matt ODonnell        Matthew Humphrey     Matthew Woodford
MechaGG              Megan Alnico         MiSTerFPGA.co.uk     Michael Berger
Michael C            Michael Deshaies     Michael Rea          Mick Stone
Mike Jegenjan        Mike Olson           Mike Parks           Mottzilla
NINE                 Nailbomb             Narugawa             Neil St
NerdyNester          Nick Delia           Nick G               Nico Stamp
Nicolas Hurtado      NonstopXiaowei       OopsAllBerrys        Oriez
Oskar Sigvardsson    Parker Blackman      Patrick Roman        Paul Cunningham
Paul M               Paulo M.             Paweł Mandes         PeFClic
Per Ole              Philip Lai           Philip Lawson        Piafoman
Pierre-Emmanuel Martin Pontus Nyholm        Rachael Netz         Rachel Schaeffer
RandomRetro          Raph_friend          Raphael Melgar       RayGun
Richard Eng          Richard Murillo      Richard Simpson      Rick Ochoa
Ronald Dean          Roro                 Ryan                 Ryan Fig
Ryan O'Malley        Sam Hall             Samuel Warner        Schnookums
Sofia Rose           Spank Minister       SteelRush            Stefan Krueger
Stephen R            Steve Ikeguchi       Steve Skrzyniarz     Steven Hansen
Steven Yedwab        Stuart Morton        SuperBabyHix         Taehyun Kim
Tales Dilli          TealShark            Terse                The Collector
The Video            Thomas Attanasio     Thomas Capetanakis   Thomas Irwin
Tobias Dossin        Travis Brown         Trifle               Turboman UK
Ty B                 VickiViperZabel      Victor Bly           Victor Fontanez
Will Abbott          William Clemens      Yunus Soğukkanlı     Zach Marquette
Zoltan Kovacs        albertprime          alejandro carlos     angel_killah
arcadebros           blackwine            brian burney         bruno_tapez
cbab                 chauviere benjamin   dannahan             datajerk
deathwombat          derFunkenstein       gunmakuma            joshewah777
kccheng              kernelchagi          liphy                natalie
nonamebear           retrod00d            rsn8887              scapeghost
slayer213            taal.M               tonitellezb          troy coberly
yoaarond             종규 박
```