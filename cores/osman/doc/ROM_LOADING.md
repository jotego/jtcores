# Sprite ROM loading

The MRA must first assemble MAME's byte-addressed ROM region. Only then does
`jtosman_game` rotate the region's half bit to combine the two 16-bit plane
pairs into each 32-bit sprite fetch. These are separate operations.

Chain Reaction uses four ROM_LOAD16_BYTE files in MAME's simpl156.cpp:

| ROM pair | Region base | Byte lanes |
| --- | ---: | --- |
| u3 / u4 | 0x000000 | even / odd |
| u5 / u6 | 0x100000 | even / odd |

The generic sequential sprite rule concatenated u3,u4,u5,u6. That corrupted
1,686,138 of the 2,097,152 region bytes and reproduced the garbled hardware
sprites in scene replay. `cfg/mame2mra.toml` now gives `chainrec` a specific
`width=16, No_offset=false` rule. It generates two interleave groups with maps
`01` and `10`, preserving MAME's byte lanes and offsets.

With this MRA, every byte of the raw 2MB sprite region matches MAME. Every byte
of the FPGA's downloaded 32-bit plane bank also matches an independent assembly
of the four physical ROM files. The existing half-bit19 rotation and sprite
`pswap` are correct and remain unchanged. Other sets retain their existing rules.

Regenerate the Chain Reaction MRA with `jtframe mra osman --setname chainrec`
using the project's normal environment/ROM path. On MiSTer, replace its MRA and
reload the game so the corrected stream is downloaded. This sprite interleave
fix does not require a new RBF. The updated MRA is also supplied in the standalone
Deco156Simple repository's prerelease folder.

Validation: 15 normal scene dumps/replays, frames 300..4500 by 300. Title frame 900
improved from 40,559 to 85 differing pixels; tutorial frame3600 from 30,550 to 111.
After correction all residual mismatches are at the first screen column (X=0),
also present before the interleave fix in the background-only scene600. No
image shifts, cropping or masks were used; the remaining edge error stays in
sim_results/diff/. See [SCENE_REPLAY.md](SCENE_REPLAY.md) for the restore format.
