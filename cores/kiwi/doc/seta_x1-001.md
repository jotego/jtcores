# SETA X1-001 Register 0

| Game        | Value      | Remarks                            |
|:------------|:-----------|:-----------------------------------|
| arknoid2    | 0001-1010  |                                    |
| calibr50    | 0001-0000  |                                    |
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