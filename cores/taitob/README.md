# JTTAITOB — Taito B System FPGA core

JTCORES implementation of the **Taito B System** arcade board (1988–1991).

## Target

**Phase A** — first target: **Rastan Saga 2 / Nastar / Nastar Warrior**
(MAME `rastsag2` / `nastar` / `nastarw`, ROM prefix `b81`, 1988).

Future phases would cover the YM2610 family on the same bitstream:
Ashura Blaster, Crime City, Rambo 3, Silent Dragon, Sel Feena, Ryujin,
Tetris (B-System conversion). The YM2203-based outliers (Violence Fight,
Hit the Ice, Master of Weapon) would need a separate bitstream.

## Hardware

PCB: `K1100419A / J1100178A`. Two crystals + a third for video:

| Block             | Chip            | Clock                |
|-------------------|-----------------|----------------------|
| Main CPU          | Motorola 68000  | 12 MHz (24 / 2)      |
| Sound CPU         | Zilog Z80       | 4 MHz (16 / 4)       |
| FM + ADPCM        | Yamaha YM2610   | 8 MHz (16 / 2)       |
| Sound comms       | TC0140SYT       | bus-paced            |
| I/O               | TC0220IOC       | bus-paced            |
| Video             | TC0180VCU       | 27.164 / 4 ≈ 6.79 MHz|
| Palette DAC       | TC0260DAR       | passive              |

## State (bootstrap commit)

- [x] Directory scaffold + cfg files
- [x] CPU spine (68000 + DTACK + autovector IACK)
- [x] BRAM RAMs (work / palette / VRAM / sprite-scroll / VCU ctrl regs)
- [x] Sound subsystem (Z80 + YM2610 + TC0140SYT, all GPLv3 ports)
- [x] TC0220IOC stub (DIPs + cabinet inputs + coin latch)
- [x] TC0260DAR (passive palette DAC → RGB)
- [x] Video timing (320×224 @ 60 Hz)
- [x] **TC0180VCU stub** — palette viewer shows whatever the 68k writes
      to palette, no tile/sprite rendering yet
- [ ] TC0180VCU real RTL — the major remaining work item
- [ ] IRQ 2 (VCU intl) — currently only IRQ 4 (vblank) is wired
- [ ] ADPCM-B SDRAM bus — voice samples currently silent
- [ ] MAME ground-truth traces (next step per AGENTS.md §0.5)
- [ ] FPGA sim diff vs MAME

## Provenance

The CPU + sound + TC0140SYT subsystems are ports from
[cores/superman/](../superman/) (Taito X System) — same silicon for
68k/Z80/YM2610/SYT, just a clock change on the 68k (8 MHz → 12 MHz).
The TC0140SYT module (`jttaitob_syt.v`) is a verbatim copy of
`jtsuperman_syt.v` with attribution updated.

The TC0180VCU is unique to the Taito B System. No reference
implementation exists in the wider open-source ecosystem (the
Arcade-TaitoF2_MiSTer and Arcade-Darius2NinjaWarriors_MiSTer repos
implement F2 / Z System chips but neither covers the VCU). It will be
built from MAME's [tc0180vcu.cpp](doc/tc0180vcu.cpp) as the only spec.
