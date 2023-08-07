# JTSIMSON FPGA core Compatible with Konami's The Simpsons hardware

By Jose Tejada (@topapate)

You can show your appreciation through
* [Patreon](https://patreon.com/jotego)
* [Paypal](https://paypal.me/topapate)
* [Github](https://github.com/sponsors/jotego)

Project source code hosted at http://www.github.com/jotego/jtcores
License: GPL3, you are obligued to publish your code if you use mine


Yes, you always wanted to have an arcade board at home. First you couldn't get it because your parents somehow did not understand you. Then you grow up and your wife doesn't understand you either. Don't worry, JT cores are here to the rescue.

I hope you will have as much fun with this project as I had while working on it!

# Game Configuration

This game does not use DIP switches but a small EEPROM to save the configuration. Access to the configuration by pressing F2 on your keyboard or pressing button 1 and coin in the Analogue Pocket. Follow the game menu to alter the configuration from that point on.

# PLD Equations

Derived from Caius original [files](https://wiki.pldarchive.co.uk/index.php?title=The_Simpsons).


**053994** at 11C:

```
/i7 = /AS & /INIT & /A15 & /A14 & /A13 & A12 & A11 & A10 & /W0C1 & W0C0 +
      /AS & /INIT & /A15 & /A14 & /A13 & A12 & A11 & A10 &  W0C1 +
      /AS &         /A15 & /A14 & /A13 & A12 & A11 & A10 &        /W0C0 +
      /AS &  INIT & /A15 & /A14 &  A13 &                   /W0C1 +
      /AS &  INIT & /A15 & /A14 & /A13 &                          /W0C0 +
      /AS &  INIT & /A15 & /A14 & /A13 & A12

# 1C00~1FFFF and if /INIT 7C00~7FFF
/i6     = /AS & /INIT & /A15 &  A14 &  A13 & A12 & A11 & A10 +
          /AS &         /A15 & /A14 & /A13 & A12 & A11 & A10   =>
        =>/AS & ( A[15:10]==7 || (A[15:10]=='h1F && /INIT))

/WORKCS = /AS & INIT & /A15 & A14 & /A13

/OBJCS = /AS & INIT & /A15 & /A14 & A13 & W0C1

/COLOCS = /AS & INIT & /A15 & /A14 & /A13 & /A12 & W0C0

/PROGCS = /AS & INIT & A14 & A13 & BK4 +
       /AS & A15

/BNKCS = /AS & INIT & /A15 & A14 & A13 & /BK4
```

**053995** at 11D:

```
/EEPROM = /AS & //i6 & //i7 & A9 & A8 & A7 & /A6 & /A5 & /A4
/JOYSTK = /AS & //i6 & //i7 & A9 & A8 & A7 & /A6 & /A5 &  A4
/OBJREG = /AS & //i6 & //i7 & A9 & A8 & A7 & /A6 &  A5 & /A4 # A[9:4]==111010
/PCUCS  = /AS & //i6 & //i7 & A9 & A8 & A7 & /A6 &  A5 &  A4
/IOCS   = /AS & //i6 & //i7 & A9 & A8 & A7 &  A6 & /A5 & /A4

/VRAMCS = /AS & //i6 &      /A9  +
          /AS & //i6 &      /A8  +
          /AS & //i6 &      /A7  +
          /AS & //i6 &       A6 & A5 +
          /AS & //i6 &       A6 & A4
          /AS & //i6 &  /i7 +
          /AS &  /i6 & //i7 +
```

# Credits

Special thanks to [Museo Arcade Vintage](https://museoarcadevintage.com/) for lending their Simpsons PCB to us during development.

Thanks to August 2023 Patreon supporters

```
```
