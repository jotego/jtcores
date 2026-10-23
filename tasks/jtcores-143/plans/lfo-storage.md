# LFO depth storage and write ordering

Finite measurements for [jtcores #143](http://gitea.jotego.es/jotego/jtcores/issues/143).
Production jt51 remains unchanged at `985a573`; this is measurement work.

## Stimulus and observable

Yamaha's application notes, printed 11/PDF 12, define register19 bit7 as the
selector for independently stored seven-bit AMD and PMD. The tested question is
whether writing the inactive branch changes the active branch's modulation or
global LFO phase. Two complementary positive controls deliberately write the
active depth, and two combined controls reverse the final INIT depth ordering.

All eight complete programs use C0/W2, KC4A, MUL0, AR31/KS0, D1R0/D2R0, TL0,
ALG7, no feedback/audio noise, and only channel0/C2 keyed. Native increment 4124
becomes retained increment 32992 at stride 8; the nominal recorded rate is
6992.1875 Hz and each recording has 16384 stereo frames. TEST01=02 holds the
LFO during INIT; EVENT waits 8192 loop counts and releases TEST with 01=00.
Only the designated TEST bit is used.

| Case | Active path | Writes under test |
|---|---|---|
| `am-cross-pmd` | AMD64, AMS1, AME1, PMS0 | PMD64,127,0 |
| `am-null` | Same AM path | No depth writes |
| `am-own-amd` | Same AM path | AMD0,127,64 |
| `pm-cross-amd` | PMD64, PMS4, AMS0, AME0 | AMD64,127,0 |
| `pm-null` | Same PM path | No depth writes |
| `pm-own-pmd` | Same PM path | PMD0,127,64 |
| `combined-amd-first` | AMD64/PMD64, AMS1/AME1/PMS4 | AMD then PMD in INIT |
| `combined-pmd-first` | Same final combined state | PMD then AMD in INIT |

The three existing pan87/C7 intervals mute LEFT/latch0 while RIGHT/latch1 stays
audible. Each target register19 write occurs 256 loop counts into a mute. Mute
delays are 1024/2048/1024 counts, separated by 4096 counts; total EVENT delay is
28672. Null controls omit only the target depth writes and preserve all delay
pieces and pan writes. Extra writes change bus execution time; marker edges
bracket interventions but do not establish exact cross-device event latency.

Generate fresh inputs from the canonical both-pan tone:

```
go run host/lfo_storage_programs.go -base artifacts/fresh-tone.bin -output artifacts/fresh-storage
```

The promoted Go generator reproduces every original payload byte and manifest
field except output paths. Full 224-register/global/key/depth-selector checks,
literal EVENT decoding, sixteen-payload reproduction and 36 malformed-base/CLI/
reused-output rejection checks pass. The frozen measured manifest SHA256 is
`6910016d9081093d580b1970a48f52c340681aa3732d9a4b6a931da5865f21ca`.

## Qualified features and retained failure

RIGHT is processed with a separate 129-point **squared-Hann** weighted
sine/cosine/DC projection: if h is the Hann vector, the least-squares weights
are h². Centers advance by 8 retained samples. One unwrapped carrier-relative
phase supplies cents through a central difference at ±16 retained samples.
This is a different kernel from the earlier 128-point Hann-weighted joint
estimator; its qualification is not transferred between them.

The independent synthetic proof integrates phase at every native sample before
stride 8, with stepped triangle modulation, arbitrary carrier/LFO phases,
16-PCM quantization and ±32-master-clock stereo latch ages. Thirty-six cases
cover gate, AM64, AM127, PM64, PM127 and moderate combined modulation. The
original guards are AM RMS 0.08 dB/max 0.3 dB, PM RMS 1 cent/max 3 cents and phase
RMS 0.005 rad. The overall result remains **`all_guards_pass:false`**.

The permanent `host/lfo_projection.go` implements this exact 129-point kernel,
without changing the earlier joint tool. Direct comparison covers all 36 original
synthetic signals, 16 model outputs and 24 physical curves, with no phase-origin,
gain or time adjustment. Maximum differences are 1.18e-11 PCM amplitude,
1.60e-14 dB, 4.55e-13 rad phase and 1.27e-10 cents. This numerical equivalence
reproduces the feature calculation; it is not model/PCB sample identity.

```
go run host/lfo_projection.go host/tone.go -column linear -csv artifacts/fresh-storage-curve.csv artifacts/capture-0-1.csv
go test host/lfo_projection.go host/tone.go host/lfo_projection_test.go
```

Use `-column right` for model CSVs. Constants and support are explicit in the
output metadata: AM/phase half-support 64 samples and cents half-support 80.
Below 64 PCM there is no logarithm; below 512 PCM no phase. Invalid phase gaps
start a new segment, and cents never cross a gap. Output files must be fresh;
input/curve hashes, malformed-input checks and quiet/gap controls are retained.
Tracked independently integrated Go tests reproduce the same 36-case guards,
including the six unqualified AMD127 corners rather than relaxing their limit.

Six AMD127 cases exceed the unchanged corner max-error guard, reaching 0.37423 dB
with RMS 0.07077 dB. Precise AMD127 extrema and instantaneous write transitions
remain unqualified. The other 30 cases pass their guards. At moderate combined
12 dB/±25 cents, worst AM RMS/max error is 0.03549/0.18740 dB, PM RMS/max error
0.18015/1.27569 cents and phase RMS 0.001168 rad. Isolated PM≤49.6094 cents also
passes. These are finite-grid observations, not universal analytic error bounds.

Physical comparisons use same-device null templates or the normal combined
ordering. One common observed late period is 2048.03999 retained samples;
individual late fits span 2047.98569–2048.09392. Each recording has one global
phase shift fitted only after all writes, samples 5000..14000, with 3000..4800
held out. Combined AM and PM share the same shift. There is no gain adjustment,
per-event phase fit, model waveform template or time warp. This coherent fit
is separate from the independently crossed period scores in the E0 matrix.

Independent alignment controls recover three known shared offsets within
0.000119 cycles. A quarter-cycle relative AM/PM error cannot be removed by one
shared shift, guarding against separately aligning the two modulation paths.
The 33-point raw interior residual diagnostic checks shorter PCM disturbances.

## Results and scope

All 24 physical recordings pass independent input/transfer hashes, framing,
exponents, requested counts, bipolar audio, generation/reply continuity and
the three LEFT marker checks. Recorder count ends at 144; subsequent silence
succeeds at generation 218/marker 147. No reset, ROM reload or dropped reply is
needed. All 16 whole-model outputs pass their exact-input/cadence/sidecar audits.

| Physical triplicates | Marker residual to coherent null | Corresponding null |
|---|---|---|
| AM cross-PMD |0.06794–0.06915 dB RMS|0.06673–0.06792 dB|
| PM cross-AMD |0.1980–0.2496 cents RMS|0.1779–0.2102 cents|
| Combined AMD-first |AM 0.06681–0.06851 dB; PM 0.2083–0.2276 cents|One shared phase|
| Combined PMD-first |AM 0.06758–0.06818 dB; PM 0.1966–0.2102 cents|Same method/template|

These finite observations support preserved active depth and global LFO phase
during the tested opposite-selector writes, and equivalent final modulation
for both INIT orders. No storage discrepancy is assigned at this resolution.
This does not establish physical byte identity or all-depth/channel/history
conformance. The raw marker-interior residuals likewise stay near the nulls.

Own-depth positives are scored separately, excluding 80 samples around mute
edges and retaining 17–18 complete interior feature points. AMD0 gives median
attenuation −0.0021..0.0014 dB versus null 2.21..2.34 dB; AMD127 gives 5.74..5.91
versus 2.94..3.01 dB. These demonstrate the direction of a finite attenuation
change, not a complete excursion or a precise maximum. PMD0 gives 0.0189..0.0345
cents RMS versus null 8.49..8.81; PMD127 gives 24.28..24.92 versus 12.39..12.71.
All return to ordinary depth 64 late, with residuals comparable to the nulls.
Temporary PM accumulates a carrier phase offset; raw phase need not return.
Abrupt AMD-write transition windows are not interpreted as PM coupling.

Within each model, the combined INIT-order pair is stereo byte-identical.
jt51 cross-depth RIGHT is also byte-identical to its null. OPM has one 80/112-PCM
sample difference inside the changed pan boundary, with none outside either
mute window. Those descriptive differences remain recorded without correction;
the physical/model CPU delays do not support event sample-identity claims.

The [storage-control figure](http://gitea.jotego.es/attachments/840ff980-720a-4555-b113-92bf3d4d4c0a)
shows one representative physical recording per case, its same-device null
prediction and observed LEFT mute brackets. Time is unwarped; smooth transitions
retain the 18.45 ms AM/23.03 ms PM support and do not establish write latency.

## Evidence and remaining work

Local immutable inputs, raw captures, model outputs and analysis are under
`artifacts/lfo-storage`: `programs/cases.json`, `permanent-generator-validation.json`,
`physical/{physical.json,qualification.json}`, `reference/{reference.json,audit.json}`,
`synthetic/qualification.json`, `physical-analysis/{features.json,provenance.json}`
and `PHYSICAL-REPORT.md`. The Go kernel equivalence and tracked tests are recorded
in `artifacts/lfo-projection/{equivalence.json,validation.json}`. The original prototype/projection scripts remain local
evidence; original hashes and failed guards are preserved.

Remaining LFO work includes hold/reset/free-run/key-on history, channel/operator
isolation, rates beyond E0/C0 and weak-noise resolution. Slow partial advancement
must not become an observed complete cycle by assumption. Broader audio-noise,
algorithm/feedback, CSM, envelope KS/KC/history and mixing/clipping work remains.
