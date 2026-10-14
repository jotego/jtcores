# ROM loading

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

## Heavy Smash music ROM addressing

Heavy Smash's `init_hvysmsh()` calls `descramble_sound("oki2")` in
`doc/hvysmsh.cpp`. This is the same permutation as `init_simpl156`: physical
ROM address bit 0 becomes logical bit 20, while bits 20..1 become bits 19..0.
The MRA loads the original `mbg-04.11k` bytes, so the FPGA must invert that
permutation on reads. With `A = {oki2_bank[2:0], oki2_a[17:0]}`, the physical
SDRAM byte address is `{A[19:0], A[20]}` for Heavy Smash as well as the other games.

The former Heavy Smash-only `musraw` bypass was incorrect: it corrupted sample
table reads as well as ADPCM data. It is removed from `jtosman_snd` and its caller.
The MRA payload, EEPROM bank bits and the 1 MHz SFX / 2 MHz music clocks are correct.
This fix requires rebuilding the RBF; no MRA regeneration is needed.

Validation used native MAME 0.288's initialized music region and the actual
2 MB physical ROM, verified against MAME's declared SHA1. Every MRA music byte
matches the physical ROM. The old bypass gives 2,054,430 differing bytes versus
MAME; the corrected HDL gives zero across all 2,097,152 bytes and eight banks.
The real jt6295 control/ROM state machines also read matching sample start/end
headers in each bank, and the two SFX banks retain their original addressing.
This verifies the addressing defect; the rebuilt core still needs a hardware
music check.
