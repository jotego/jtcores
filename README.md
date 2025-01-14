# JTCORES FPGA Arcade Hardware by Jose Tejada (@topapate)

You can show your appreciation through
* [Patreon](https://patreon.com/jotego)
* [Paypal](https://paypal.me/topapate)
* [Github](https://github.com/sponsors/jotego)

Yes, you always wanted to have an arcade board at home. First you couldn't get it because your parents somehow did not understand you. Then you grow up and your wife doesn't understand you either. Don't worry, JT cores are here to the rescue.

I hope you will have as much fun with this project as I had while working on it!

## Wanna play?

You can find the list of supported games in [jtbin/game_list](https://github.com/jotego/jtbin/blob/master/game_list.md). That list is actually an output of the source code of this repository and gets updated every release. There are 1050+ supported titles at the moment ( January 2025 ).

The compiled versions for some FPGA platforms are in [JTBIN](https://github.com/jotego/jtbin). Most cores are released early for [patrons](https://patreon.com/jotego) so check it out too. [JTFRAME](https://github.com/jotego/jtframe) supports more FPGA platforms than the ones publised in JTBIN. You are welcome to compile the cores for the other platforms. Distribution of the core binary files together with copyrighted ROM files is not permitted.

# Compilation - JTFRAME

Refer to [JTFRAME](modules/jtframe/README.md) for compilation instructions and general information about how the cores are organized.

Master branch health:
[![Compile all MiSTer cores](https://github.com/jotego/jtcores/actions/workflows/compile_mister.yaml/badge.svg)](https://github.com/jotego/jtcores/actions/workflows/compile_mister.yaml)
[![Verilator linter](https://github.com/jotego/jtcores/actions/workflows/linter.yaml/badge.svg)](https://github.com/jotego/jtcores/actions/workflows/linter.yaml)
[![Unit tests](https://github.com/jotego/jtcores/actions/workflows/simunit.yaml/badge.svg)](https://github.com/jotego/jtcores/actions/workflows/simunit.yaml)

# Schematics

Some core have KiCAD schematics for the arcade PCB. This is part of the core research effort and it is important on its own. The schematics folders are called *sch* and can be found in some core folders.

All schematics use the same set of symbol components from [JTKICAD](modules/jtkicad/README.md)

## Troubleshooting

* If you have in-game problems, please read the text file specific to that core. Sometimes it's just that the games has more buttons than you think
* Continue the game: some early arcade games require you to hold the fire button while pressing 1P to continue

## Keyboard

For MiST and MiSTer: games can be controlled with both game pads and keyboard. The keyboard follows the same layout as MAME's default.

    F2      Service mode
    F3      Game reset
    T       Tilt
    P       Pause (in some games, you can disable the credits screen by pressing 1P)
    1,2,3,4 1P..4O start buttons
    5,6     Left and right coin inputs
    9       Service

    cursors 1P direction
    CTRL    1P button 1
    ALT     1P button 2
    space   1P button 3

    R,F,G,D 2P direction
    Q,S,A   2P buttons 3,2 and 1

# Credits

Jose Tejada Gomez. Twitter @topapate
The project is hosted in http://www.github.com/jotego/jt_gng
License: GPL3, you are obligued to publish your code if you use mine


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
