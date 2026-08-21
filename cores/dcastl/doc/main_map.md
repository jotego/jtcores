# Main Z80 memory map (jtdcastl_main.v)

Source of truth: `D:\Arcade\AI\aCORES\mrdo\rtl\docastle_main.sv`, whose own
header cites `src/mame/universal/docastle.cpp main_map variants`. The three
profiles below correspond to `PROFILE_CASTLE`, `PROFILE_RUNRUN` and
`PROFILE_SOCCER` (`profile` input, 2'd0/2'd1/2'd2) in `jtdcastl_main.v`.
Address ranges are transcribed unchanged from the mrdo RTL / decoder in
`jtdcastl_main.v`; they were not re-derived from MAME source for this table.

All ranges are qualified by `cpu_macc = ~mreq_n & rfsh_n` (a real memory-space
access, excluding refresh and I/O cycles) except the CRTC register port,
which is I/O space and qualified by `~iorq_n` only.

## PROFILE_CASTLE (profile = 2'd0)

| Address range     | Region                       |
|--------------------|------------------------------|
| 0x0000 - 0x7FFF     | ROM                           |
| 0x8000 - 0x97FF     | Work RAM                     |
| 0x9800 - 0x99FF     | Sprite RAM                    |
| 0xA000 - 0xA7FF     | Communication RAM (comm)      |
| 0xA800 (single)     | Watchdog kick                 |
| 0xB000-0xB3FF, 0xB800-0xBBFF (addr[15:12]==0xB, addr[10]==0) | Video (tile) RAM |
| 0xB400-0xB7FF, 0xBC00-0xBFFF (addr[15:12]==0xB, addr[10]==1) | Color RAM |
| 0xE000 (single)     | Sub-CPU NMI request           |
| n/a                 | ADPCM status/data (not present on this profile) |

## PROFILE_RUNRUN (profile = 2'd1)

| Address range     | Region                       |
|--------------------|------------------------------|
| 0x0000 - 0x1FFF     | ROM (low bank)                |
| 0x2000 - 0x37FF     | Work RAM                     |
| 0x3800 - 0x39FF     | Sprite RAM                    |
| 0x4000 - 0x9FFF     | ROM (high bank)               |
| 0xA000 - 0xA7FF     | Communication RAM (comm)      |
| 0xA800 (single)     | Watchdog kick                 |
| 0xB000 - 0xB3FF     | Video (tile) RAM               |
| 0xB400 - 0xB7FF     | Color RAM                     |
| 0xB800 (single)     | Sub-CPU NMI request           |
| n/a                 | ADPCM status/data (not present on this profile) |

## PROFILE_SOCCER (profile = 2'd2)

| Address range     | Region                       |
|--------------------|------------------------------|
| 0x0000 - 0x3FFF     | ROM (low bank)                |
| 0x4000 - 0x57FF     | Work RAM                     |
| 0x5800 - 0x59FF     | Sprite RAM                    |
| 0x6000 - 0x9FFF     | ROM (high bank)               |
| 0xA000 - 0xA7FF     | Communication RAM (comm)      |
| 0xA800 (single)     | Watchdog kick                 |
| 0xB000-0xB3FF, 0xB800-0xBBFF (addr[15:12]==0xB, addr[10]==0) | Video (tile) RAM |
| 0xB400-0xB7FF, 0xBC00-0xBFFF (addr[15:12]==0xB, addr[10]==1) | Color RAM |
| 0xC000 (single)     | ADPCM status read / data write |
| 0xE000 (single)     | Sub-CPU NMI request           |

## CRTC register port (I/O space, all profiles, qualified by ~iorq_n only)

| I/O address (cpu_addr[7:0]) | Region                        |
|-------------------------------|-------------------------------|
| 0x00                           | CRTC register-index latch     |
| 0x02                           | CRTC register-data latch (commits `crtc_we`) |

## Ambiguity / evidence notes found while transcribing

- The mrdo RTL comment states "All three 0x1800-byte RAM windows are aligned
  to 0x2000, so the low thirteen address bits are the physical RAM index" --
  this is an implementation note about mrdo's own internal work-RAM array
  addressing, not part of the external CPU-visible map, so it is not carried
  into this table.
- For CASTLE and SOCCER, `video_cs`/`color_cs` are decoded purely from
  `cpu_addr[15:12]==4'hb` and `cpu_addr[10]`, independent of bits [11] and
  [9:0] below bit 10. This means the same video/color RAM is also mirrored at
  0xB800-0xBBFF / 0xBC00-0xBFFF (bit 11 set) in both profiles' address space,
  overlapping the CASTLE/SOCCER NMI address 0xE000 only in appearance -- 0xE000
  has address bits [15:12]==0xE, not 0xB, so there is no actual overlap; this
  is called out here only because it was the first thing worth double-checking
  when transcribing the bitwise decode into a range table.
- No address range collisions were found between regions within any one
  profile; every decoded select in `jtdcastl_main.v` is mutually exclusive
  by construction (if/else-if chain, one profile at a time).
