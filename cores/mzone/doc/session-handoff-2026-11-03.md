# Mega Zone session handoff — 2026-11-03

Resume with the warning review below. See also the November 1 handoff for
renderer design decisions, previous frame comparisons, and stress-test limits.

## Build and hardware

- Latest commit reviewed: `45ce3b684` (`mzone core`, November 2).
- Initialized missing `modules/jt12` dependency to resolve missing `cfg/jt49.yaml`.
- Fixed `outputreg` to `output reg` in `hdl/jtmzone_video.v`'s optional
  `MZONE_FETCH_DIAG` port. SiDi128 lint passed after the fix. Preserve this edit.
- User built SiDi128 successfully: 0 errors, 86 warnings, JTCORE PASS;
  18,350 logic elements and 166,040 memory bits. Build finished at 23:14 CET.
- Output: `release/sidi128/jtmzone.rbf` relative to the repository root.
- User confirmed this build works on SiDi128. Detailed HDMI alignment, flipped
  mode, width selection, sprite and audio checks were not individually confirmed.
- MiSTer needs testing of this renderer revision; Pocket remains untested.

Build from repository root:

```sh
source ./setprj.sh
jtcore mzone -sidi128
```

## Fresh automated results reported by the user

Verilator 5.050 is available after:

```sh
export VERILATOR_ROOT="$HOME/github/verilator"
export PATH="$VERILATOR_ROOT/bin:$PATH"
```

- `obj_equiv`: PASS; 128 cases, 977,049 protocol checks, 147,456 pixel checks.
  Full pipeline: 8 cases, 292,800 cycle comparisons, 1,920 DMA byte advances;
  45,312 exact pixel comparisons before overrun.
- Extreme-delay diagnostics reproduced: 1,668 differing pipeline samples and
  96 HS-boundary cycle samples. These are intentionally reported, not asserted
  equivalent. They are synthetic stress cases, not a known gameplay failure on
  SiDi128 or the PCB. Physical PCB overrun/drop behavior is unresolved. The test
  currently prints counts; it does not export images of the differences.
- `video_width`: PASS for all four width/flip combinations, HS/VS unchanged.
  Normal selection is 288; Original is 287 non-flipped and 288 flipped.
- `scene_restore`: PASS both NOMAIN and MAINCPU; RAM/register restoration,
  CPU ports and IOCTL dump checks passed.
- `tilemap_equiv`: previously passed, but no fresh result reported this session.

Remaining fresh test:

```sh
simunit.sh --run cores/mzone/ver/tilemap_equiv
```

## Warning review — next work

Inspect actual reports before classifying warnings. Only an excerpt of the 86
Quartus warnings was reviewed in chat; do not claim all are harmless.

1. Core PROM-offset width truncations: `jtmzone_video.v` lines 77–78 and
   `jtmzone_colmix.v` line 31. Expressions are 32 bits, destinations 22 bits.
   Verify values fit and consider explicit sizing.
2. Previously documented MiSTer/Pocket unconstrained paths and shared platform
   clock warnings. Establish which paths are legitimate exceptions and which
   need constraints; a JTCORE PASS alone is not complete timing closure.
3. Shared Quartus warnings shown: unused `xtal1_s` in T48 `clock_ctrl.vhd`,
   unused `balut_bit_addr` in `jtframe_dwnld.v`, and unconnected configured PLL
   outputs. Classify using actual connections and intended platform use.
4. Restoration simulation warnings: generated `jtframe_frac_cen` n/m constants
   narrowed from 32 to 17 bits, and mixed default/explicit timescales.
5. Fixture-generation message:
   `jtframe mem: cannot update file /tmp/mzone-mmr-.../mzone/hdl/jtmzone_game.v`.
   Both restoration variants passed, but establish why this message appears.

## Video-width question

`cfg/macros.def` declares `CORE_OSD=OE,Video width,288,Original 287;`.
`hdl/jtmzone_game.v` reads status bit 14 on hardware: 0 selects 288, 1 selects
Original. Simulations force this game-level option to zero; the dedicated
width test exercises all video-module combinations. User suspected HDMI pixel
shift on SiDi128; no cause was established. A saved firmware setting could also
affect the selected width. Do not describe either explanation as confirmed.

No commit or push was requested. Resume tomorrow; do not continue investigations
merely because this note lists outstanding work.
