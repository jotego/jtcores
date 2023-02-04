# FPGA Clone of Early Arcade Games by Jose Tejada (aka jotego - @topapate)

You can show your appreciation through
* Patreon: https://patreon.com/jotego
* Paypal: https://paypal.me/topapate
* Github: https://github.com/sponsors/jotego

Yes, you always wanted to have a Ghosts'n Goblins arcade board at home. First you couldn't get it because your parents somehow did not understand you. Then you grow up and your wife doesn't understand you either. Don't worry, MiST(er) is here to the rescue.

What you get with this is an extremely accurate (allegedly 100% accurate) clone of the original hardware. You will notice differences from MAME if you compare. For instance, on Ghosts'n Goblins try resetting it and compare those screens for a start! Original hardware handled sound and graphics in a different way from the emulator. There were delays in CPU bus access and other details that will make the experience different from an emulator.

I hope you will have as much fun with it as I had it while making it!

## Supported Games

In chronological order:

 1. 

# Schematics

The KiCAD schematics developed by JOTEGO's team are in the sch folder of each core. Some of them only reproduce one aspect of the board that we needed to double check. A link to PDF versions is available below.

- [JOTEGO's schematics for CAPCOM Bowling](https://github.com/jotego/jtbin/tree/master/sch/bowl.pdf)


## Keyboard

On MiSTer keyboard control is configured through the OSD.

For MiST and MiSTer: games can be controlled with both game pads and keyboard. The keyboard follows the same layout as MAME's default.

    F2      Test
    F3      Game reset
    P       Pause (press 1p or 2P during pause to hide the credits)
    1,2     1P, 2P start buttons
    5,6     Left and right coin inputs
    9       Service

    cursors 1P direction
    CTRL    1P button 1
    ALT     1P button 2
    space   1P button 3

    R,F,G,D 2P direction
    Q,S,A   2P buttons 3,2 and 1


# ROM Generation

There are MRA files available in the [rom/mra](rom/mra) folder. MRA files are the recommended way to boot the core in MiSTerFPGA. Use the [MRA-to-ROM converter](https://github.com/sebdel/mra-tools-c/) from Sebdel if your device does not accept MRA files natively.

# Binary Files

MiSTerFPGA, MiST, SiDi, NeptUNO and MC+/2 platforms are supported. Look for your platform binary files in [JTBIN](https://github.com/jotego). For MiSTerFPGA, the recommended way to get the core binary files is the [update_all](https://github.com/theypsilon/Update_All_MiSTer) script.

# Compilation

This project uses the [JTFRAME](https://github.com/jotego/JTFRAME) framework. Please refer to it.

# Special thanks to Patreon subscribers

```
members
```