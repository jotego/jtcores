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

Some of the MRA files provided may not work as there is some variation in Bubble Bobble bootleg hardware which is not implemented. Official Tokio MRA file will not work because the MCU hardware is not yet implemented in the core. Only the bootleg MRA for Tokio works.

Note for developers: Tokio hangs up after a life is lost if the RBF is compiled without sound.

## Documentation

The cores have been developed by combining information in the MAME drivers with PLD dumps from the PLD archive and with full schematic extraction from the PCBs.

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
Ben Toman             Human0Target        Nico Stamp
Bob G                 hyp36rmax           Paweł Mandes
Brent Fraser W.       Jesse Clark         Richard Eng
Carrboroman           Johan Smolinski     Richard Murillo
Clinton Cronin        Justin D'Arcangelo  SNIPERMikeUK
Daniel Estreito       Keith Duncan        Spank Minister
Darren Wootton        KnC                 Stephen Goldberg
David Fleetwood       Lee Osborne         Steven Yedwab
David Jones           Luc JOLY            taal.M
DrMnike               Magnus Kvevlander   Thomas Irwin
Eric J Faulkes        Matthew Woodford    Trifle
Fabio Michelin        M. Penkert-Hennig   VickiViperZabel
XC-3730C              Michael Deshaies    Victor Bly
```
