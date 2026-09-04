# Open video issues (attract/demo, compared against original hardware video)

Build state these notes refer to: scrx=16, HLOOP=360, col_nx=+1 in
jtmnymny_scroll.v (since 2026-09-04 the shim owns heff/vsum directly and
instantiates jtframe_tilemap without jtframe_scroll - see issue 3); no
sprite row inversion in jtmnymny_obj.v. Title screen
layout, colours and the in-ROM crosshatch (9/7 px margins, 30 strips) are
VERIFIED against hw video in this configuration. Axis conventions used below:
raw hdump = the 256-px scan axis (vertical in the rotated mp4/PNG view, PNG
row 0 = first-scanned strip); raw vdump = the 224-px axis (horizontal in the
rotated view; text reads along it).

## 1. Sprites flipped horizontally (rotated-screen horizontal)

- FIXED (2026-09-04): not a flip at all - the pixel ORDER WITHIN EACH 8-PIXEL
  ROM WORD was reversed, halves in correct order (pixel-mapped against a
  same-state MAME run: each 8px half of each sprite internally mirrored
  along the buffer axis). Root cause: the SDRAM words pack the leftmost
  pixel in the MSB (jtframe_tilemap convention, proven by the verified
  tiles), while jtframe_draw expects it in the LSB ("leftmost pixel in
  LSB"). Same ROM feeds both paths, so jtmnymny_obj.v now bit-reverses each
  plane byte into u_draw (dr_data). VERIFIED: player sprite at frame 877 is
  structurally pixel-identical to MAME (30/30 rows, same bbox). The axis
  description below ("mirrored along raw vdump") was a misattribution.

- Symptom: every sprite graphic is mirrored along the rotated-horizontal
  axis; positions look plausible. Tilemap on the same axis is correct, so
  global axes are fine - the sprite path specifically mirrors.
- Rotated-horizontal = raw vdump = the sprite ROW axis (ysub / sy).
- Implementation (jtmnymny_obj.v): sy = 242 - byte0 (MAME formula),
  ydiff = vrender - sy, ysub = ydiff[3:0], vflip = bo1[7]^flip,
  hflip = bo1[6]^flip; jtframe_draw applies ysub^{4{vflip}} internally;
  ROM address remap {code, Y3, H, Y2:0} from objdraw's {code, H, Y[3:0]}
  (layout cross-checked against jtdd usage; the isolated bit order was
  verified when tiles were brought up).
- Tried and reverted: global ysub inversion (~ydiff). User check: still
  flipped, and sprites missing - not the fix, or entangled with issue 2.
- MAME sprite table (driver comment): off0 = y source (242-y), off1 =
  {flipy, flipx, code[5:0]}, off2 = {code[7:6], ?, color[2:0]}, off3 = x
  (sx = ram[3]+1); offsets 1 and 2 swap for the spriteram2 sections
  (implemented via `sec1`).
- Not yet ruled out: hflip/vflip attribute-to-axis assignment swapped
  (bit6/bit7 roles vs OUR axes); sx placement mirrored (240-sx style) which
  would also interact with issue 2; jtframe_objdraw `flip` input semantics
  vs this board's separate VCMA/HCMA flips.
- Schematic path: object row select goes through the sigma adders
  (line + y sums, sheet 2) and the LS86 XOR banks 7F/8F/8J/7J on the
  line-buffer addresses; sequencing from dumped 6J/6K (doc/pld/equations.md).
  The exact row order and flip conventions are derivable - see the
  schematic-exact engine handoff in TODO.md.

## 2. Sprites in part of the screen invisible

- FIXED (2026-09-04): jtframe_objdraw HFIX=1 (default) breaks with our
  vtimer because visible hdump starts exactly at the 383->0 wrap: the hdfix
  readout counter keeps counting past the wrap (384, 385...) and only
  resyncs via hdump>hdfix once hdump reaches ~129, so the line buffer
  readout for screen x 0..~129 addressed the empty 384..511 region -
  sprites never appeared in the first half of the scan axis ("top half"),
  while x>=130 rendered at the exact correct position ("positions look
  plausible"). Fix: HFIX(0) - hdfix=hdump combinationally, correct across
  the whole line (the scontra case HFIX solves cannot happen here since
  hdump never wraps mid-visible). VERIFIED vs same-state MAME run: frame
  877 shows all 5 sprites (was 2), full-screen coverage, bbox pixel-exact.

- Symptom: sprites in one region of the rotated screen never appear
  (described as "top half" in one session, "right part" in another - map the
  region precisely on the next pass before changing anything).
- RULED OUT: scanner line-time overrun. A counter on (hs rise && scanner
  busy) showed zero overruns across 1210 demo frames.
- Prime suspect: jtframe_objdraw parameter mismatch with our vtimer.
  jtmnymny_obj.v instantiates it with defaults except CW/PW/LATCH; check
  HJUMP (default expects Konami-style jumping hdump; ours is linear 0..383)
  and the internal buffer addressing/flip. jtdd sets HJUMP(1) explicitly and
  passes xpos-HOFFSET; we pass raw sx = ram[3]+1 with no offset.
- MAME hides sprites with sx==1 (x byte 0); implemented as a skip.
- If sx needs mirroring (issue 1 family), the same error maps a sub-range of
  sprites outside the buffer window - issues 1 and 2 may share a root cause.

## 3. Wrong scrolling columns (pairing off by one strip)

- Symptom: the per-column scroll values land on the wrong columns: a border
  strip that must be static scrolls with wrap, and an edge gamefield strip
  stays static. Content does not move position on screen: it scrolls
  in-place within the wrong strip.
- Experiments (all judged against hw video by the user):
  - col_nx +1 -> +2: BOTH artifacts moved one strip, nothing fixed.
  - scrx 16 -> 0 (with HLOOP 368): "entirely broken, same issue".
  So pure pairing shifts translate the symptom; scrx changes shift heff and
  therefore window AND pairing together. scrx=16 is required for the
  verified window alignment (crosshatch + CREDIT line) and stays.
- Where the pairing lives (jtmnymny_scroll.v): the shim reads the column
  scroll at phases 5-6 of each 8-px group (attr addr {col_nx,0}), latches
  `scry`; jtframe_scroll_offset (COL_SCROLL=1) computes veff = vdump + scry
  at each heff[3] toggle. Paper analysis says col_nx=+1 pairs correctly;
  reality disagrees - next diagnosis should log (boundary, veff, scry, col,
  fetched code) cycle-accurately instead of scanning k.
- Structural resolution (preferred): the hardware latches the row sum in
  1F LS374 strobed by /VPL = 6K pin 18, DUMPED: /o18 = /2H & /4H & /ABT
  (phases 0-1 of a group); column colour loads via LDCOL3H = 6J pin 12
  (dumped); shifter loads via /YA //YB (dumped) at phases 3/7. These fix the
  fetch-to-column pairing with no free parameters - first slice of the
  schematic-exact engine in TODO.md.
- ROOT CAUSE FOUND (2026-09-04): coarse/fine row split across two columns.
  jtframe_scroll_offset updates veff on the heff[3] toggle detected on the
  free-running clk (1 clk after hdump crosses the group boundary), but
  jtframe_tilemap latches rom_addr[2:0] <= veff[2:0] at the NEXT pxl_cen
  edge, 7 clks later - for the tile fetched during the PREVIOUS group. So
  column c got its map row from scroll[c] (correct) and its intra-tile ROM
  line from scroll[c+1] (wrong): correct glyphs, rotated in place within
  each 8px cell whenever adjacent columns carry different scroll. On the
  board this cannot happen: the 1F LS374 (/VPL) latches SigmaV once per
  group and feeds BOTH the tile RAM row and the ROM line from that single
  latch. Explains both experiments: col_nx shifts coarse+fine together, so
  the mismatch is invariant under any col_nx; and the artifact "scrolls
  in-place" because only the fine line animates.
  FIX: jtmnymny_scroll.v drops jtframe_scroll/jtframe_scroll_offset and
  registers the row sum (vsum) once per group at phase 0 on pxl_cen - the
  same edge where jtframe_tilemap samples the fine bits, so nonblocking
  ordering hands the old sum to the previous group's tile, exactly like the
  1F latch. The heff math (scrx=16, HLOOP=360) is replicated bit-identically
  so the verified window alignment is untouched; col_nx=+1 unchanged.
  VERIFIED in sim vs MAME (coin_start.cab, frames 877/1107/1403): HUD strips
  read PL1/PL2 (top) and CREDIT 0 HIGH SCORE (bottom) cleanly during
  scrolling gameplay, matching stock MAME attract/gameplay snapshots
  band-for-band; static screens (title, high-score table) unchanged.
  Hw-video confirmation still pending on real hardware.

## Also relevant, uncommitted right now

- Sound fixes (verified): jtmnymny_snd.v bus sampling (6802 multi-clock bus
  cycles vs cen-gated models - melody CPU used to crash at boot),
  jtmnymny_6821.v read-clear race (command IRQs were eaten; delivery now 1:1).
- jtmnymny_prot.v 6C00 high-bit drive restricted to offset 4 (board-traced
  values vs the over-driving brute-forced 22V10 dump) - intended to fix coin
  acceptance, NOT yet verified (coin credit still unconfirmed in sim).
- Attract mode appears genuinely silent (both PSGs initialised, melody CPU
  idles polling for commands; no demo-sound DIP exists). Gameplay sound
  unverified until a coin credits.
