# F1GPR2 checkpoint

Requested: full wiring check, then a real-ROM boot simulation. Review and boot
attempt complete; CPU startup confirmed, visual/gameplay acceptance remains open.
Set f1gp2: two fx68k M68000s at 10 MHz, Z80 5 MHz, YM2610 8 MHz.
Preserved PLL7159 and existing bank placement. MiSTer-only macros are now
scoped to [mister], preserving the selected MiSTer/SiDi128 target behavior.

Reviewed all six local HDL modules, cfg contracts, shared f1grpr sub/foreground/
mixer, pspike sound, local f1gp.cpp, local MAME vsystem_spr.cpp and shared interfaces.

Fixes:
- Main ROM interleave reverse=true: SP 00ffc000, PC 00000400. Sub PC 000005da.
- Simulation launcher undefines JTFRAME_180SHIFT: jtsim changes JTFRAME_SHIFT
  to zero, so leaving the extra 180-degree shift enabled samples SDRAM early.
  Verified incorrect cached vector words before, correct vectors/instructions after.
- Sprite CG RAM 32 KiB and attributes 4 KiB: missing address bits restored.
- VS9108 sort index, synchronous attribute reads, word CG lookup, palette 0200.
- ROZ full 4 MiB addressing; stable requests, matching palette/pixel selectors,
  CPU byte enables; foreground offsets, opaque base layers and true RGB blank.
- Z80 bank writes 00/0c, one select bit and 8000 base; defaults preserve other
  shared sound users. Turbo and test input; byte-enabled scroll writes.

ROM preparation:
jtframemac mra f1gpr2 --path /Users/andreabogazzi/.mame/roms-local --skipPocket
All nine regions byte-verified against f1gp2.zip; all four actual SDRAM banks
match after normalizing the model's documented big-endian word serialization.

Repeatable normal boot:
cores/f1gpr2/ver/game/sim.sh 360
Installed jotego/simulator:arm64, no pull, normal MiSTer target, full ROM download;
current Linux JTFRAME helper built in ver/f1gp2/scratch/bin. No shared-tool edits.

Evidence under ver/f1gp2:
- scratch/boot-180.log: initial failure, correct downloaded bytes, bad cached vectors.
- scratch/boot-cache.log and boot-vectors-fixed.log: timing fault and corrected fetches.
- scratch/boot-fixed-180.log: full download, 224 transfer frames + 180 CPU frames.
- scratch/boot-fixed-360.log: 360 frames from those verified banks, 59.92 Hz;
  main reaches scheduler 003612-003686 by frame 300, sub remains active.
- scratch/mame-boot.log: approved /Users/andreabogazzi/Emus/mame0276-arm64/mame
  0.282 confirms ROM checksum still running at frame 240, normal execution by 300.
- scratch/reports/boot.json, rom.json, banks.json, sources.json retain details/hashes.
- scratch/frames-mister-360/: 29 preserved images from that run.
  No frame images viewed. No cabinet inputs applied.

Remaining: ACIA cabinet link/IRQ3 is stubbed; raster constants provisional;
graphics pixel accuracy, ROZ throughput, sprite zoom and coin/start/gameplay
need focused validation. Compilation and CPU execution do not establish those.

Clock handling follow-up:
- JTFRAME_180SHIFT and JTFRAME_MR_DDRLOAD moved into [mister].
- sim.sh accepts SIM_TARGET=mister (default) or SIM_TARGET=sidi128; both
  simulation paths use -u JTFRAME_180SHIFT. Target supplies JTFRAME_SHIFT.
- Resolved FPGA profiles: MiSTer SHIFT=1/180SHIFT=1, SiDi128 0/0.
- SiDi128 three-frame probe confirms both reset vectors and executing CPUs.
- Existing JTFRAME doc/macros.md, doc/sdram.md and doc/sim.md now explain
  target scoping, controller XOR and the Verilator override.
- scratch/reports/clock-followup.json records values and current hashes.

Original user-requested 5000-frame run (subsequently found to be service mode):
- Container f1gpr2-boot-5000, image jotego/simulator:arm64, --pull=never.
- Normal MiSTer run with full ROM download and -u JTFRAME_180SHIFT.
- scratch/boot-5000.log; frames/; scratch/boot-5000.exit on completion.
- scratch/reports/boot-5000.json records launch/source details.
- No cabinet inputs, visual inspection or completion monitoring requested.

Service-mode diagnosis and correction:
- F1GP2 MAME driver has no EEPROM/NVRAM device or default persistent image.
  No EEPROM image was added; the existing DIP default 01fbffff is correct.
- JTFRAME service and dip_test are active low, idle 1. Main INPUTS bit 14
  had inverted service; the earlier wiring pass also inverted dip_test when
  combining it with active-low DSW2 bit 8. Both inversions are corrected.
- boot-game-mode-360.log: 360 frames, 59.92 Hz. CPU reads DSW2=fb00,
  INPUTS=ffff. Firmware's DSW2 byte at ff9134 is fb, normal-mode bit 1,
  confirmed through frame 360; default service controls remain released.
- scratch/reports/service-mode-fix.json records checks and current source hash.
- scratch/frames-game-mode-360/ preserves 46 fresh images. No images viewed.
- Original service-mode run had no successful 5000-frame completion evidence;
  its 432 captured images are in scratch/frames-service-5000-partial/.
- Replacement normal-mode 5000-frame run is detached in f1gpr2-game-5000:
  scratch/boot-game-5000.log, frames/, scratch/boot-game-5000.exit.
  scratch/reports/boot-game-5000.json records launch/source details.

ROZ and scene capture follow-up, 25-10-2026:
- Stopped replacement f1gpr2-game-5000 on user request (exit 143).
  Its 2236 images remain in scratch/frames-roz-missing-5000-partial/.
- MAME ctrl register 7 stays zero. Shared jt053936 window asserts ob for this
  setting, so the earlier wrapper suppressed every ROM request. F1GP2 MAME
  config enables 1024x1024 wrapping and ignores window clipping. Wrapper now
  wraps tile coordinates and qualifies output on a completed ROM fetch.
- scratch/roz-diagnostic-420.log: old wrapper has no ROM requests; new wrapper
  scratch/roz-fixed-420.log completes 3584160 requests per 30-frame interval.
  Early boot map uses transparent tile 07ff, which is not visible ROZ content.
- Standalone ver/f1gp2/mamedump.sh and mamedump.lua use approved MAME 0.282 at
  /Users/andreabogazzi/Emus/mame0276-arm64/mame. No Python/skill runtime helper.
  No arguments captures 20 frames 300..6000. --manual uses backslash rising edge.
  --replace backs up the old scene under scratch/capture; unrelated files abort
  publication and remain intact. --output changes the capture root.
- Canonical RAM layout, CPU BE bytes in dump.bin (53248 total):
  ffd000 fg4096 at0 -> fgvram.bin / u_bram_fgvram;
  d00000 roz8192 at4096 -> rozvram.bin / u_bram_rozvram;
  a00000 CG32768 at12288 -> sprcg.bin / u_bram_sprcg;
  e00000 attrs4096 at45056 -> sprvram.bin / u_bram_sprvram;
  ffe000 palette4096 at49152 -> pal.bin / u_bram_pal.
  No aliases or independent video DMA owners in this board map.
- cfg/mmr.yaml raw block order: control 8 at0, psac32 at8, 40 bytes total.
  control byte0 raw fff001 gfx/flip, byte1 fff000 bank, LE16 scroll x/y from
  fff044/46 at2/4, explicit reserved zero bytes6/7. Raw PSAC fff020..3f as
  LE16 words. Retained write-tap handles observe all byte masks from reset.
- Restore: NOMAIN generated jtf1gpr2_control_mmr SIMFILE mmr.bin SEEK0 supplies
  gfx/flip/bank/scroll. rest2bin.sh extracts bytes8..39 as psac.bin; real
  u_video.u_roz.u_xy loads all16 words through its existing SIMULATION loader.
  Generated psac_mmr HDL is unused; the YAML block defines the raw restore data
  consumed by that handwritten loader. Main/sub writes disabled in scene mode.
  Sprite scan/draw pipeline state rebuilds from captured RAM during three frames.
- Only video state is restored; CPU/work/shared RAM, audio and cabinet link
  execution are excluded. PSAC line-mode bit6 in reg7 is rejected: F1GP2 has no
  mapped line RAM. Unmapped upper MAME allocation is not video register state.
- Capture at F holds all RAM/MMR writes through F+1 for native PNG, then rolls
  back whole-machine checkpoint incl. screen frame and restores pause state.
  Numeric scene folders publish only dump.bin/mmr.bin/screen.png. Definition
  checksums cover mem.yaml, mmr.yaml, rest2bin.sh. Captures are ignored.
- Default20 capture completed; native PNGs224x320. No images visually inspected.
  Independent300/600 captures match byte-for-byte across RAM, MMR and PNG.
- scratch/manual-test.log: repeated manual handler at360/420, paused480 twice;
  each restores PC, work/sharedRAM, screen frame and pause. Identical paused480
  dump/MMR/PNG; resumed through600. scratch/manual-test/passed records success.
  Preservation test retains old scene bytes and unrelated keep.txt on rejection.
- ver/game/scene.sh supplies all/fg/roz/obj masks; applies180SHIFT simulation
  override for mister/sidi128. Images/logs under sim_results, builds in scratch.
  Scratch is disposable: permanent entrypoints regenerate required helpers.
- scratch/scene-probe.log: all53248 BRAM bytes and40 MMR bytes verified against
  actual HDL consumer arrays for scene2700, bank1. Stable frame has71680 active
  pixels,71680 non-alpha ROZ pixels,3346 non-alpha sprite pixels. This establishes
  restored content and active pipelines; pixel alignment/accuracy is ungraded.
- User documentation added to existing modules/jtframe/doc/sim.md.

Requested alignment iteration, 25-10-2026:
- Clockwise replay: raw -X maps toward rotated top; raw +Y maps rotated left.
- Delayed the exported blanking pair by one pixel while retaining original
  palette blanking, moving all displayed content one pixel toward rotated top.
- ROZ affine YOFFSET -22 -> 4, translating ROZ +26 raw lines (rotated left26).
- Replayed only2400/2700 through scene.sh, defaultMiSTer, successful.
  Generated only those two diffs; no image inspection or metrics review.

Requested ROZ downward adjustment, 25-10-2026:
- ROZ XOFFSET -4 -> 26: +30 raw pixels maps down30 in clockwise replay.
  Prior YOFFSET4 and global one-pixel display phase retained.
- Replayed all20 captured scenes300..6000 successfully with scene.sh (MiSTer).
  Regenerated all diffs; no images or metrics inspected.

Requested ROZ rightward adjustment, 25-10-2026:
- ROZ YOFFSET4 -> 3: -1 raw scanline maps right1 in clockwise replay.
- Replayed all20 captured scenes300..6000 successfully (MiSTer).
  Refreshed all existing diffs; no images or metrics inspected.

Requested direction correction, 25-10-2026:
- ROZ YOFFSET3 -> 5: +2 raw lines maps left2 in clockwise replay.
- Replayed all20 captured scenes300..6000 successfully (MiSTer).
  Refreshed all diffs; no images or metrics inspected.

ROZ scene timing diagnostics, 25-10-2026:
- ver/game/bench.sh instruments the existing Docker/Verilator scene harness;
  defaults2400/2700, accepts frame arguments, rebuilds runtime C++ in scratch.
  Checks each consumed ROM word against BE16 sdram_bank2.bin, request addresses
  against captured tile RAM plus sampled PSAC coordinates, outstanding address
  stability and pixel-tick acceptance. Per-line counts and latency histograms.
- User requested use of scene sim as the bench. Extra registered synthetic unit
  was removed; no unit registration, runner or shared module change remains.
- Both default scenes complete successfully with zero bad ROM words, address
  mismatches or unstable outstanding requests. Eight clk48 cycles per pixel;
  accepted-hit path4 cycles, misses10..18 (2400) /10..16 (2700).
- Measured frame3: 2400 misses3236/71680 pixel sampling opportunities,3205 while
  cache filling;2700 misses1915/71680,1898 while filling. These are skipped new
  coordinate samples, not a claim that every skipped sample changes RGB.
- The single outstanding ROZ FSM holds old output while waiting and ignores
  pxl_cen in non-idle states. Evidence points to fetch deadlines/prefetch needs,
  with no stale cache payload detected in these two scenes.
- scratch/bench/{2400,2700}-summary.log: clean per-frame measurements;
  corresponding -rows.csv: raw scanline counts; .log: simulator/build output.
  Startup measurements wait for an actual core reset. Diagnostic files use
  unbuffered independent streams to avoid forked PNG output corruption.
- No rendering/cache fix applied from these measurements; latest alignment
  YOFFSET5/XOFFSET26 and all20 canonical replays/diffs remain the review result.

ROZ prefetch and double line buffer, 26-10-2026:
- Jotego jt053936.v unchanged. Wrapper continues clocking coordinates at real
  pxl_cen; YOFFSET5 -> 4 produces next-line coordinates, compensated by one-line
  buffered display. XOFFSET26 and global one-pixel blank phase retained.
- 64-entry coordinate/destination FIFO captures every visible future pixel.
  Fetch FSM drains independently of pxl_cen, keeps ROM requests stable until
  acknowledgment and stores palette/pixel into alternating512x8 RAM halves.
  Only320x224 visible future pixels fetched, blanking available to drain queue.
- Per-bank line tags, completion counts and failure flags prevent stale/partial
  lines from becoming visible. Late writes cannot corrupt a reused bank. Output
  pixel register preserves original palette pipeline phase. Logical line data
  640bytes; physical buffer1024bytes; request FIFO2688bits.
- scene.sh default all20 successfully replayed. In canonical logs,63 full frames
  checked:224 complete lines each, zero incomplete/overflow/late, peak queue3.
- Updated existing scene bench for queued coordinates and buffered output:
  captured tile RAM/ROM -> expected addresses, payloads and per-screen pixels.
  bench.sh2400/2700 passes3 full frames each:71680 pixels, zero underruns,
  incorrect words, addresses, pixels or unstable outstanding requests; peak2.
  Diagnostics remain in scratch/bench; no synthetic/unit tests added.
- Refreshed all20 diffs. No images or diff metrics inspected. Hardware fitting
  and physical FPGA timing are not established by these scene simulations.

Visible edge and analog steering review, 26-10-2026:
- First-column fault reproduced in existing scene2700 instrumentation: active
  raw_h0 RGB0000, raw_h1 RGB56b1; raw_h320 had palette4a4e but was blanked.
- F1GP2 video now delays exported blanking two pixel stages and feeds the
  first delayed stage to shared colmix gating. All320 valid palette pixels
  are displayed. Shared F1GPR colmix and Jotego chip sources untouched.
- bench.sh2700 verifies first active sample raw_h1=56b1, last raw_h320=4a4e;
  raw_h0/321 outside active window. Three frames: no ROZ underruns, word,
  address or buffer-pixel mismatches. Edge probes retained in existing bench.
- All20 canonical scenes replayed and diffs refreshed; no visual inspection.
- Approved MAME0.282 executable -listxml f1gp2 confirms 0..255 analog stick
  input and Input Method DIP(SW3:8 / DSW2 bit15) with Steering Wheel value0.
  Local driver PORT_AD_STICK_X has center80 and is inherited by f1gp2.
- Steering already correctly wired: joyana_l1[7:0] signed X -> flip sign bit
  -> unsigned00/80/ff at left/center/right -> main fff002 low byte. Mister
  joystick_l_analog_0 and MiST/SiDi user_io forward analog buses unconditionally.
  JTFRAME_NOMULTIWAY already set prevents analog-to-digital multiway emulation.
  No JTFRAME_ANALOG consumer exists in this framework: do not add a dummy flag.
  No additional core analog wiring/configuration change was necessary.
- Select Input Method=Steering Wheel (core dipsw23=0). Default remains joystick.
  Inherited MAME input definition warns that wheel mode is unresolved in-game;
  ADC wiring is established, functional wheel gameplay/real cabinet support is
  not established by that definition or these frozen video simulations.

Corrected edge fix after user review, 26-10-2026:
- Previous blank-delay2 moved the sampling window from raw_h0..319 to1..320,
  shifting content up in clockwise images. Reverted exported blanking to one
  stage and colmix gating to original preLHBL/preLVBL.
- Actual cause: ROZ display pixel/valid was held until pxl_cen, too late for
  palette lookup at the first visible sample. Read the completed line buffer
  continuously on clk; latch its ready state while hdump0 before display tick.
- ROZ XOFFSET26 ->27 compensates removal of the full-pixel output hold, keeping
  interior content at its previous position. YOFFSET4 retained. Jotego intact.
- Existing scene bench2400/2700: raw_h0 and319 both active with expected palette
  data; h320/321 blank. No underruns, wrong words/addresses/pixels or unstable
  requests in3 measured frames per scene.
- Saved prior shifted PNGs in scratch/edge-before/. For BOTH2400/2700, all71456
  interior RGB pixels compare exactly when undoing that erroneous one-row shift:
  new rotated rows1..319 equal saved shifted rows0..318. New top row is fetched
  pixel data, not a stretched/copied edge. No image viewing/editing performed.
- All20 canonical scenes replayed and diffs refreshed after this correction.

Commit and normal build dispatch, 26-10-2026:
- Commit892989c4957b5825d81091f51b64109b4fadfd88 on andrea-cores, Andrea Bogazzi
  <andreabogazzi79@gmail.com>. Commit hook pushed origin/andrea-cores; verified
  remote SHA through gh API.25 files include core/tools/MAME refs/shared sound
  parameters and this work's SDRAM clock/scene documentation. Unrelated working
  files and cache-documentation hunks remain outside the commit.
- Normal jtframemac mra f1gpr2 --nodbg --skipROM --skipPocket passed and emitted
  release/mra/F-1 Grand Prix Part II.mra (setname f1gp2,rbf jtf1gpr2). Only existing
  overlong Multi Player Mode DIP-label warnings; scratch/build-preflight.log.
- Dispatched existing compile-custom.yaml on andrea-cores, core=f1gpr2,
  target=mister,sidi128, debug=false. Run40248669558:
  https://github.com/jotego/jtcores/actions/runs/40248669558
  FPGA build results pending at dispatch.

Additional-game feasibility review, 26-10-2026:
- Checked official mamedev/mame tag mame0282 f1gp.cpp and crshrace.cpp through
  gh API; copies in scratch/references/*-0282.cpp. Approved MAME0.282 -listfull
  confirms five f1gp-driver sets and three crshrace-driver sets. Local source
  checkout f1gp.cpp contains extra flip patches; use official tag for findings.
- f1gp2: one set, no sibling clones. f1gp/f1gpa already targeted by f1grpr config.
  Original hardware has two SPR2 engines,256KiB writable ROZ graphics and GGA;
  merging it into f1gpr2 adds hardware/resource/testing cost without a new title.
- f1gpb: same original configuration, earliest/wheel-only revision; marked
  MACHINE_NOT_WORKING. ROM packaging low effort; analog/control debugging
  uncertain. Better investigate under f1grpr, not expand f1gpr2 backends.
- f1gpbl: Playmark bootleg, MACHINE_NOT_WORKING. Different sprite layout,
  custom ROZ/foreground registers, no sound Z80/YM2610, OKIM6295 instead, and
  unresolved sample banking. High-cost separate hardware project.
- Best next new game: Lethal Crash Race/Bakuretsu Crash Race, crshrace,
  crshrace2,crshrace2a (alternate sound). All working in MAME0.282. Same
  VSYSTEM_SPR and K053936 (-48,-21), raw8bpp chars/packed4bpp ROZ/sprites,
  YM2610,320x224, but ROT270 vsF1GP2 ROT90.
- Adaptations: one68000 nominal16MHz instead of two10MHz; Z804MHz vs5;
  MAME flags CPU clock/dividers uncertain. Newmainmap with user1 at300000,
  user2 at400000 mirrored500000, workRAM64KiB atfe0000. No linked subCPU.
- ROZ tile lowcode12bits+bank<<12 vs11bits+bank<<11 (same4MiB region).
  Sprite ROM4MiB vs2, CG table64KiB vs32, attributes8KiB vs4; widen addresses.
  Both sprite memories snapshotted on vblank. Need live+buffer ownership in
  capture/restore, not CPU taps alone. Foreground code/flip/offset assumptions
  differ; nominal64x64 MAME map but CPUcharRAM4KiB, visible area only uses28rows.
  Palette xGBR555 vsxRGB555; distinctpriority mux/backgroundpen511. Sound bank
  mask3/base0, latch04,YM08..0b (currentF1GP2 latch14,YM18..1b).
- Declared ROM regions sum13.625MiB vsF1GP2 12MiB, including unpopulated tile
  padding. Fits32MiB total SDRAM capacity; actualbanklayout/padding mustchange.
  Straightall-BRAM storage estimate relativecurrentF1GP2: spriteRAM/copies
  +108KiB; workRAM replacingmain/sub/shared +28KiB =>~136KiB beforecache changes.
  Separate thin crshrace wrapper sharing RTL avoids inflating F1GP2 resources.
- Rough planning estimate only: 5..10 focused engineering days for first set
  through boot, scene comparison and FPGA validation; other two sets mostly
  ROM/MRA/inputs plus per-set validation. Hardware clocks/fit can extend this.
  No new core/game support implemented by this review.

ROZ scheduling and foreground review, 26-10-2026:
- Explicitly enabled PIPELINED=1 on the F1GPR2 ROZ instance; retained shared
  renderer defaults, ROM width, bank placement and cache capacities.
- SIM_TARGET=sidi128 cores/f1gpr2/ver/game/scene.sh 2400 completed successfully.
  Output: ver/f1gp2/sim_results/2400.png and 2400.log. No image inspection;
  one frozen scene is not confirmation that the hardware rotation issue is fixed.
- Foreground remains unchanged. Shared jtf1grpr_fg samples ROM readiness only
  on pxl_cen, changes the ROM address from raster/map data with CS permanently
  asserted, and swaps nxt into cur at a fixed four-pixel boundary without a
  request/address validity check. These are concrete latency/handshake risks;
  attribution of the reported flicker remains provisional.
- Proposed next text change: stable request/response ownership and master-clock
  response capture, with one-line-ahead double buffering (640 bytes of pixels
  for 320-wide output, approximately 1 KiB allocated). Preserve scroll/flip and
  alignment; make buffered use explicit for f1gpr2/crshrc so f1grpr stays intact.
  Keep 32-bit client/32-bit bank burst initially; 64-bit bank-0 bursts can fill
  one full 8-byte text tile row later, but also affect main ROM on that bank.

Partial ROZ display and foreground handshake, 26-10-2026:
- User selected partial ROZ display and the three foreground fetch corrections
  before any foreground line buffering; scene4200 is the only requested scene.
- Shared ROZ tracks 320 populated positions per line-buffer bank, clears them
  when the bank is reused, and pipelines readiness alongside RAM data. Completed
  pixels display independently; unfilled positions are transparent. Existing
  whole-line readiness/overflow counters remain diagnostic only.
- Shared jtf1grpr_fg has opt-in HANDSHAKE mode. Map/ROM requests are registered,
  ROM address/CS held through completion, synchronous map/cache latency observed,
  and responses captured on every master clock. Two tagged 32-bit groups serve
  only matching display rows/positions. Late valid data can supply the remaining
  pixels of its group. No FG line buffer added.
- HANDSHAKE=1 for f1gpr2/crshrc; default0 preserves f1grpr. Cache capacities,
  ROM widths/layout, clocks and Jotego chip internals remain unchanged.
- SIM_TARGET=sidi128 cores/f1gpr2/ver/game/scene.sh 4200 passed. Full frames:
  FG_FETCH pixels=71680 missing=0; ROZ224 lines, incomplete=0 overflow=0 late=0,
  peak_queue=1. Outputs ver/f1gp2/sim_results/4200.png and4200.log; detailed
  build log ver/f1gp2/scratch/replay/4200-all.log.
- Matching crshrc scene4200 passed with the same clean pixel/deadline counters.
  No other scenes, image inspection, forced starvation, extra unit runs, FPGA
  builds, commits or pushes. Frozen scenes exclude CPU contention; the partial
  ROZ fallback under an actual deadline miss remains for hardware verification.

Scene4200 missing-glyph diagnosis and fix, 26-10-2026:
- User explicitly requested inspection of4200 in both games after unchanged
  defects. Respect silent simulation runs: wait for completion, no progress
  updates or polling logs while a script runs. No further scene expansion.
- F1GP2's captured foreground contains only tile0 (fully transparent) and7131
  (separator graphics); the lettering and track cards are VS9108 sprites.
  Prior zero-missing FG counters did not cover these missing glyphs.
- Sprite-only scene4200 reproduces missing glyphs. Original S_EVAL discarded
  on-line records when its eight-entry FIFO was full:152/160 drops per full
  frame,5912/5904 emitted tiles. Baseline log sim_results/obj/4200.log and
  before image scratch/text-4200/before.png preserve the evidence.
- Shared objscan now stalls S_EVAL until FIFO space exists. Retains eight
  entries, original ordering, draw timing/interfaces and Jotego chip modules.
  SIMULATION counters report stalled cycles, peak queue, unfinished scans and
  emitted tiles. Fixed4200 emits6304 tiles/full frame, unfinished=0, queue peak8.
- Replayed only4200 for SiDi128 in both games and regenerated4200 diffs.
  F1GP2 went from750 differing RGB pixels to0/71680 exact. Crshrc also required
  its foreground HOFFSET0; final Crshrc4200 is0/71680 exact (previous8763).
- Images inspected as explicitly requested. Both fixed replays retain zero
  missing FG pixels and zero ROZ incomplete/overflow/late events. Logs/images
  are canonical sim_results/4200.* and diff/4200.png; run logs under
  scratch/text-4200. Other scenes were not refreshed after these latest fixes.
  No unit tests, FPGA builds, commits or pushes; hardware acceptance remains.

Foreground offset normalization and scene1800, 26-10-2026:
- User requested the equivalent Crash Race offset correction and f1gp2 scene1800.
  F1GP2 already canceled default HOFFSET1 through79/161 scroll additions.
- Selected HOFFSET0 explicitly and changed normal/flipped additions to80/160.
  Effective source coordinates remain identical in both flip modes; this removes
  the split compensation without introducing a one-pixel shift to correct4200.
- SIM_TARGET=sidi128 cores/f1gpr2/ver/game/scene.sh 1800 completed successfully,
  silently. Output ver/f1gp2/sim_results/1800.png and1800.log; preparation/run
  log ver/f1gp2/scratch/replay/1800-run.log. Only1800 replayed. No image inspection,
  extra comparisons/regressions, FPGA builds, commit or push requested/performed.
