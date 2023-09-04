# Konami 053251

This chip is a video layer priority encoder.

It has inputs for 5 layers:
 * 0, 1 and 2: 5 palette bits + 4 color bits
 * 3 and 4: 4 palette bits + 4 color bits
 
The output is a 11-bit palette index:
```
B: Base, P: Palette #, C: Color
         A9876543210
For CI0: BBPPPPPCCCC    BB: Reg9[1:0]
For CI1: BBPPPPPCCCC    BB: Reg9[3:2]
For CI2: BBPPPPPCCCC    BB: Reg9[5:4]
For CI3: BBBPPPPCCCC    BB: Reg10[2:0]
For CI4: BBBPPPPCCCC    BB: Reg10[5:3]
```

# Registers

* Reg 0: Layer 0 priority (when enabled, see Reg 12)
* Reg 1: Layer 1 priority (when enabled, see Reg 12)
* Reg 2: Layer 2 priority (when enabled, see Reg 12)
* Reg 3: Layer 3 priority
* Reg 4: Layer 4 priority
* Reg 5: Bright priority threshold. When the winning layer's priority is equal or above this value, the BRIT output is set.
* Reg 6: Shadow priority when SDI inputs == 01
* Reg 7: Shadow priority when SDI inputs == 10
* Reg 8: Shadow priority when SDI inputs == 11

When SDI inputs == 0, shadow priority is set to lowest (111111)

* Reg 11:
  * D0 low: Layer 0 transparency is color 0 of any palette
  * D0 high: Layer 0 transparency is color 0 of palettes x0000
  * D1 low: Layer 1 transparency is color 0 of any palette
  * D1 high: Layer 1 transparency is color 0 of palettes x0000
  * D2 low: Layer 2 transparency is color 0 of any palette
  * D2 high: Layer 2 transparency is color 0 of palettes x0000
  * D3 low: Layer 3 transparency is color 0 of any palette
  * D3 high: Layer 3 transparency is color 0 of palette 0
  * D4 low: Layer 4 transparency is color 0 of any palette
  * D4 high: Layer 4 transparency is color 0 of palette 0
  * D5: Swap Layers 0 and 1 ?

* Reg 12:
  * D0 low: Layer 0 priority comes from PR0x inputs
  * D0 high: Layer 0 priority comes from Reg 0
  * D1 low: Layer 1 priority comes from PR1x inputs
  * D1 high: Layer 1 priority comes from Reg 1
  * D2 low: Layer 2 priority comes from PR2x inputs
  * D2 high: Layer 2 priority comes from Reg 2

# Schematic

The schematic was traced from the chip's silicon and should represent exactly how it is internally constructed. The svg can be overlaid on the die picture (not provided, very large and ugly file).

Thanks to O. Galibert for the help.

![Konami 053251 internal routing](routing.png)

# Games

According to MAME, it is used in the following Konami games:
* Asterix
* Bells & Whistles
* Bucky O'Hare
* Cowboys of Moo Mesa
* Dragon Ball Z 2
* Escape Kids
* G.I. Joe, Over Drive
* Golfing Greats
* Lightning Fighters
* Parodius
* Premier Soccer
* Punk Shot
* Surprise Attack
* The Simpsons
* TMNT 2
* Vendetta
* X-Men
* Xexex
