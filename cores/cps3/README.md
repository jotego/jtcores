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
