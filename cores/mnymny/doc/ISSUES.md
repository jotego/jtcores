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
- Attract mode appears genuinely silent (both PSGs initialised, melody CPU
  idles polling for commands; no demo-sound DIP exists).

## 4. Cocktail mode / screen flip broken - ACTIVE

- Symptom: setting the Cabinet DIP to Cocktail (SW 5I:5) and starting a
  2P game makes the flipped screen entirely broken, not just mirrored
  wrong. The flip bit clearly has effect, so the LS259 write path works.
- Wiring today: 3G LS259 bit0 = flip_x (VCMA), bit1 = flip_y (HCMA), per
  MAME mainlatch. jtmnymny_game.v: dip_flip = flip_x. jtmnymny_video.v
  passes ONLY flip_x to both u_scroll and u_obj; flip_y is an input but
  is CONNECTED TO NOTHING inside video.v - vertical flip is entirely
  unimplemented. On this rotated game the MAME "x" axis is our scan
  (hdump) axis; both axes need handling.
- MAME reference behaviour (zaccaria.cpp, checked 0.276):
  - bit0 -> flip_screen_x_w: flip_screen_x_set(state) AND
    update_colscroll() - re-applies all 32 column scrolls because
  - attribute reads are ADDRESS-MIRRORED under x-flip:
    read_attr does `if (flip_screen_x()) offset ^= 0x1f;` - the per-column
    scroll AND colour attributes come from the mirrored column entry.
    Our scroll shim does NOT mirror: col/col_nx use va[4:0] directly
    (only col_nx switches +1 -> +31... via `flip ? 5'd31 : 5'd1`).
  - bit1 -> flip_screen_y_set directly (plain tilemap y flip).
  - sprites: sx = 240-sx with flipx inverted under x-flip; sy = 240-sy
    with flipy inverted under y-flip. Our jtmnymny_obj.v does NEITHER:
    sy/ydiff math ignores flip entirely, and xpos passes raw; only
    jtframe_objdraw's internal `flip` input is fed (semantics may not
    match this 240-sx convention - check XOFFSET/flip in jtframe_draw).
- Suspected breakdown (to verify in sim before changing anything):
  1) tilemap: heff ^ {8{flip}} flips the fetch axis but the column
     attribute index is not mirrored (missing offset^0x1f equivalent),
     so scroll/colour pair with the wrong columns when flipped -> screen
     "breaks" rather than mirrors. col_nx flip term is paper-derived,
     never verified against hw/MAME.
  2) vsum uses vdump^{8{flip}}: mixes the flip into the row sum, but
     bit1 (flip_y) should drive this, not flip_x - the two axes are
     currently tied together through the single `flip` input.
  3) objects: no coordinate mirroring at all; jtframe_objdraw flip
     semantics unverified for this board's separate VCMA/HCMA flips.
- The generic jtframe_tilemap/objdraw flip inputs may be usable, but the
  Zaccaria attribute-mirroring (colscroll under flip) has no jtframe
  equivalent - that part must live in the shim either way.
- How to reproduce in sim: cocktail DIP on, coin + 1p + 2p start via cab
  (2P game reaches the flipped rounds), or force the LS259 bits early.
  MAME same-state screenshots are the grading reference (stock mame:
  DIP overrides silently do nothing - use the service menu or a .cfg
  known to work; see memory note on scene capture).
- Related: schematic path for flips is the LS86 XOR banks 7F/8F/8J/7J
  (line-buffer addresses) + sigma adders for object rows - the same
  banks as issue 1; doc/pld/equations.md has the dumped 6J/6K terms.

## 5. High scores not saved - ACTIVE

- Symptom: "Todays high scores" reset every power cycle; the Table Title
  DIP (Todays / All time, SW 3I) suggests the board kept an all-time
  table in battery-backed RAM.
- Hardware: 7000-77FF work RAM; the 2C/2D half (upper 1KB? confirm on
  sheet 1) is the battery-backed section on the real board. The game
  keeps the all-time table there.
- Current plumbing: mem.yaml wram has ioctl save+restore (order 0), MRA
  carries <nvram index="2" size="2048"/> - so the FULL 2KB work RAM is
  dumped/restored via the NVRAM mechanism, commit 6a86cc3c0.
- Unknowns / next steps:
  1) Verify on MiSTer that the NVRAM file is actually written on exit
     and reloaded (needs OSD save enabled? jtframe NVRAM doc) - scores
     "not saved right now" may be a platform behaviour, not core logic.
  2) Restoring the whole 2KB (not just the battery-backed half) also
     restores volatile game state - check whether the game re-inits the
     volatile half at boot (likely, given the checksummed NVRAM restore
     code at boot) or whether we corrupt startup state.
  3) The boot code validates the NVRAM (S1 notes: restore-from-SD added
     precisely for this); if validation fails it wipes the table -
     an all-FF or zeroed file must still boot clean.
  4) MAME parity: mame monymony saves .nv len 0x800 - compare its file
     layout with our ioctl dump to confirm addressing matches.

## Sound / speech issues

### S1. Coins never credited in sim - FIXED (2026-09-07)

- Symptom: game stuck on title/attract, credit counter (7269) never
  incremented; every coin insert ignored, so gameplay + gameplay sound
  could never be reached in sim (and reportedly on hardware too).
- ROOT CAUSE (diagnosed by Andrea): the jtframe Z80 wait wrapper's cycle-recovery
  (`jtframe_z80wait`, RECOVERY=1 default) corrupts DEVICE reads on this
  core's 48 MHz / 8 MHz clock config - exactly the combination the module
  header comment warns about (jtbubl issue #27). The recovered cen pulses
  make the tv80 latch stale data on the 6C00 coin-port reads, so the ROM's
  10-read debounce loop (5761) never sees the coin low on all ten reads ->
  no rising edge (700F stays 0) -> coin-accept (57B3) never fires -> no
  credit. Port decode itself is correct: coins_in[0] reads low and stable
  on every 6C00 read.
- FIX: `jtframe_z80_romwait #(.RECOVERY(0)) u_cpu` in jtmnymny_main.v.
  Precedent: bubl, dd, kiwi, comsc etc. already use RECOVERY(0).
- VERIFIED in sim (coin+start cab): credit 7269<=01 at the same frame as
  MAME (F262), game leaves the title screen, scores points (PL1 500).
  Do NOT let this revert to the default - see the header warning.
- Trade-off: recovery reclaims cycles lost to SDRAM ROM waits; disabling
  it is negligible for this 3 MHz Z80 but note it if timing looks off.

### S2. Speech cut short vs MAME - FIXED (2026-09-07)

- ROOT CAUSE: nmi_n was the level term ~(nmi_mask & ~LVBL). The NMI handler
  toggles INTST 0->1 to ack; re-enabling INTST while still inside vblank
  re-asserted NMI -> 2 NMIs per frame. The game's music delay (counter 74E0,
  decremented in the NMI handler's and-$07 slow tick at C452/C456, queued at
  C0D6 via 5063) then expired in half the time: music cmd 0x0b arrived 74
  frames after speech cmd 0x2C instead of MAME's 142 (2.37 s), and any host
  command aborts speech by design (see below) -> phrase cut mid-word.
- FIX: jtframe_edge #(QSET=0) in jtmnymny_main.v - NMI set on LVBL falling
  edge, cleared while INTST=0, no retrigger (same pattern as jt051960/
  jt052109 u_nmi). MAME equivalent: vblank_irq ASSERT_LINE + nmi_mask_w
  CLEAR_LINE.
- VERIFIED in sim (coinplay.cab, full-game): exactly 1 NMI/frame, 74E0 steps
  every 8 frames, speech 2c at F304 plays to natural end F428 (2.06 s),
  music 0b at F447 vs MAME F444 with the same coin/start cadence (MAME tap
  s2timeline.lua). Capture cry 0x37 also plays full length (F779-F863).
- Sim cab for gameplay: coinplay.cab (256 / 4 coin / 40 / 12 1p) - short
  presses; the long-press coin_start.cab predates the debounce findings.

### S2-old notes (kept for reference)

- Symptom: intro sentence is cut when the music starts ("you can go and
  ll..." instead of "...look for the money"); the capture cry says "help"
  once instead of "help help".
- Established (do NOT re-derive):
  - Clocks verified end-to-end: TMS5200 cen = 649200 Hz (RC osc, matches
    MAME `TMS5200(config,...,649200)`), 6802 + AY cens all correct.
  - Sound-board RTL matches MAME in isolation: on the sound-only bench
    (ver/snd/: tb_snd.v + sim.sh) the intro phrase 0x2C lasts 2.046 s vs
    MAME WAV 2.05 s. Feed loop, status bytes, INT/READY handshake trace
    correctly - the TMS model timing itself is close.
  - FIRMWARE FACT (6802 disasm): any host command ABORTS speech by design
    - the sound-CPU IRQ handler resets its stack, forwards music cmds to
    the melody CPU, and never resumes talking. No resume path. On real hw
    the sentence survives only because the game sends the music command
    ~2.28 s after speech start while the phrase is ~2.05 s (0.23 s margin).
  - Command timeline identical across monymony/monymony2 (MAME tap): boot
    init ~F221, coin sound 0x12, intro speech 0x2C ~F802, music 0x0b ~F940
    (~2.28 s after speech).
  - The coin blocker (S1) is now fixed, so a FULL-GAME sim can be driven
    with the real command timing - better than the isolated bench.
- Leading hypothesis: on the FPGA the speech runs SLOWER or STARTS LATER
  than MAME, so the phrase is still going when the 2.28 s music command
  arrives and the firmware aborts it. Discriminate (a) TMS synthesis rate
  too slow, (b) speech CPU starts late, (c) music command arrives early.
- Tools ready: ver/snd/ bench (tb_snd.v, sim.sh, melody.hex, speech.hex);
  MAME ref `~/Emus/mame0276-arm64/mnymny_ref.wav` + sndtap/creditfind Lua;
  6802 disasm in /tmp/spc_*.asm; set monymony (top MRA "Money Money (set 1)").
- Next step: full-game sim, coin+start via .cab, capture the speech
  envelope and the frame the music command is sent; compare phrase length
  and start offset against the MAME WAV.
- Analog-network detail for the speech path is in AUDIO.md (speech stage,
  ~390 Hz-4.1 kHz band-pass); this issue is about TIMING, not filtering.
