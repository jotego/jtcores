# JTGNG FPGA Arcade Hardware by Jose Tejada (@topapate)

You can show your appreciation through
* [Patreon](https://patreon.com/jotego)
* [Paypal](https://paypal.me/topapate)
* [Github](https://github.com/sponsors/jotego)

Yes, you always wanted to have a Ghosts'n Goblins arcade board at home. First you couldn't get it because your parents somehow did not understand you. Then you grow up and your wife doesn't understand you either. Don't worry, MiST(er) is here to the rescue.

What you get with this is an extremely accurate (allegedly 100% accurate) clone of the original hardware. You will notice differences from MAME if you compare. For instance, on Ghosts'n Goblins try resetting it and compare those screens for a start! Original hardware handled sound and graphics in a different way from the emulator. There were delays in CPU bus access and other details that will make the experience different from an emulator.

I hope you will have as much fun with it as I had it while making it!

## Supported Games

In chronological order:

 1. [Vulgus           ](doc/jtvulgus.txt)
 2. [Higemaru         ](doc/jthige.txt)
 3. [1942             ](doc/jt1942.txt)
 4. [Commando         ](doc/jtcommando.txt)
 5. [Exed Exes        ](doc/jtexed.txt)
 6. [Ghosts'n Goblins ](doc/jtgng.txt)
 7. [SectionZ         ](doc/jtsectionz.txt)
 8. [GunSmoke         ](doc/jtgunsmoke.txt)
 9. [Legendary Wings  ](doc/jtsectionz.txt)
10. [Trojan           ](doc/jttrojan.txt)
11. [The Speed Rumbler](doc/jtrumble.txt)
12. [1943             ](doc/jt1943.txt)
13. [Black Tiger      ](doc/jtbtiger.txt)
14. [Side Arms        ](doc/jtsarms.txt)
15. [Tiger Road       ](doc/jttora.txt)
16. [F1-Dream         ](doc/jtf1dream.txt)
17. [Bionic Commando  ](doc/jtbiocom.txt)
18. [Street Fighter   ](doc/jtsf.txt)

Plus the games supported by the [JTPANG](cores/pang/README.md) and [JTBOWL](cores/bowl/README.md) cores. Refer to those README files for matters specific to those cores.

# Schematics

The KiCAD schematics developed by JOTEGO's team are in the sch folder of each core. Some of them only reproduce one aspect of the board that we needed to double check. A link to PDF versions is available below.

- [JOTEGO's schematics for Exed Exes](https://github.com/jotego/jtbin/tree/master/sch/exed.pdf)
- [JOTEGO's partial schematics for The Speed Rumbler](https://github.com/jotego/jtbin/tree/master/sch/rumble.pdf)
- [JOTEGO's partial schematics for Side Arms](https://github.com/jotego/jtbin/tree/master/sch/sarms.pdf)

### Dependencies

Game              | 6809 | Z80 | 68000 | MCU  | YM2203  | YM2151 | YM2149 | MSM5205 | SN76489AN
------------------|------|-----|-------|------|---------|--------|--------|---------|-----------
1942              |      |  X  |       |      |         |        |   X    |         |
1943              |      |  X  |       |      |   X     |        |   X    |         |
Bionic Commando   |      |  X  |   X   |  X   |         |   X    |        |         |
Black Tiger       |      |  X  |       |  X   |   X     |        |   X    |         |
Commando          |      |  X  |       |      |   X     |        |   X    |         |
Exed Exes         |      |  X  |       |      |         |        |   X    |         |    X
F1-Dream          |      |  X  |   X   |  X   |   X     |        |   X    |         |
Ghosts'n Goblins  |  X   |  X  |       |      |   X     |        |   X    |         |
Gun Smoke         |      |  X  |       |      |   X     |        |   X    |         |
Higemaru          |      |  X  |       |      |         |        |   X    |         |
Legendary Wings   |      |  X  |       |      |   X     |        |   X    |         |
Section Z         |      |  X  |       |      |   X     |        |   X    |         |
Side Arms         |      |  X  |       |      |   X     |        |   X    |         |
Street Fighter    |      |  X  |   X   |  X   |         |   X    |        |   X     |
The Speed Rumbler |  X   |  X  |       |      |   X     |        |   X    |         |
Tiger Road        |      |  X  |   X   |      |   X     |        |   X    |   X     |
Trojan            |      |  X  |       |      |   X     |        |        |   X     |
Vulgus            |      |  X  |       |      |         |        |   X    |         |

Games using 1943 scroll module

* 1943 / Gun Smoke
* Trojan
* Tiger Road / F1 Dream
* Side Arms

Games re-writting the sprites to SDRAM

* The Speed Rumbler
* Tiger Road / F1 Dream
* Bionic Commando

Games using multiple SDRAM banks

* Bionic Commando
* Street Fighter
* The Speed Rumbler

Some modules identify the location of graphic bits, such as horizontal flip, with the help of a LAYOUT parameter. Here are the values:

Layout  |  Game
--------|---------
10      | The Speed Rumbler
11      | Exed Exes
12      | Exed Exes (SCR2)

## Wait States

Bus contention is similar across the different boards.

Game              |   Char Access Ok  |  Scr Access Ok
------------------|-------------------|-----------------
GnG               |  H[2:1]!=3        | H[2:0]<2
1942              |  H[2:1]!=2        | H[2:0]<3
1943, Side Arms   |  After H[2:0]==4  | No SCR RAM
Commando          |  After H[2:0]==4  | Wait until H[0]==0

## YM2203 Clock Divider

These are the settings for the internal clock divider in YM2203 games. Each number refers to a YM22003 chip. This information can be viewed on the *debug_view* bus when compiled with *JTFRAME_DEBUG*.

Game              | Divider   | FM IRQ
------------------|-----------|---------
1943              |  0/0      | No
Black Tiger       |  2/2      | Yes
Commando          |  0/0      | No
F1-Dream          |  2/2      | Yes
Ghosts'n Goblins  |  3/3      | No
Gun Smoke         |  3/3      | No
Legendary Wings   |  3/3      | No
Section Z         |  3/3      | No
Side Arms         |  2/2      | Yes
The Speed Rumbler |  2/2      | Yes
Tiger Road        |  2/2      | Yes
Trojan            |  3/3      | No

Note that 2 is the default divider, so games using it may never set it explicitly.

## Troubleshooting

* If you have in-game problems, please read the text file specific to that core. Sometimes it's just that the games has more buttons than you think.

* F1-Dream and Black Tiger are using an IP for the MCU that does not synthesize correctly at 48MHz because of a setup timing violation. Using the clock enable signal to operate it seems to remove the problem. Ideally, the IP should be edited to increase its frequency performance.

* How to continue the game: many CAPCOM games of this era require to hold the fire button while pressing 1P to continue the game.

## Keyboard

On MiSTer keyboard control is configured through the OSD.

For MiST and MiSTer: games can be controlled with both game pads and keyboard. The keyboard follows the same layout as MAME's default.

    F3      Game reset
    P       Pause (in some games, you can disable the credits screen by pressing 1P)
    1,2     1P, 2P start buttons
    5,6     Left and right coin inputs

    cursors 1P direction
    CTRL    1P button 1
    ALT     1P button 2
    space   1P button 3

    R,F,G,D 2P direction
    Q,S,A   2P buttons 3,2 and 1

    F7      Turn character layer on/off
    F8      Turn second background layer on/off
    F9      Turn first  background layer on/off
    F10     Turn object (sprite) layer on/off

# ROM Generation

Each core in the releases folder continues files for linux and windows to generate the ROM file starting from a MAME set. Follow the instructions of that file. There are also MRA files available in the [JTBIN](https://github.com/jotego(jtbin)). MRA files are the recommended way. Use the MRA-to-ROM converter from Sebdel if your device does not accept MRA files natively.

# SD Card

For MiST copy the file core.rbf to the SD card at the root directory. Copy also the rom you have generated with the name JTGNG.rom. It will get loaded at start. Make sure to have a recent version of MiST/SiDi firmware.

# Extras

You can press F12 to bring the OSD menu up. You can turn off music, or sound effects with it. By default, a screen filter makes the screen look closer to an old tube monitor. If you turn it off you will get sharp pixels. Note that if you switch from sharp to soft pixels you will need a couple of seconds to get your eyes used as the brain initially perceives this as an out of focus image compared to the old one.

# Misc

Original filter for sound (GnG)
- high pass filter with cut-off freq. at 1.6Hz
- low pass filter with cut-off freq. at 32.3kHz

## Modules

The FPGA clone uses the following modules:

JT12:   For YM2203 sound synthesis. From the same author.
JT51:   For YM2151 sound synthesis. From the same author.
JT5205: For MSM5205 ADPCM sound. From the same author.
JTFRAME: A common framework for MiST arcades. From the same author.
MC6809 from Greg Miller
T80: originally from Daniel Wallner, with edits from Alexey Melnikov (Mister)
hybrid_pwm_sd.v copied from FPGAgen source code. Unknown author

Use `git clone --recurse-submodules` in order to get all submodules when you clone the repository.

# Compilation and Directory Structure

Refer to [JTFRAME](https://github.com/jotego/jtframe) for compilation instructions and general information about how the cores are organized.

# HDL Code Structure

The top level module is called jtgng_mist. This is the module that is really dependent on the board. If you want to port jtgng to a different FPGA board you will need to modify this file. Most other files will likely stay the same

The game itself in module jtgng_game. It is written using an arbitrary clock (active on positive edge) and a clock enable signal (switching on the negative edge). From jtgng_game down the hierarchy, everything should be highly portable.

The video output is a 256x256 screen. That is what you get from jtgng_game in a signal format that replicates the original hardware. jtgng_mist instantiates a module called jtgng_vga that converts the image to a standard VGA resolution without losing frame speed.

# Credits

Jose Tejada Gomez. Twitter @topapate
The project is hosted in http://www.github.com/jotego/jt_gng
License: GPL3, you are obligued to publish your code if you use mine

Special thanks to Greg Miller, Bruno Silva and Alexey Melnikov


Thank you all!
```
+--------------------------------------------------------------------------------+
|oooooooooooooooooooooooooooooooooo+++++++++++ooooooooooooooooooooooooooooooooooo|
|ooooooooooooooooooooooooooooooooo+. .    . .+ooooooooooooooooooooooooooooooooooo|
|ooooooooooooooooooooooooooooooooo~         :o++ooooooooooooooooooooooooooooooooo|
|oooooooooooooooooooooooooooo+ooo+.        .++.:oo+oo+oooooo+o+oo+oooooo++ooooooo|
|ooooooooooooooooooooooooo+.......          .. .............................:oooo|
|oooooooooooooooooooooooo+.                                                .+o+oo|
|oooooooooooooooooooooooo:                                                 :o:.+o|
|ooooooooooooooooooooooo+.                                                .++.:oo|
|ooooooooooooooooooooooo:.....           ...........          ....... ....:o~.+oo|
|oooooooooooooooooooooooo+++++~         ~+++:++:++++.         ++++++++++++++.+ooo|
|oooooooooooooooooooooooooo+:~         .++.~:::::::.         .o+.~:::::::::::+ooo|
|oooooooooooooooooooooooooooo:         :o~.+oooooo+.         ++.~oooooooooooooooo|
|ooo~........~oooooooooooooo+.        .++.:ooooooo+         ~o:.+oooooooooooooooo|
|oo:         ~o++ooooooooooo.         +o~.ooooooo+.        .++.~ooooooooooooooooo|
|oo.         :+.:ooooooooo+.         ~o+.+ooooooo:         ~o:.+ooooooooooooooooo|
|oo.         ...~:::::::..          .++.~ooooooo+.        .o+.:oooooooooooooooooo|
|oo~                               ~o+..+ooooooo~         +o~.+oooooooooooooooooo|
|oo+.                           .~+o+..+ooooooo+.        .o+.+ooooooooooooooooooo|
|oooo~.                       .:+o+..:+oooooooo.         +o..oooooooooooooooooooo|
|ooooo+:...              ..~:+++:..:+ooooooooo+         .o+.+oooooooooooooooooooo|
|ooooooo+++::::::::::++++++++~~.~++ooooooooooo+:+:::::+:++.~ooooooooooooooooooooo|
|ooooooooo+++:::::::::~:~~~~:++oooooooooooooooooo+::::~::~.+ooooooooooooooooooooo|
|oooooooooooooo+o+oo++++o+ooooooooooooooooooooooo+o+++o++o+oooooooooooooooooooooo|
+--------------------------------------------------------------------------------+
```
