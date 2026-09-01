# Supported Games

| setname     | Size (kB) | game name                                                                 | SIMM modules     | SIMM size (MB)                   |
|:------------|----------:|:--------------------------------------------------------------------------|:-----------------|:---------------------------------|
| jojoban     |     66048 | JoJo no Kimyou na Bouken: Mirai e no Isan (Japan 991015, NO CD)           | 1, 2, 3, 4, 5    | 1:8, 2:8, 3:16, 4:16, 5:16       |
| jojobaner1  |     66048 | JoJo's Bizarre Adventure (Europe 990927, NO CD)                           | 1, 2, 3, 4, 5    | 1:8, 2:8, 3:16, 4:16, 5:16       |
| jojobaner2  |     66048 | JoJo's Bizarre Adventure (Europe 990913, NO CD)                           | 1, 2, 3, 4, 5    | 1:8, 2:8, 3:16, 4:16, 5:16       |
| jojobanr1   |     66048 | JoJo no Kimyou na Bouken: Mirai e no Isan (Japan 990927, NO CD)           | 1, 2, 3, 4, 5    | 1:8, 2:8, 3:16, 4:16, 5:16       |
| jojobanr2   |     66048 | JoJo no Kimyou na Bouken: Mirai e no Isan (Japan 990913, NO CD)           | 1, 2, 3, 4, 5    | 1:8, 2:8, 3:16, 4:16, 5:16       |
| jojon       |     53760 | JoJo's Venture (Asia 990128, NO CD)                                       | 1, 2, 3, 4, 5    | 1:8, 2:8, 3:16, 4:16, 5:4        |
| jojonr1     |     53760 | JoJo's Venture (Asia 990108, NO CD)                                       | 1, 2, 3, 4, 5    | 1:8, 2:8, 3:16, 4:16, 5:4        |
| jojonr2     |     53760 | JoJo's Venture (Asia 981202, NO CD)                                       | 1, 2, 3, 4, 5    | 1:8, 2:8, 3:16, 4:16, 5:4        |
| redearthn   |     45568 | Red Earth (Asia 961121, NO CD)                                            | 1, 3, 4, 5       | 1:8,      3:16, 4:16, 5:4        |
| redearthnr1 |     45568 | Red Earth (Asia 961023, NO CD)                                            | 1, 3, 4, 5       | 1:8,      3:16, 4:16, 5:4        |
| sfiii2n     |     66048 | Street Fighter III 2nd Impact: Giant Attack (Asia 970930, NO CD)          | 1, 2, 3, 4, 5    | 1:8, 2:8, 3:16, 4:16, 5:16       |
| sfiii3n     |     82432 | Street Fighter III 3rd Strike: Fight for the Future (Japan 990608, NO CD) | 1, 2, 3, 4, 5, 6 | 1:8, 2:8, 3:16, 4:16, 5:16, 6:16 |
| sfiii3na    |     82432 | Street Fighter III 3rd Strike: Fight for the Future (Asia 990608, NO CD)  | 1, 2, 3, 4, 5, 6 | 1:8, 2:8, 3:16, 4:16, 5:16, 6:16 |
| sfiii3nar1  |     82432 | Street Fighter III 3rd Strike: Fight for the Future (Asia 990512, NO CD)  | 1, 2, 3, 4, 5, 6 | 1:8, 2:8, 3:16, 4:16, 5:16, 6:16 |
| sfiii3nr1   |     82432 | Street Fighter III 3rd Strike: Fight for the Future (Japan 990512, NO CD) | 1, 2, 3, 4, 5, 6 | 1:8, 2:8, 3:16, 4:16, 5:16, 6:16 |
| sfiiin      |     45568 | Street Fighter III: New Generation (Asia 970204, NO CD, BIOS set 1)       | 1, 3, 4, 5       | 1:8,      3:16, 4:16, 5:4        |
| sfiiina     |     45568 | Street Fighter III: New Generation (Asia 970204, NO CD, BIOS set 2)       | 1, 3, 4, 5       | 1:8,      3:16, 4:16, 5:4        |

# FPGA BRAM Sizes

FPGA systems with less than 64MB of SDRAM cannot hold a game in memory, so they cannot support this core.

| FPGA Platform   |  Size (bits)     | RAM Blocks  | SDRAM (MB) |
|:---------------:|-----------------:|------------:|:----------:|
|  MiSTer         |   5,662,720      |  553        |   128      |
|  Sidi 128       |   3,981,312      |             |   128      |
|  Pocket         |   3,153,920      |  308        |    32      |
|  MiST/SiDi      |                  |             |    32      |

# Initial Games

The game sfiiin and redearthn are selected for the first core version because they fit in a single 64MB SDRAM module. This makes the first design a bit simpler.

| setname     | Size (kB) | game name                                                                 | SIMM modules     | SIMM size (MB)                   |
|:------------|----------:|:--------------------------------------------------------------------------|:-----------------|:---------------------------------|
| redearthn   |     45568 | Red Earth (Asia 961121, NO CD)                                            | 1, 3, 4, 5       | 1:8, 3:16, 4:16, 5:4             |
| sfiiin      |     45568 | Street Fighter III: New Generation (Asia 970204, NO CD, BIOS set 1)       | 1, 3, 4, 5       | 1:8, 3:16, 4:16, 5:4             |

The SIMM modules are mapped to the SDRAM banks as:

| SIMM |  SDRAM bank | SIMM size |
|:-----|:------------|:----------|
| 1    | 0           |  8        |
| 3    | 1           | 16        |
| 4    | 2           | 16        |
| 5    | 3           |  4        |

## Scene simulations

`dump.bin` format:

- Its first 128 bytes are the normal EEPROM IOCTL block
- The generated splitter copies every remaining byte to `rest.bin`, and CPS3's `rest2bin.sh` splits it into the following payload:

| Offset | Size | Content |
| ---: | ---: | --- |
| `0x000000` | `0x000080` | EEPROM compatibility prefix |
| `0x000080` | `0x002000` | flattened scene list BRAM |
| `0x002080` | `0x040000` | palette BRAM |
| `0x042080` | `0x004000` | SS character BRAM |
| `0x046080` | `0x002000` | SS tilemap BRAM |
| `0x048080` | `0x002000` | SS line-scroll BRAM |
| `0x04a080` | `0x080000` | sprite/tilemap RAM SDRAM overlay |
| `0x0ca080` | `0x800000` | character/tile RAM SDRAM overlay |
| `0x8ca080` | `0x0000b0` | PPU MMR bytes |
| `0x8ca130` | `0x000016` | SS MMR bytes |
| `0x8ca146` | `0x000002` | flattened scene entry count |

The file must be exactly `0x8ca148` bytes. `ver/rest2bin.sh` rejects other
sizes, splits the CPS3 payload, and invokes `jtutil sdram --sim` to apply the
two SDRAM overlays. The CPU and sound are disabled by the standard `jtsim -s`
macros; `SIMSCENE` restores the flattened scene entry count without running
sprite DMA.