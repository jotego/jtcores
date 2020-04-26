# JT_GNG FPGA Clone of Early CAPCOM Arcade Games by Jose Tejada (@topapate)

You can show your appreciation through
* Patreon: https://patreon.com/topapate
* Paypal: https://paypal.me/topapate

Yes, you always wanted to have a Ghosts'n Goblins arcade board at home. First you couldn't get it because your parents somehow did not understand you. Then you grow up and your wife doesn't understand you either. Don't worry, MiST(er) is here to the rescue.

What you get with this is an extremely accurate (allegedly 100% accurate) clone of the original hardware. You will notice differences from MAME if you compare. For instance, on Ghosts'n Goblins try resetting it and compare those screens for a start! Original hardware handled sound and graphics in a different way from the emulator. There were delays in CPU bus access and other details that will make the experience different from an emulator.

I hope you will have as much fun with it as I had it while making it!

## Supported Games

In chronological order:

 1. Vulgus           (see doc/jtvulgus.txt)
 2. 1942             (see doc/jt1942.txt)
 3. Commando         (see doc/jtcommando.txt)
 4. Ghosts'n Goblins (see doc/jtgng.txt)
 5. SectionZ         (see doc/jtsectionz.txt)
 6. GunSmoke         (see doc/jtgunsmoke.txt)
 7. 1943             (see doc/jt1943.txt)
 8. Black Tiger      (see doc/jtbtiger.txt)
 9. Tiger Road       (see doc/jttora.txt)
10. F1-Dream         (see doc/jtf1dream.txt)
11. Bionic Commando  (see doc/jtbiocom.txt)

## Troubleshooting

* If you have in-game problems, please read the text file specific to that core. Sometimes it's just that the games has more buttons than you think.

* F1-Dream and Black Tiger are using an IP for the MCU that does not synthesize correctly at 48MHz because of a setup timing violation. Using the clock enable signal to operate it seems to remove the problem. Ideally, the IP should be edited to increase its frequency performance.

* How to continue the game: many CAPCOM games of this era require to hold the fire button while pressing 1P to continue the game.

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

    F7      Turn character layer on/off
    F8      Turn second background layer on/off
    F9      Turn first  background layer on/off
    F10     Turn object (sprite) layer on/off

# ROM Generation

Each core in the releases folder continues files for linux and windows to generate the ROM file starting from a MAME set. Follow the instructions of that file. There are also MRA files available in the rom/mra folder. MRA files are the recommended way. Use the MRA-to-ROM converter from Sebdel if your device does not accept MRA files natively.

# SD Card

For MiST copy the file core.rbf to the SD card at the root directory. Copy also the rom you have generated with the name JTGNG.rom. It will get loaded at start. Make sure to have a recent version of MiST/SiDi firmware.

# Extras

You can press F12 to bring the OSD menu up. You can turn off music, or sound effects with it. By default, a screen filter makes the screen look closer to an old tube monitor. If you turn it off you will get sharp pixels. Note that if you switch from sharp to soft pixels you will need a couple of seconds to get your eyes used as the brain initially perceives this as an out of focus image compared to the old one.

# Misc

Original filter for sound (GnG)
    -high pass filter with cut-off freq. at 1.6Hz
    -low pass filter with cut-off freq. at 32.3kHz

# Project Structure

This work has two separate parts:

1. A verilog model of the original hardware, replicated from original schematics. This is found in the hdl folder. Some test benches are available in the "ver" (for verification) folder. Data sheets of parts used in the original design are located in the "doc" folder. This is interesting to understand how it worked. It can be used to repair broken boards too.

2. A modern clone written in Verilog. It has been made with the MiST board in mind but the game itself (jtgng_game module) is highly portable. All components used aim to be cycle exact -some even sub-cycle exact- so the recreation is the most similar thing to having the original PCB you can get.

## Modules

The FPGA clone uses the following modules:

JT12: For YM2203 sound synthesis. From the same author.
JTFRAME: A common framework for MiST arcades. From the same author.
MC6809 from Greg Miller
T80: originally from Daniel Wallner, with edits from Alexey Melnikov (Mister)
hybrid_pwm_sd.v copied from FPGAgen source code. Unknown author

Use `git clone --recurse-submodules` in order to get all submodules when you clone the repository.

# Compilation

I use linux as my development system. This means that I use many bash scripts, environment variables and symbolic links. I recommend using linux to compile the cores.

## Requisites

* Linux
* Quartus 13 for MiST/SiDi compilation
* Quartus 17 for MiSTer compilation
* Add the path to quartus_sh to your PATH environment variable if JTCORE cannot automatically find it
* PNG library for Python

### Compilation Steps
Go to the root directory of the repository and execute: `source set_prj.sh`

That will create an alias called jtcore to directory modules/jtframe/bin/jtcore. This is a command line utility that will compile the cores. Like

`jtcore gng`

will compile Ghosts'n Goblins for MiST.

`jtcore gng -mr`

will compile it for MiSTer. And -sidi, will compile it for MiST. Support for Xilinx platforms is done by Neurorulez and is done through the GUI. Just check the files inside the cores folder for each game.

Pnce compilation is triggered with jtcore, Quartus qpf and qsf files are created. This files are not part of the repository as they are considered output files, not input.

There is another script called update_cores.sh that will run jtcore over all supported cores in parallel.

# Directory Structure

original/hdl/   replica of original PCB schematics
original/ver/   simulation files for original PCB
modules         files shared by several games and external files
modules/mist    
doc             documents related to original PCB
doc/74          74' series data sheets
rom             script to convert from MAME rom files to the required format
                simulation files expect the rom files here
gng/            MiST board version of Ghosts'n Goblins.
                Latest core version is located in this folder and called core.rbf
gng/hdl         Verilog files of the clone for MiST
gng/doc         documents related to MiST clone or MiST hardware
gng/quartus     project to synthesize the clone
gng/ver         simulation files of MiST clone

1942            MiST board version of 1942 arcade game
1942/hdl        Verilog files of the clone for MiST
1942/zxuno      files for ZX-UNO version
1942/mist       Quartus files for MiST version

1943            MiST board version of 1943 arcade game
1943/hdl        Verilog files of the clone for MiST
1943/mist       Quartus files for MiST version
etc.

# HDL Code Structure

The top level module is called jtgng_mist. This is the module that is really dependent on the board. If you want to port jtgng to a different FPGA board you will need to modify this file. Most other files will likely stay the same

The game itself in module jtgng_game. It is written using an arbitrary clock (active on positive edge) and a clock enable signal (switching on the negative edge). From jtgng_game down the hierarchy, everything should be highly portable.

The video output is a 256x256 screen. That is what you get from jtgng_game in a signal format that replicates the original hardware. jtgng_mist instantiates a module called jtgng_vga that converts the image to a standard VGA resolution without losing frame speed.

# Simulation

# Credits

Jose Tejada Gomez. Twitter @topapate
Project is hosted in http://www.github.com/jotego/jt_gng
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
