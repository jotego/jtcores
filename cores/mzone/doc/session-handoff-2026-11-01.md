# Mega Zone session handoff — 2026-11-01

Read this file before continuing work after a restart. It records the final
implementation, decisions, validation, and remaining limits of this session.
The working tree is uncommitted; preserve the existing changes. No commit was
created during this session.

## Workspace and restart setup

Repository: `/home/skutis/github/jtcores-private`.

```sh
cd /home/skutis/github/jtcores-private
source ./setprj.sh
export VERILATOR_ROOT="$HOME/github/verilator"
export PATH="$VERILATOR_ROOT/bin:$PATH"
export JOTEGO="$HOME/jt-support"
export CCACHE_DISABLE=1
export CCACHE_DIR=/tmp/mzone-ccache
```

The installed Verilator used successfully is **5.050**. An earlier 5.046 build
had simulation image problems. Do not restore old JTFRAME/C++ port workarounds:
JTFRAME is unchanged in the final working tree.

For simunits with `init.go`, the working local Go environment was:

```sh
export GOROOT="$HOME/go/pkg/mod/golang.org/toolchain@v0.0.1-go1.23.4.linux-amd64"
export PATH="$GOROOT/bin:$PATH"
export GOCACHE=/tmp/mzone-go-cache
```

The default Go 1.21.3 installation gave missing-standard-package errors when
running fixture generators. The cached 1.23.4 toolchain above worked. Icarus
is 10.3. It runs the Mega Zone simunits, but cannot parse existing shared drawer
scaling tests' old-style string task arguments / `$sformatf`. Temporary diagnostic-
formatting compatibility copies were used to run those checks earlier.

`ROM` is set by `setprj.sh`; the local Mega Zone ROM is
`/home/skutis/github/jtcores-private/rom/megazone.rom` (127584 bytes). ROMs and
captures are local support assets, not files to add to Git.

## Final implementation: full-speed object rendering

The user explicitly approved applying the simpler full-speed implementation
after all captured frames matched. This is already applied, not just a prototype.

- `hdl/jtmzone_obj.v`: scanner runs on every master clock, waiting on drawer
  `busy`. The internal DMA render table uses `jtframe_dual_ram32` so one read
  returns all four object attributes. The byte-wide DMA still copies 240 bytes
  with its original pixel-clock-qualified start/copy schedule. Byte write enables
  select the appropriate lane in each packed entry.
- Scan order remains **35 down to 0**. `scan_obj <= scan_obj-1'b1` moves to the
  preceding entry, guarded against decrementing below zero. Lower-numbered
  sprites draw later and their opaque pixels overwrite higher-numbered sprites.
  Do not reverse this ordering casually; it preserves overlap priority.
- Scanner states are `IDLE`, `LOAD`, `CHECK`, `START`, `WAIT`. The load cycle
  permits the synchronous table read to settle. `WAIT` checks the registered
  draw request was consumed before advancing attributes.
- `hdl/jtmzone_objdraw.v`: uses the **existing, unmodified `jtframe_draw`** at
  master-clock speed. No `cen2` port, paced emission counter, or extra eight-pixel
  staging buffer remains. It retains the original circular `jtframe_obj_buffer`
  readout and synchronous palette-before-buffer write path.
- A previous implementation added a JTFRAME `clk_en` port, then a later version
  staged eight pixels to preserve exact old timing. Both approaches were removed
  at the user's request. Do not reintroduce either as the current design.
- JTFRAME, Flstory and Gals Panic have no residual changes from these experiments.

### Naming and ROM wiring agreed with the user

Object signals now use JTFRAME/Slap-style names:

- `helper_x` became `buf_addr`.
- `helper_we` became `buf_we` (redundant alias removed).
- `helper_pixel` became `buf_pred`.
- Object `planes` became `rom_sorted`.

The generic ROM address is byte-indexed:

```verilog
wire [14:2] draw_addr;
assign rom_addr = {draw_addr[14:7],draw_addr[5],draw_addr[6],draw_addr[4:2]};
```

This preserves Mega Zone's `{code, row_msb, half, row_lsb}` ordering. Do not copy
Slap Fight's literal permutation: its ROM layout and code width differ.

The object ROM bit permutation is now four explicit `rom_sorted` byte
assignments, with no nested generate loops or conditionals. All 32 one-hot
input bits were checked against the previous wiring, proving the same mapping.
Existing `mem.yaml` `gfx_sort` options permute addresses, not these bits within
a ROM word.

### Why the palette stays before buffer writes

`jtframe_objdraw` hides its pre-buffer data ports. Applying the object palette
only after its buffer incorrectly changes overlap transparency: a nonzero raw
pen may overwrite an existing sprite before mapping to transparent color zero.
The actual Mega Zone object PROM has three such nonzero-pen mappings. An earlier
generated test found 1,358 differing samples with that plain-wrapper approach.

`jtframe_objdraw_gate` exposes `buf_pred`/`buf_din` and supports a delayed palette
path, but the final implementation uses `jtframe_draw` plus the explicit buffer.
It preserves the finite circular read/erase interval and eight-bit X reversal.

## Other completed changes carried in the working tree

- FIX uses native `jtframe_tilemap`; SCROLL uses native `jtframe_scroll`.
  PCB coordinate mapping, flip, source/priority windows and blanking adaptation
  remain in the core. Detailed reasoning is in `doc/renderers.md`.
- Removed `jtmzone_charpal.v`; plane wiring and palette instances are inside
  the renderers. Removed the earlier custom tilemap phase adapter as well.
- Fixed debug control mapping: `gfx_en[0]` is FIX, `[1]` is SCROLL.
- CPU-visible video/shared RAM is declared in `cfg/mem.yaml`; video registers
  are declared in `cfg/mmr.yaml` and generated as `jtmzone_video_mmr.v`.
  Generated MMR files must not be committed.
- Standard `jtsim -s` restoration is supported. `ver/game/sim.sh` changes into
  `ver/<setname>` and invokes the standard workflow, default set `megazone`.
- `NOMAIN` handling is inside `jtmzone_main`, which is always instantiated.
  Its ROM ports are `main_addr`, `main_cs`, `main_data`, `main_ok`, connected
  directly without redundant `main_rom_*` aliases.
- `.beta.yaml` includes `mzone` for MiSTer and Pocket.
  `cfg/macros.def` declares `JTFRAME_RATE=60.61` (measured simulation rate).
- Handwritten core HDL has copyright/license/date headers crediting Ulf
  Skutnabba, retaining contributor attribution in the README.
- All **11 handwritten HDL files** have uniform four-space indentation,
  declaration alignment and named-port spacing. Generated MMR files and frozen
  test references were excluded. Formatting was verified whitespace-only.

## Simunit workflow and validation

Run from the repository root after the environment setup above:

```sh
simunit.sh --run cores/mzone/ver/video_width
simunit.sh --run cores/mzone/ver/scene_restore
simunit.sh --run cores/mzone/ver/tilemap_equiv
simunit.sh --run cores/mzone/ver/obj_equiv
lint-one.sh mzone -mist
```

Custom Python launchers for width/restoration were replaced with standard
`.simunit`, `test.v`, `gather.f`, and optional `init.go` preparation. Automated
tests never invoke MAME. See `ver/README.md` and each test's README.

- Width: all four width/flip settings and unchanged HS/VS passed.
- Restoration: generated synthetic dump passed with and without `NOMAIN`,
  including CPU RAM/register ports, idle outputs, ROM decode, IOCTL and reset.
- FIX/SCROLL: 512 generated scenarios passed; 1,769,472 timely RGB comparisons,
  3,538,944 control/blanking checks and 589,824 missed-deadline zero-fill checks.
  This was before the final whitespace-only formatting pass.
- Objects: 128 independent logical sprite-compositor cases passed, including
  overlaps, palette transparency, X wrapping, both flips, ROM delays and read/
  erase. 147,456 scoreboard pixels passed. Frozen original sources remain in
  `ver/obj_equiv/reference/`, with their original SHA256 comments intact.
- Full object pipeline: exact DMA checks plus **45,312 final-pixel comparisons
  before any HS overrun** passed. Busy/ROM phases deliberately differ now.
- Sound-enabled lint passes, including after final formatting.
  The earlier missing `modules/jt12/cfg/jt49.yaml` problem was resolved by
  initializing the jt12 submodule; it is no longer a blocker.

### Important limitation: HS overrun stress is not equivalent

Do not claim universal equivalence or silently describe these diagnostics as
passing pixel comparisons. At generated 63-master-clock ROM latency, the
full-speed scanner differs from the original by **1,668 pixel-enable samples**:
687 non-flipped and 981 flipped. Explicit HS-mid-write cases also report
96 differing master-clock samples. Busy and fetch timing differences alone
are acceptable; these particular stress differences reach pixel output.

The final simunit requires equality until a draw in either implementation spans
HS. Once that deadline is exceeded, subsequent differences in that case are
counted and printed as diagnostics; they are not asserted equivalent. The
original slower renderer is not treated as a universal overrun oracle.
Delays 0, 1 and 9 clocks produced identical pipeline pixels.

A trace confirmed what the synthetic test permits: object code 02, circular
address 66, is written at H=287/V=20/bank 0 by the fast version and H=6/V=21/
bank 1 by the old version, across an HS switch. The later scan also uses a
new vertical sub-row. The user challenged the statement that sprites could
land on another line: distinguish this observed FPGA-model overrun behavior
from a claim about the physical PCB. The intended hardware overrun/drop policy
has **not** been independently established.

## Full captured-frame comparison

**All 15 saved PNGs match the original object implementation exactly**, using
local captures `989`, `1141`, `grid`, `972_flipped_2p`, and `legacy989`, with
frames 1, 3 and 4 from each capture. This includes startup images and the flipped
two-player scene. MAME supplied RAM/register dumps; its own rendered image was
not the pixel reference. The reference was the core's original custom object
renderer with the same tile renderers and scene input.

Persistent results and paired PNGs:

- `/home/skutis/github/mzone-fullspeed-applied-comparison/README.md`
- `/home/skutis/github/mzone-fullspeed-applied-comparison/report.json`
- `/home/skutis/github/mzone-fullspeed-applied-comparison/runs/`
- `/home/skutis/github/mzone-fast-object-experiment/README.md`
- `/home/skutis/github/mzone-fast-object-experiment/write-trace.log`

The full comparison was rerun after applying the full-speed implementation.
Subsequent changes were signal naming, mathematically equivalent ROM-address/
plane wiring cleanup, and whitespace; lint was rerun. No additional change in
rendering behavior is expected from those cleanups.

Do not trust stale executables when doing a fresh comparison. Earlier, an
executable built before a FIX edge correction falsely suggested a 394-pixel
flipped-scene mismatch; rebuilding removed it. Always rebuild current RTL.

## Scene assets and user preferences

**Do not commit any `.bin` or `.hex` files.** The core has ignore rules for them.
Old private scene binaries are intentionally deleted in the proposed changes;
the local `scenes/989/dump.bin` is preserved but ignored, not a proposed addition.
Default CI data is generated in `init.go`, not encoded game captures.

Use `$JOTEGO/scenes/mzone/megazone/<scene>/dump.bin` for normal scene playback.
The 7172-byte format is five 1 KiB RAMs, 2 KiB shared RAM, followed by four bytes
`scrolly, scrollx, flip bit 0, reserved`. The standard command is:

```sh
cd cores/mzone/ver/game
./sim.sh -s 989
```

Local MAME captures used for comparisons also persist at:
`/home/skutis/github/mzone-scene-comparison/scenes/mzone/megazone/<scene>/dump.bin`.
`989` there is a new MAME capture (scroll Y=EE); `legacy989` is the older title
capture. Grid RAM matched all five recorded grid hashes; the two-player capture
has its flip latch set. `game/scenes/capture.sh` is an optional fixture-capture
tool, not an automated simulation runner. Installed MAME is 0.220; the script
reads scroll shares and the saved LS259 latch where write taps are unavailable.

For an optional real capture in the restoration simunit:

```sh
MZONE_SCENE_DUMP="$JOTEGO/scenes/mzone/megazone/989/dump.bin" \
    simunit.sh --run cores/mzone/ver/scene_restore
```

`MZONE_SCENE_DUMP` is a core-local test option, **not** a standard JTFRAME setting
and not used by `jtsim -s`. The default test remains generated synthetic data.

## Continuing tomorrow

1. Read this handoff, `doc/renderers.md`, and `ver/obj_equiv/README.md`.
2. Inspect `git status --short` and the current diff; preserve all pre-existing
   changes. No renderer replacement is pending: the full-speed version is applied.
3. Set the environment and run the relevant standard simunits/lint before further
   behavioral changes. Keep frozen reference sources unchanged.
4. If comparing scenes again, rebuild from current RTL, use identical external
   dumps for both builds, and compare actual PNG pixels, not file timestamps or
   compressed PNG bytes. No MAME execution is needed to replay saved captures.
5. Any further change to line deadlines/overrun handling needs an explicit
   decision or PCB evidence. Do not infer that `cen2` was a proven hardware clock
   requirement, or that 15 matching captures prove all possible frames equivalent.
6. Review the final diff before committing; exclude generated MMR/build artifacts
   and every binary/hex capture. No commit or push was requested this session.

Persistent log/status bundle:
`/home/skutis/github/mzone-session-2026-11-01/`.
Anything under `/tmp` is disposable and must not be the sole record after restart.
