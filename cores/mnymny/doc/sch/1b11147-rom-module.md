# 1B11147 Z80µP MODULE MEMORY (ROM board) digest

2 sheets, P83-001/M2, 17.5.1983. Connectors: CN1 (to I/O board CN4: Z80 bus),
CN2 (to video board: AF3..AF12 + Σ0..Σ2 in, DF0..DF23 out), CN3 (to audio board
CNA: both 6802 buses).

## Sheet 1/2 — Z80 program ROMs, protection, bg ROMs

- Main CPU ROMs: positions 2, 3, 4, 10, 11 — each "2732 or 2764", addressed
  AB0..AB10 (+AB11 via jumper 1/2/3 per socket, +A15/ABx pin2/23 straps),
  selected by /CS2 /CS3 /CS4 /CS5 /CS6 from CN1 (27K pullups R3/R4/R6/R10/R11).
  Data -> D0..D7 (direct Z80 data bus). With 2764s fitted: 5 sockets, but MAME
  monymony has 6 ROMs (cpu1..cpu6 at 1A..2C on ROM board naming 1A/1B/1C/1D/2A/2C) —
  the 6th (cpu1.1a) is the socket 1A on the *I/O board* (this module's numbering
  2..11 vs MAME's PCB locations differ; MAME jackrabt2 set lists "1B11147 ROM PCB").
  Positions here are module-silk numbers, not grid refs. 5 module ROMs + 1 on I/O
  board(1A) = 6 program ROMs -> matches.
- R1 27K pulls up /RFSH, R2 27K pulls up A14 (PAL OE-term inputs).
- Position 1 ("1", 20-pin, bottom-left): the PAL16L8 protection device (MAME:
  "protection device at 1A on the ROM board"). Inputs AB1/AB2/AB9/AB10/AB11 (pins
  1..5), D0..D7? no — pins 6/7/8 = AB12/AB13/A14, /RDB /WRB /RFSH (2/6/8),
  DBB3..DBB7 (16..12? shown right side 16/17/18/19/12) — it sits on the *buffered*
  data bus high bits DBB3..7 driving them when addressed (prot1_r 6400-6407 reads
  D4..D7, prot2_r 6C00-6C07): matches MAME "sits on bits 4-7 of the data bus".
  Exact pin/eqn unknown (NO_DUMP); responses hardcoded in MAME prot1_r/prot2_r.
- Background ROM expansion: B3 (pos 5), B2 (pos 6), B1 (pos 12) 24/28-pin sockets,
  address AF3..AF12 + Σ0..Σ2 (13 bits = 8K) from CN2, 10K pullups AR1..AR5,
  outputs DF0..DF23 -> CN2 (24-bit pixel data). GNDV grounds. These mirror the
  three on-video-board sockets 4A/4C/4E (B3/B2/B1): the graphics can be fitted
  either on the video board (2732=4K tiles) or here (2764=8K, monymony uses 8K×3).
  CN2 pin map: DF0..7 24/27/3/20/4/22/2/1(?), DF8..15 33/32/35/28/26/31/29/30,
  DF16..23 40/39/37/25/23/21/19/17.

## Sheet 2/2 — audio CPU ROMs

- Melody CPU ROMs: positions 7, 8 — "2732 or 2764 or 27128", address AD0..AD15
  from CN3 (melody 6802 bus), selects /CS0A (7) and /CS1A (8), data D0..D7
  (CN3 6..20 even pins). 27K pullups R7/R8. Jumper pads 17/18/19 (7) and
  21/20/22 (8) for A11/A12/VPP straps.
  MAME monymony melodycpu: snd13.2g 8K @8000 + snd9.1i 8K @C000 -> two 2764s. ✓
- Speech/effects CPU ROMs: positions 9, 13 — "2764 or 27128" (9) and
  "2732 or 2764 or 27128" (13), address A0..A13 (audiocpu bus, CN3 28..45 even),
  selects /CS5A (9), /CS4A (13), straps 29/30/31 (13).
  MAME audiocpu: snd8.1h + snd7.1g (2×4K split loading) -> 2732s. ✓
- CN3 also carries /CS0A /CS1A /CS4A /CS5A (pins 3/4/50/49) and DB0..DB7
  (27..41 odd = audiocpu data).

## MRA/core implications

- ROM regions map cleanly: maincpu (6 ROMs, split-loaded 0000-5FFF / 8000-DFFF per
  ROM_CONTINUE), gfx1 3×8K (DF planes 0/1/2 = B1/B2/B3 order to confirm against
  MAME load order bg1.2d/bg2.1f/bg3.1e), melodycpu 2×8K, audiocpu 2×4K split,
  proms 2×512×4 (palette, video board 9F/9G), plus undumped: PAL16L8 (protection,
  emulate as prot1_r/prot2_r constants), 2×82S100 (object PLAs, model behaviourally).
