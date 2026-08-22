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

# Bring-up Notes

## SH-2 External Bus Contract

The CPS3 BIOS programs the SH7604 bus control register `BCR2` to `0x00e8`.
With the current `MD_CFG`, this gives the CPU-facing external bus widths below:

| Decode signal | CPU address range       | SH area | CPU bus width | RTL target                    | Current contract/status                                                         |
|:--------------|:------------------------|:--------|:--------------|:------------------------------|:--------------------------------------------------------------------------------|
| `bios_cs`     | `0x00000000-0x0007ffff` | CS0     | 32-bit        | `cpuba0` bank 0               | Full 32-bit path with BIOS decrypt handling.                                    |
| `ram_cs`      | `0x02000000-0x0207ffff` | CS1     | 16-bit        | `cpuba0` bank `0x12`          | 16-bit halfword steering by `A[1]`; covered by `jtcps3_main_ram_adapter`.       |
| `fram_cs`     | `0x03000000-0x030003ff` | CS1     | 16-bit        | FRAM/test NVRAM               | Local byte/halfword handling, test-mode only; not fully proven.                 |
| `sprite_cs`   | `0x04000000-0x0407ffff` | CS2     | 16-bit        | `cpuba0` bank `0x11`          | 16-bit halfword steering by `A[1]`; covered by `jtcps3_main_ram_adapter`.       |
| `cram_cs`     | `0x04080000-0x040bffff` | CS2     | 16-bit        | palette/color RAM             | Uses local 16-bit palette path; still needs focused bus-lane assertions.        |
| `ppu_cs`      | `0x040c0000-0x040cffff` | CS2     | 16-bit        | video/PPU registers           | Local 16-bit register path for writes; readback coverage is partial.            |
| `snd_cs`      | `0x040e0000-0x040effff` | CS2     | 16-bit        | sound block                   | Local sound register/RAM path; still needs focused bus-lane assertions.         |
| `charram_cs`  | `0x04100000-0x041fffff` | CS2     | 16-bit        | character RAM `tiles_wr` lane | 16-bit halfword steering by `A[1]`; covered by `ver/busmux`.                    |
| `gfxflash_cs` | `0x04200000-0x043fffff` | CS2     | 16-bit        | graphics flash window         | Read/autoselect CPU path through banked GFX SDRAM; program/erase writes are acknowledged but not persisted. |
| `input_cs`    | `0x05000000-0x050007ff` | CS2     | 16-bit        | cabinet inputs                | Local readback path; still needs focused bus-lane assertions.                   |
| `dipsw_cs`    | `0x05000a00-0x05000aff` | CS2     | 16-bit        | DIP switch readback           | Returns `0xffffffff`; still needs final device behavior.                        |
| `eeprom_cs`   | `0x05001000-0x05001fff` | CS2     | 16-bit        | EEPROM                        | Missing CPU path; simulation reports an error on access.                        |
| `ssram_cs`    | `0x05040000-0x0504ffff` | CS2     | 16-bit        | SS RAM/map/screen RAM         | Local byte/halfword path exists; still needs focused bus-lane assertions.       |
| `ssreg_cs`    | `0x05050000-0x0505ffff` | CS2     | 16-bit        | SS registers                  | Writes reach video path; reads are currently reported as missing in simulation. |
| `scsi_cs`     | `0x05140000-0x0514ffff` | CS2     | 16-bit        | SCSI/CD interface             | Missing CPU path; simulation reports an error on access.                        |
| `flash1_cs`   | `0x06000000-0x067fffff` | CS3     | 32-bit        | SIMM 1 via `cpuba0`           | Full 32-bit path; no 16-bit steering should be applied.                         |
| `flash2_cs`   | `0x06800000-0x06ffffff` | CS3     | 32-bit        | SIMM 2                        | Missing CPU path; simulation reports an error on access.                        |

The proof target for this table is a simunit assertion for every row. For each
16-bit CPU-visible row, reads must put the selected halfword on `DI[15:0]` and
writes must consume `DO[15:0]` plus `WE_N[1:0]`, with `A[1]` selecting the
upper or lower halfword inside any 32-bit backing store.

## SH-2 Cache

The SH7604 cache block in `modules/jtframe/hdl/cpu/sh7604/CACHE.sv` is required.
It is not redundant with the SDRAM cache lanes described in `cfg/mem.yaml`.

The SH7604 manual describes an integrated cache with:

- 4 KB total size
- 4-way set associativity
- 16-byte lines
- cache control through the CPU-visible CCR and cache address/data spaces

That behavior is architecturally visible to software. The SDRAM-side cache lanes
only help the FPGA memory system meet bandwidth and latency requirements. They
cannot replace the SH7604 cache because they do not provide the CPU-visible
cache control behavior.

## SIMM Data Versus BIOS

For the currently targeted NO-CD sets (`sfiiin` and `redearthn`), the SIMM data
used for graphics and sound is plain. That includes the data consumed by palette
DMA and character DMA.

The BIOS/security-cart side is different:

- the BIOS data stored in SDRAM bank 0 is still encrypted
- the SH-2 must see the decrypted BIOS stream at runtime

So "NO CD" does not mean "fully unencrypted". It only means the game no longer
needs CD-ROM data at runtime.

## Decryption Keys

The BIOS decryption keys are game-specific.

The core does not hard-code them in the SH-2 wrapper. Instead, they are stored
in the MRA header and captured during ROM download:

- `cfg/mame2mra.toml` writes the per-game `key1/key2` bytes and MAME
  `altEncryption` mode into the ROM header
- `jtcps3_game.v` latches those header bytes during download
- `jtcps3_main.v` passes the captured keys and mode into the SH7604 path

This keeps the key selection tied to the downloaded set instead of to a build-time
Verilog constant.

The current BIOS decrypt path also takes into account the raw bank-0 layout used
by `jtutil sdram`: before applying the normal CPS3 32-bit XOR mask, the FPGA
path swaps the bytes inside each 16-bit halfword so the SH-2 sees the same word
stream MAME decrypts internally.

## Default PPU Timing Registers

`jtcps3_vtimer` needs valid timing register values before the SH-2 starts
programming the PPU.

To avoid undefined sync timing during ROM download and early reset, the video
block seeds only the vtimer-related PPU MMR bytes from `ver/sfiiin/ppureg.bin`
at reset:

- `h_sync_width`
- `h_blank_end`
- `h_screen_end`
- `h_total_end`
- `v_sync_end`
- `v_blank_end`
- `v_screen_end`
- `v_total_end`

All other PPU MMR reset values stay at zero. This is only a bring-up default so
simulation starts with sane sync timing before the BIOS writes its own values.

## CPS3_STATS

The scene/object statistics printed by the scan pipeline are optional.

Use the macro `CPS3_STATS` when that information is needed. Without it, the core
skips the extra accounting and console output so normal simulations do not waste
time calculating debug-only scene statistics.

## NOVIDEO

The macro `NOVIDEO` is intended for CPU-focused simulation bring-up.

With `NOVIDEO` enabled, the rendering-heavy video blocks idle internally so
simulation spends less time on scene generation and pixel mixing. The following
 pieces stay active because the SH-2 can observe or depend on them:

- PPU and SS MMR access
- `jtcps3_vtimer` sync/timing generation
- palette DMA
- character DMA

The following blocks are bypassed or blanked:

- sprite-list DMA
- SS rendering
- scene rendering and line-buffer activity
- color mixing and visible pixel output

This is meant to speed up early boot and CPU debugging runs without removing the
video-side state that software reads or writes.

## SH7604 Differences Versus Saturn

The SH7604 block used here was compared against the Saturn implementation and
one CPS3-relevant issue is currently kept local:

- `CACHE.sv`: SH-2 internal `IO_AREA` writes must not be stalled by the external
  write-through path. CPS3 BIOS bring-up relies on timely writes to internal
  control registers.

The older `MSBY.sv` divergence that accepted `SBYCR` at both `0xfffffe90` and
`0xfffffe91` was re-tested during cps3#72. Current cputest coverage and an
`sfiiin` frame-180 smoke pass with the Saturn byte-address-only behavior, so
that divergence is no longer considered CPS3-required.

# Video Timing Notes

There is an inconsistency in the documented CPS3 wide-mode horizontal timing values.

For normal mode, the documented values are internally consistent if the registers are interpreted as end counts on a wrapping horizontal counter:

- `h_total_end = 454` gives 455 counts per line
- `h_blank_end = 111`
- `h_screen_end = 495`

That produces a visible width of 384 pixels:

```text
(454 - 112 + 1) + (495 - 455 + 1) = 343 + 41 = 384
```

Wide mode does not fit the same interpretation:

- `h_total_end = 454`
- `h_blank_end = 118`
- `h_screen_end = 613`

The problem is that `h_screen_end = 613` is outside the 455-count line implied by `h_total_end = 454`. Even if the same wrapped-end arithmetic is applied, the visible width becomes 495 pixels, not the 496 pixels described in the documentation:

```text
(454 - 119 + 1) + (613 - 455 + 1) = 336 + 159 = 495
```

So there are two inconsistencies in wide mode:

- `h_screen_end = 613` is out of range for a 455-count horizontal line
- the documented values add up to 495 visible pixels, while the prose says 496

The same wide-mode values also appear in the local MAME CPS3 driver comments in `/home/jtejada/mame/src/mame/capcom/cps3.cpp`. MAME also notes that horizontal timing stays tied to a fixed base clock while the video DAC rate changes with the pixel divider. That suggests the wide-mode register set mixes a fixed horizontal timing domain with a different effective pixel rate.

Because of this, the current `vtimer` verification only enforces exact geometry for normal mode. For wide mode it only checks that:

- the `/4` and `/8` clock-enable cadence is correct for `pxl_div = 5`
- `lhbl` and `hs` are active and toggle
- the current implementation still does not support wide mode correctly

# Character DMA Timing

The exact character DMA speed of the original CPS3 hardware is unknown. A
plausible reference point is a continuous 16-bit transfer path clocked at
14.42 MHz, because the memories involved had 16-bit data buses. The ideal
time below is therefore only a lower bound: it assumes one 16-bit transfer per
clock and does not include character-data decompression work, table reads,
command fetches, RAM arbitration, flushing, or other pipeline overhead.

The table shows the three large `sfiiin` New York-stage character DMA events
from the fast DMA implementation:

| DMA event | DMA bytes | 16-bit transfers | Ideal lower bound at 14.42 MHz | Ideal frames | Measured waveform time | Measured frames | Effective 16-bit rate |
|-----------|-----------|------------------|--------------------------------|--------------|------------------------|-----------------|-----------------------|
| 1st       | 518,400   | 259,200          | 17.98 ms                       | 1.08         | 24.00 ms               | 1.44            | 10.80 MHz             |
| 2nd       | 791,296   | 395,648          | 27.44 ms                       | 1.65         | 42.34 ms               | 2.54            | 9.34 MHz              |
| 3rd       | 1,234,944 | 617,472          | 42.82 ms                       | 2.57         | 68.86 ms               | 4.13            | 8.97 MHz              |

Frame counts assume 16.67 ms per video frame.

# CPU Cache Size

There is a visible R0 transition from busy to zero around frame 12 during boot up of sfiiin. This was used to assess the effect on speed of different jtframe cache configurations:

| Type  |   Count    |  Size  |  Time   | Total Size kB |
|-------|------------|--------|---------|---------------|
|  C    |  256       |   32   | 171.51  |   8           |
|  D    |  512       |   16   | 165.27  |   8           |
|  E    |  128       |   64   | 161.60  |   8           |
|  F    |  128       |  128   | 160.15  |  16           |
|  J    |  256       |  128   | 160.02  |  32           |
|  G    |  128       |  256   | 159.23  |  32           |
|  K    |   64       |  256   | 159.34  |  16           |
|  H    |  256       |  256   | 158.95  |  64           |
|  I    |  256       |  512   | 158.18  | 128           |

The type column is just a name for the count-size cache lane combination.

# Scope Measurements

PCB measurements for the standard video resolution:


| Item                |  Measurement    |
|---------------------|-----------------|
| Line  period        |  15.7 kHz       |
| Frame period        |  59.6  Hz       |
| H sync width        |   4.72 us       |
| V sync width        | 190.8  us       |

Take into account the limited resolution of these measurements when done visually on the scope. The snapshots are in doc/scope/.