# Reproduce the 2026-10-19 serial investigation

The consolidated case is
`/gdrive/jotego/reverse/YM2151/2026-10-19-jt51-16-serial-controls/`.
Each compressed archive has an adjacent `.verification.json` containing the
archive SHA256 and every member's path, size and SHA256. Verify before extracting
into a new scratch directory. Earlier measurement cases remain sealed.

## Public production checks

From the published JT51 source checkout, use its existing silicon runner with
a fresh build directory:

```bash
JT51_SILICON_BUILD=/nobackup/tasks/jt51-replay/build \
    bash ver/silicon/sim.sh stereo_age_analysis
JT51_SILICON_BUILD=/nobackup/tasks/jt51-replay/build \
    bash ver/silicon/sim.sh stereo_age
JT51_SILICON_BUILD=/nobackup/tasks/jt51-replay/build \
    bash ver/silicon/sim.sh nominal_pitch
```

Expected counts are 23,160 and 5 respectively, with zero failures. The complete
`all` dispatch has 593 checks, including the unchanged 405 legacy checks.
The 32-route test is self-contained and needs no physical archive at runtime.
Its fixed carrier, residual, phase and quiet gates are described in
`ver/silicon/README.md`. Baseline 01110fd fails exactly16 measured age checks;
the rejected two provisional candidates fail the channel7 boundary checks.

## Physical evidence and rejected hypotheses

`stereo-assembly-analysis-v3.tar.gz` contains the prospectively frozen
`stereo-age-map-v1/` observer and all 96 reused physical records, plus separate
literal and raw-word/acquisition audits. Its report pins the exact commands,
source files and completed 405/seven-phase/three-noise validation. The final
physical slice uses original ordinals14336..16383, then128-point guards;
there is no per-record alignment or fitted carrier. LEFT-minus-RIGHT age
is measured within each recording. The independent public regression uses
newly generated public samples with the same stride/window/screens.

The original AM-enable bit is immaterial in these no-modulation fixtures;
canonical public INITs disable AM explicitly. Their complete literal preflight
matches the prospective 32 canonical fixtures, rather than claiming every
byte equals the older acquisition programs. Saved physical programs remain
archived exactly as acquired.

`pitch-anomaly-experiment-and-nominal-v1.tar.gz` retains the experimental
−8192 patch, all 243 bench-case and 542 composed-check successes, and the
primary Yamaha documentary example that rejects its production generality.
The nominal five-check guard passes ordinary JT51 and fails that experiment
in four checks. Do not apply the experimental patch to production to reproduce
normal nominal tuning.

`raw-pitch-crosscheck.tar.gz` contains 12 valid mode1 recordings and independent
bit-center decoding. Raw mode1 exposes un-inverted pin values; inversion 15
is applied exactly once. It uses the CAP02 revision2 header and completed
status0x6 despite the native protocol 960104. The first two schema-assumption
failures are retained separately. Native mode3 was restored afterward.

## Consumer tool compatibility

The installed Verilator 5.018 rejects JTFRAME's `--quiet-stats`. The task-local
wrapper removes only that argument and invokes the pinned installed binary;
it changes neither warning handling nor RTL. Consumer lint and Contra build
use `VERILATOR_ROOT` pointing to the archived compatibility directory.
JT51's standalone runner above does not need this workaround.

The initial wrapper-free consumer attempts failed at the unsupported option,
not at RTL compilation. They are retained. The corrected full-tree lint has
98 logs/12 skips and exactly the baseline19 diagnostic lines, including
repeats; exit1 and the four unrelated core errors are explicitly preserved.
The consumer build records hashes of every included JT51 RTL file before
and after compilation. Generated version metadata can predate the final
source commit; these byte-level pins establish the implemented source.
