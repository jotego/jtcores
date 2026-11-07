# YM7101 full frame diagnostic

This standalone timed Verilator runner compares the current YM7101 against an
identified historical YM7101, YM library, and VRAM model. `test.v` dispatches
the default render fixture and opt-in service, feature, and legacy-format
profiles. It has no `.simunit`; the short current-source CI smoke is in
`../ym7101_passive/`.

Historical HDL is an external input and is not checked into the repository.
The default source is `/nobackup/tasks/jtcores-180/baseline/source` at
`3dc6b88e0204fd3abbb462b34f428757f8596e94`. The runner verifies that identity,
renames baseline modules in a private build snapshot, and records source hashes
in `manifest.txt`. Candidate dependencies include `ym7101_raster.v` and
`jtframe_vtimer.v`, compiled with `SIMULATION` enabled.

Run from the repository root after sourcing the project environment:

```sh
source modules/jtframe/bin/setprj.sh
cores/s18/ver/ym7101_render/sim.sh --mode legacy
cores/s18/ver/ym7101_render/sim.sh --mode legacy --scenario legacy_formats \
  --build-dir /nobackup/tasks/jtcores-180/render/legacy-formats
cores/s18/ver/ym7101_render/sim.sh --mode passive \
  --geometry 400x262 --build-dir /nobackup/tasks/jtcores-180/render/passive
cores/s18/ver/ym7101_render/sim.sh --mode passive --mode4 disabled \
  --geometry 400x262 --scenario pattern_a --transitions \
  --build-dir /nobackup/tasks/jtcores-190/render/mode4-off-pattern
```

`--mode legacy` compares the pristine and candidate models. `--mode passive`
checks independent raster acquisition and rendered pixels. Passive geometry
options are `400x262` (default), `384x260`, and `384x261`; `--transitions` adds
the longer reset and display mode transition matrix. Both options are captured
and verified when running an immutable staged snapshot.
The candidate YM7101 defaults to `MODE4=1` for every existing invocation.
`--mode4 disabled` explicitly tests the S18/Pocket `MODE4=0` wiring in passive
mode and is recorded in the staged manifest. The option is rejected in legacy
mode and for `legacy_formats`, whose default MODE4 comparison preserves the
Mode4 and Mode5 H32 historical checks.

`--scenario pattern_a` is the default and retains the validated PatternA
fixture. `--scenario service` runs additional CPU-visible CRAM/VSRAM read and
autoincrement checks plus a cancelled-command check after the same raster and
pattern setup. `--scenario features` selects the passive-only nonzero graphics,
scroll, window, and sprite profile. `--scenario legacy_formats` selects the
legacy-only Mode5 H32 and Mode4 full-image comparisons; it requires the default
400x262 geometry and cannot be combined with reset transitions. That fixture
checks 224 Mode5 rows and 192 Mode4 rows, each with 256 contiguous pixels and
candidate/pristine equality. It requires nonzero complete 342-event native-H
traversals during the full active epoch and checks every completed traversal;
the traversal count is not an active-row count. The legacy profile uses the
default-off attached VRAM behavior in `LEGACY_TEST`. Service additions remain
isolated in `service_profile.vh`; each scenario and the reset transition
profile is recorded in the staged manifest.

`--scenario copy_first` runs the reviewed reset-origin VRAM copy procedure
before any CPU read. It checks the literal 16-byte payload, source and
destination sentinels, destination words before source words, completion,
drain, and the selected launch phase. `--copy-start active` selects the
independent active-origin event (default); `--copy-start late` selects the
predeclared fast-blank event and is supported only in passive 400x262 and
384x260 modes. `--copy-start` is rejected outside `copy_first`.

The ordinary `service` scenario continues to test MMR memory access, FIFO
backpressure, fill, and passive H/V latch behavior. It does not run the known
CPU-read-before-copy history. `--scenario copy_read_before` retains that exact
historical sequence and strict byte oracle as a separate legacy-only 400x262
diagnostic; it is expected to exit nonzero when the documented payload
mismatch reproduces. This result does not change the copy-first acceptance.

`--scenario irq_hv` selects the private interrupt and blank/HV profile. Passive
mode supports 400x262 and 384x260. It checks the source-only H/V edge schedule,
the HIRQ sequence beginning at active y6 (including V511's preactive count),
masked and restored VIRQ pending state, status bit7, and the AS acknowledge
clear edge at two MCLKs after registered YM AS (`raw release R+3`). It also
checks full HV words at the two row223 sides
(`dfa4` and `e0a5`) and across the H364/H457 jump (`ddb6` and `dee4`) using
fixed legal CPU S0 windows and the modeled two-MCLK data history. The source
oracle counts each physical blank row, checks q235 encoding, the final V511
tail row, and V0 after that tail. It does not derive expected H/V from the DUT
counters.

In the passive profile, the second counted frame retains the y222 H request
through the fixed row223 HV read. The later masked V request is then observed
with H still pending; VIE enable selects the V-priority pull vector, masking
VIE reveals H, and restoring VIE restores V priority. The designated V-only
acknowledge is checked at its exact registered-AS+2 observer for the retained
H vector and post-ack H/V model state. An INTAK=1 status read must preserve H
with status bit7 clear, followed by a separate exact H-only acknowledge that
clears the survivor. Final acceptance requires separate per-step flags and
exactly one V-ack survivor observation and one H-survivor clear observation;
the existing frame-one V-alone acknowledge remains separate.

The strict passive 384x260 IRQ/HV fixture declares a two-clk96-edge startup
delay for the CPU divider only. It then uses the unchanged 20/96 enable
accumulator and 10 MHz bus sequence. This analytically selected test phase
makes the fixed H364 full-word sample reachable; it does not alter the master
clocks, raster or production clocking. The passive 400x262 fixture uses no
divider delay and selects source frame phase 0 before enabling its two counted
IRQ epochs. Each staged manifest records `cpu_start_delay96` explicitly (2
only for passive 384x260 `irq_hv`, otherwise 0), and staged verification checks
it.

The ACK watcher counts the selected YM MCLK (`clk48` in passive mode and
`clk96` in legacy mode). It keeps the raw CPU S6 AS-release count `R` and
separately anchors the registered YM AS input on `M1=A=R+1`. It requires the
pending request at `A+1` (`R+2`) and the acknowledged clear or H-survivor at
`A+2` (`R+3`). It requires INTAK=0 at the pre-edge sample while registered AS
is still low at M1; after AS is registered high, the legal CPU driver may
restore INTAK before M3. Raw and registered AS must remain released, and the
independent source model must emit no new H/V event through M3. The existing
CPU driver and S6 release timing are unchanged; this accounts for the
wrapper's one-MCLK AS register and the actual CPU return edge.
The H blank-clear flag counts only source-model rows `q>=224` after raw LVBL
falls, while HIE is enabled and both pending expectations are clear; horizontal
blank samples on active rows do not contribute.

The same scenario in legacy mode is limited to 400x262 and compares IRQ pins
continuously against the pristine model while checking CPU status and four
legal H/V reads. Its setup first disables HIE, clears V through an ordinary
INTAK-qualified status access, observes and acknowledges a fresh native V
request, then enables and clears any accumulated H request before the main
H-only probe. The native pin wait uses the 420-event legacy H40 traversal, not
the separate 400-pixel external timer, as its bounded timing unit. During the
main probe VIE stays masked through the first H acknowledge and the next
independently observed H request; enabling VIE then tests V priority and H
survival. Preparation comparator samples are excluded from the main H/V
coverage counters. The optional `+irq_calibrate` path is diagnostic only and
does not satisfy the strict profile. Calibration evidence is archived at
`/nobackup/tasks/jtcores-180/irq-hv/calibration-400-v2.log`; the diagnostic
recorded 15 clk48 edges, but strict metadata is normalized after NBA on both
S0 and S6. The accepted three-cycle delta is derived from the independent
clk96 edge residue: canonical residues 6/16 yield 15 clk48 edges; 25/35/45
yield 14. The 384x260 profile normalizes the raw residue by subtracting the
declared two-edge startup delay before applying that same table; logs retain
both residues and K.
The strict S0 age envelope is derived from each unchanged S6 window and only
accepts an actual CPU edge whose phase-specific delta lands inside that S6
window. The first calibration timeout
used a one-frame bound for a declared next-frame row223 target; the recorded
entry was frame5/y4, and source chronology placed that target about 1.84 frames
away. The later factor-of-two bound allowed the diagnostic to finish, but the
cause was target distance, not a half-rate `tick()` timebase: passive `tick()`
waits one clk48 edge, while legacy `tick()` waits one clk96 edge. The final
waits calculate their bound from the current source frame/row and selected
mode. The legacy HV sample bound is `(frames_ahead+1)*(N+2)*T*edges_per_pixel`,
with negative `frames_ahead` clamped to zero; the existing fail-fast check
rejects a target already passed. The v2 row223-after diagnostic captured
`dfa4` at age2433, one edge before
the intended `e0a5` window; it does not establish that endpoint. The strict
IRQ/HV fixture has since passed three reviewed private dynamic profiles:

- `PASSIVE_TEST`, 400x262/K0: candidate IRQ/HV behavior against the independent
  source/status oracle (`passive400-priority3-20261102T023204Z`).
- `PASSIVE_TEST`, 384x260/K2: the same independent source/status contract
  (`passive384260-priority3-20261102T034000Z`). The directory suffix is an
  erroneous opaque label, not a timestamp; separate `launch-observation.txt`
  and `terminal-provenance.txt` preserve the approximate launch evidence and
  state that exact start/finish times were not captured.
- `LEGACY_TEST`, 400x262/K0: current/pristine IRQ-pin and CPU HV comparison
  (`legacy400-prep-review1-20261102T024006Z`).

The reviewed receipts and scope are in
`/nobackup/tasks/jtcores-180/review-irq-priority-result.md` and
`/nobackup/tasks/jtcores-180/review-irq-final-delivery.md`. The promoted shared
composition keeps the tested `test.v` hash
`a2b82559d4f8c97c6af640c1530806677f9548b05b74fbccaf6ee44169998a98`, IRQ
include hash `5cfe1fa9442c9982b2ba9674df08e2b0c57f9c5d7bd0069d4274bd2d1e9e2bdd`,
and runner hash
`f278a119080f415bc980204665b3cb38d94d19bf011b29d81c06b4ed74293be5`.
The maintained CLI staged and revalidated the three profiles with 15/15 source
hashes and K values 0/2/0. Default passive384 PatternA, passive384 features,
and legacy default scenarios retain K0; invalid mode/geometry/scenario
combinations reject. Static Verilator lint passed for all three IRQ profiles.
Exact promotion-time commands, manifests, results and index checks are in
`/nobackup/tasks/jtcores-180/irq-hv/permanent-merge-delivery/DELIVERY-MANIFEST.md`.
Those staging manifests are historical records of the pre-correction README
hash; this documentation refresh does not change testbench, runner or HDL
inputs. These are scoped fixture results, not whole-game IRQ or hardware
acceptance.

Use `--baseline-dir DIR --baseline-sha SHA` to select another identified
baseline, `--candidate-dir DIR` to choose the current RTL directory, and
`--build-dir DIR` to isolate output. To snapshot source and manifest without a
build, run `--dry-run --build-dir DIR`; later `--run-staged DIR` verifies every
input hash and test setting before building that snapshot. `--keep` preserves
the FST waveform. Build parallelism defaults to four jobs and is configurable
with `YM7101_RENDER_JOBS` (1–4). Unknown flags and positional arguments are
rejected; pass any runtime arguments to the C++ harness after `--`. Each build
directory has an OS-level `.sim.lock` held for the entire invocation, so a
concurrent writer fails immediately without replacing the active run's files.

The full-frame fixture checks raster lock, the 420-event prime, readiness,
complete active rows, and candidate/reference pixel tuples. It is intended for
diagnostics and historical comparisons; the short CI smoke does not require
the external baseline or wait for raster acquisition.

## Runtime geometry switch

The `geometry_switch` scenario is a passive-only testbench profile. Run it with
`--mode passive --geometry 400x262 --scenario geometry_switch`. It uses one
fixture-local runtime timing source whose counters and sync pipeline follow
`jtframe_vtimer`; requests are latched at `H=0x1ff`, `vdump=0xe0`, with LVBL
already low. The tested sequence is 400x262, 384x260, 400x262, 384x261,
400x262. The clocks, VDP reset, CPU MMRs, and pattern memories remain
unchanged; the new H start takes effect on the timer's normal line-wrap edge
without a counter reset.

The scenario checks source line periods, the analytically derived VS and
LVBL crossing intervals, all 224 active lines and 320 active pixels per line,
YM raster lock and measured dimensions, renderer mute/re-prime, the 420-event
H traversal, and fast quotas 40/72. After each profile is ready, it compares
full 320-pixel RGB/YS tuples at rows 0, 1, and 100 in two successive frames
against the original seeded 400x262 image; rows 0/1 carry the colored pattern
and row 100 is required to remain transparent black. A CPU status read is
acknowledged after each switch to check post-switch liveness. This is not
a bus transaction held across the commit and does not extend the existing
static IRQ/HV coverage to geometry transitions.

This proves passive YM tolerance to the supplied timing stream. The source is
testbench-only; this profile does not establish that the production S16
tilemap/graphics fetch pipeline can generate or render the shortened raster.

The `production_switch` profile runs the bounded YM checks from the production
`cores/s16/hdl/jts16_vtimer.v`, not the fixture-local timer used by
`geometry_switch`. Run the immutable reviewed snapshot from the repository root:

```sh
source modules/jtframe/bin/setprj.sh
cores/s18/ver/ym7101_render/sim.sh \
  --mode passive --geometry 400x262 --scenario production_switch \
  --run-staged /nobackup/tasks/jtcores-180/production-switch-ym-run01
```

The reviewed run passed fast 384x260 → original 400x262 → fast 384x260. Each
request commits at the H511/vdump224 vertical-blank line boundary; the master
clock and 6/12 MHz pixel enables continue, with no VDP reset or MMR rewrite.
The YM mutes while geometry is invalid, reacquires, completes its 420-native-H
event prime, and resumes with quota 72 in fast mode or 40 in original mode.
The run checked settled and transition line/frame intervals, 224 active lines,
CPU status reads, and complete 320-pixel RGB/YS tuples on rows 0, 1, and 100
over two frames after each change. Rows 0/1 were patterned and row 100 was
transparent. The receipt, immutable source manifest, and terminal log are at
`/nobackup/tasks/jtcores-180/production-switch-ym-run01/terminal-receipt.txt`
and `run.log`.

The real-S16 `cores/s18/ver/video16_timing` simunit independently passes the
actual S16 char, both scroll planes, object scanner/drawer, priority and DAC
path. It compares 320 active coordinates on each of three rows between static
original and fast operation, then checks both live fast→original→fast changes.
Its deterministic memory responders use four-clock address-tagged data and
cached-valid level acknowledgements. The fixture programs legal row/column
scroll MMRs, exercises two visible objects and a dense 62-object list, and
checks each profile's H128 `done` and terminal line-buffer write to address 511,
sprite completion before H129, `scr_bad`, row/column latches, active endpoints,
and nonzero selected data from every layer. See
`../video16_timing/README.md` and
`/nobackup/tasks/jtcores-180/video16_timing/simunit-final.log` for its bounded
scope and result. Together these focused runs establish the production timer
switch and tested S16 graphics-fetch budget; they do not establish whole-game
compatibility or hardware behavior.

The separate 40-frame quiet SiDi128 boot stopped at the nonblank Sega copyright
warning screen at 60.10 Hz; it does not reach the full attract sequence. The
later 781-frame Astormj boot-and-coin run is documented in
`cores/s18/doc/passive-vdp.md`. Updated MiSTer, SiDi128, and Pocket release
fits/STA for this timing integration are still pending.
