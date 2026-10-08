# SETA X1-001 Register 0

| Game        | Value      | Remarks                            |
|:------------|:-----------|:-----------------------------------|
| arknoid2    | 0001-1010  |                                    |
| calibr50    | 0001-0000  |                                    |
| chukatai    | 0101-1010  | written once at boot               |
| drtoppel    | 0001-1010  |                                    |
| extrmatn    | 0001-1010  |                                    |
| insectx     | 0101-1010  |                                    |
| kabukiz     | 0001-1010  |                                    |
| kageki      | 0001-1010  |                                    |
| tnzs        | 0001-1010  |                                    |

Interpreted meaning:

| Bit    | Use                               |
|:-------|:----------------------------------|
|     7  |                                   |
|     6  | flip (only vflip?)                |
|     5  |                                   |
|     4  | video enable (?)                  |
|     3  | object page enable (?)            |
|     2  |                                   |
|   1:0  | start column in tile map          |

Bit 6 influences where an object with `y=0` lands, because `jtkiwi_obj.vf` is
`{9{flip}} ^ (vdump-1)` and `flip = ~cfg[0][6]`:

| cfg[0] bit 6 | games                        | y=0 matches on | visible?          |
|:-------------|:-----------------------------|:---------------|:------------------|
| 0            | tnzs, kageki, drtoppel, ...  | vdump 241-256  | no, past the bottom |
| 1            | chukatai, insectx            | vdump 1-16     | yes, top two rows   |

`y=0xF8` is the value the games write to park an unused object; it is off screen
under both settings. **kageki** parks at `y=0x00` instead, which is only safe
because it runs with bit 6 clear.

## chukatai: incomplete sprite table init

**chukatai** is the one set that combines bit 6 set with objects left at `y=0`.
Its boot fill covers only 0x17E of the 512 Y slots (`b44-10:$004E`, shared by all
four sets):

```
0048: 21 00 F0     LD   HL,$F000      ; X1-001 sprite Y table
004B: 11 01 F0     LD   DE,$F001
004E: 01 7D 01     LD   BC,$017D      ; 1+0x17D = 0x17E bytes
0051: 36 F8        LD   (HL),$F8
0053: ED B0        LDIR
```

`$F17E-$F1FF` stay at zero, so ~130 objects draw sprite code 0 — a solid tile in
this game's ROM — over screen rows 0 and 1. They also match on every one of those
lines, so each costs a full draw and the per-line object budget (~106 draws) is
spent before the scan reaches any real object: the header text on the top two rows
disappears.

`mame2mra.toml` patches the count byte to `$01FF` so the fill covers the whole
table.

# SETA X1-001 Register 1

The register 1 bits are not well understood. This register is in jtkiwi_gfx.cfg[1] and in MAME x1_001_device.m_spritectrl[1]. These are the values seen in some games

| Game        | Value      | Remarks                            |
|:------------|:-----------|:-----------------------------------|
| arknoid2    | 0010-1010  | title screen, game play            |
| arknoid2    | 0010-1100  | credit inserted                    |
| arknoid2    | 0010-1110  | intro scenes (demo/game start)     |
| calibr50    | 0*10-0000  | always                             |
| drtoppel    | 0010-1001  | always                             |
| extrmatn    | 0*10-1001  | always. bit 6 toggles constantly   |
| insectx     | 0*10-1001  | always. bit 6 toggles constantly   |
| kabukiz     | 0000-1001  | always                             |
| kageki      | 0010-0001  | title screen                       |
| kageki      | 0010-1000  | gameplay                           |
| tnzs        | 0010-0000  | transitions screens, mostly text   |
| tnzs        | 0010-0001  | intro scene                        |
| tnzs        | 0010-1001  | gameplay                           |

Interpreted meaning:

| Bit    | Use                               |
|:-------|:----------------------------------|
|     7  | Unknown, always zero              |
|     6  | Tilemap page                      |
|     5  | Object buffer                     |
|     4  | Unknown, always zero              |
|   3:0  | tilemap color                     |

- The tilemap page is used as the MSB of the tile map VRAM address.
- In **extrmatn**, it is clear that the object VRAM also has a page that needs constant switching or the objects become stall
- The flag in **insectx** has a wrong tile if the object page is not toggled
- **calibr50** shows no objects on the top page, but the behavior of bits 6/5 seems the same as in the other two games
- Using register 0, bit 3 to disable the objects page fixes **calibr50** without affecting the other games

The internal memory, 1kB, is used for the X/Y scroll of each screen column. This information takes 256 byes, but the address use follows a mask with blanks `10****0*00`, so only 5 bits are used. The tilemap page bit is not used here, at least not in MAME.

Applying the tile map page bit (asserted or inverted) to any of the fixed value bits in the column address does not work (tested on **insectx**)