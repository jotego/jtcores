# Candidate public-output recheck results

All work was offline. The PCB remained powered off. No original sealed task or
Drive case was changed. Candidate RTL was supplied and owned by ROOT; this
agent changed no RTL. Public replay harness is unchanged own
`tasks/jtcores-143/ver/jt51/test.cpp`; no third-party algorithm was inspected,
copied, translated or run in this recheck.

## Qualified results

- 31 initial stereo replays completed, actual session39440 exit0. Eight further
  boundary/geometry replays completed, actual session77604 exit0. All39 have
  16384 frames and the requested64×stride public-clock cadence, with pinned
  input bytes and candidate HDL. Three initial RR00/01/02 native short versions
  differ from their old stride64 geometry and remain explicitly partial
  diagnostics. Thus36 replay records match the intended archived geometry;
  no slow-duration claim is made from the three short records.
- All11 declared unchanged public-PCM checks pass exactly: five steady noise/
  NE-off cases and six constant/AM/PM pan-marker/control cases. The continuous
  RIGHT column is also identical between each candidate marker/control pair.
- Maximum-off noise passes its scoped new behavior: never-keyed is entire0,
  delayed KEYOFF final4096 samples are0, and finite AR24 retains a silent
  first512 prefix plus nonzero late output. TL127 remains exactly -9/+8 on
  both latches; noise00/0F/1F and NE-off sine retain exact old public PCM.
- D1L15 retains a nonzero transient and exact-zero final4096 on both latches;
  adjacent D1L14 retains nonzero tails.
- Automatic CSM-on produces bipolar output on both latches, including2325
  nonzero late4096 samples; CSM-off and no-Timer-A nulls remain entire0.
  Manual positive remains bipolar and nonzero late. The8429 changed stereo
  frames from old CSM-on silence are an expected correction, not a regression
  count. No IRQ-pin behavior is inferred from this audio.
- Thirteen measured EG duration features are inside the unchanged archived
  physical bands. RR15 remains the original `window_limited` state; no
  duration is invented for it. The original observer settings and eligibility
  remain distinct from raw capture validity.
- Eight selfcontained literal timer programs match the recorded physical
  statusbits1:0. Busy is not compared; twelve retained-history fragments are
  excluded from fresh-instance tests. No timer-audio claim is made.

| Public feature | Candidate duration ms | Original physical band retained |
| --- | ---: | --- |
| D1 raw12 |147.598955843|Inside|
| D2 raw12 |147.598955843|Inside|
| D1 raw22 |4.609473277|Inside|
| D2 raw22 |4.609473277|Inside|
| D1 raw23 |3.456063679|Inside|
| D2 raw23 |3.456063679|Inside|
| D1 raw24 |2.302908443|Inside|
| D2 raw24 |2.302908443|Inside|
| RR08 |27.344551731|Inside|
| RR00, original stride64/MUL0 |7028.778129905|Inside|
| Raw AR14 |46.034388017|Inside|
| Raw AR15 |33.985275924|Inside|
| Raw AR16 |22.496680078|Inside|

`features/summary.json` and
`supplement/features-exact-geometry/summary.json` contain exact bands, values,
observer commands, actual exits and source report content. RawAR30/31 in the
initial batch are highest-rate positives, not the effective30/31 boundary.
The raw14/15/16 supplement supplies the relevant lower attack comparison.

## Retained applicability errors and limits

The first optional timer replay tried a retained-history fragment in a fresh
instance. Its expected physical flag depended on an earlier enabled-overflow
command absent from that fragment. The attempt stopped; stdout and
`timer-physical-programs/applicability-failure.json` remain. A later separate
selection accepts only full programs beginning14=30. The root's dedicated
sticky-history timer suite is the appropriate verification of command chains.

The first long-RR observer call used a hardcoded nativeMUL8 increment, but this
fixture actually uses MUL0/native4124/stride64/retained263936. The unchanged
observer rejected the invalid projection settings. This failed call remains
under `supplement/features/`; the corrected caller reads exact frozen manifest
geometry and writes `features-exact-geometry/`. No model rerun, guard relaxation
or changed physical band was used to obtain the corrected result.

This is a bounded recheck, not full waveform conformance or a claim that all
JT51 behavior is correct. The known odd-MUL physical difference, relative
joint-key phase and high-level mixing remain unresolved pending the specific
controls in `offline-dispositions.md`. External OPM pan/carrier exceptions
remain reference-only conditional limitations. No other production fix beyond
the maximum-off noise behavior is established offline by this audit. Pitch
follow-up commands were documented but not launched. Rastan was not launched;
its compound stimulus remains last after isolated fixes and measurements.

## Authoritative new artifacts

All paths below are under
`/nobackup/tasks/jt51-16/artifacts/candidate-recheck-v1`:

- `replay-plan.json`, `replay-results.json`, `replay.log` and39 model CSVs/
  EVENT sidecars across the main/supplement directories.
- `noise-scoped-behavior-check.json`, `d1l-tail-behavior-check.json`,
  `csm-pan-behavior-check.json`.
- `features/summary.json`, `supplement/plan.json`, `supplement/results.json`,
  `supplement/features-exact-geometry/summary.json`.
- `timer-selfcontained/summary.json`, retained applicability failures,
  unchanged own observer builds and candidate build/source hashes.
- `FINAL-handoff.json` pins the final sources/reports and confirms the source
  HDL snapshot still matches the completed runs. All producer handles are
  terminal before that handoff; no more artifact writers remain.
