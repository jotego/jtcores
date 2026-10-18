# Measurement gap inventory

The bounded Diet Go Go direct-serial campaign for
[jtcores #143](http://gitea.jotego.es/jotego/jtcores/issues/143) is recorded below.
Production jt51 remains at `985a573dcfc1ff135553a39f7eae21d18ba57cbe`.
Six physically supported implementation requirements are consolidated separately
for review under the user's [jt51 #3 instruction](http://gitea.jotego.es/jotego/jt51/issues/3).
No RTL change or candidate patch has been made. Broader finite limits and untested
combinations retain their stated limits. [Reconciliation](reconciliation.md)
accounts for the earlier issue rounds on the replacement bench. Their essential
remaining input is the unavailable exact Rastan prefix; jt51#7/#8/#13/#3 stay open
and #14 stays blocked. Historical checkpoint schedules below are superseded by
the completed finite supplements, without changing their original results.

| Observation | Classification | Evidence and limit |
|---|---|---|
| Disabled timer overflow still creates jt51 status flags | Confirmed production gap | All 16 controls, 3 physical repetitions; 7 disagreeing control modes. Yamaha notes and OPM agree with PCB. |
| IRQ disappears when disabling an already-latched timer source | Documentation/reference discrepancy; physical IRQ unobserved | Standalone probe and independent OPM/ymfm review. Do not call it a physical IRQ measurement. |
| Effective attack rates 30/31 take an instant jt51 branch | Confirmed production gap | Four AR/KS configurations, physical repetitions and adjacent controls; phase/history variants and byte-preserving internal trace. |
| Raw zero AR/D1R/D2R loses inhibition after key scaling | Confirmed production gap | Isolated D1/D2 holds at all KS, AR0 negative controls plus AR1 positive control. Observable AR0 leakage at KS2/3 in native captures; three longer 18.74 s runs now confirm jt51 KS1 PCM leakage relative to the silent PCB, with an independent nonzero positive control. |
| D1L15 holds at nominal 48 dB in jt51 | Confirmed production gap | All 16 levels×3 physical recordings: 0–14 agree within 0.546 PCM units; 15 physical/OPM tails exactly zero, jt51 ±31. Primary Fig2.13 assigns nominal 93 dB. |
| D1/D2 attenuation granularity at rate12/KC4A/KS0 | Confirmed output-domain production gap | All six PCB captures and OPM have approximately 0.09375 dB resolved steps; jt51 approximately 0.1875 dB. Independent staircase/phase/window qualifications retain the difference. Average 80→40 timing alone can conceal it; no general all-rate claim or RTL patch. |
| PCB pitch fits a missing multiplier partial-product contribution | Unclassified physical/reference discrepancy | 243 cases after known reset; 114 differ by 8192. Bus/control/capture versus chip behavior remains unresolved. Both models agree; model voting does not establish the chip is defective. |
| Timer coarse periods | Consistent within declared bounds | 100 guarded observations at 10 preloads; first-overflow phase remains uncertain. |
| KS0 AR12–31 outside the rate30/31 gap | Consistent windowed attack features | Three physical repetitions per setting. Fastest attacks remain below projection-window resolution; no sample-identity claim. |
| KS0 AR1–11 slow attacks | Consistent windowed attack features | Three physical repetitions per rate, complete plateaus; stride 64/MUL0 retains KC4A and KS0. Window 36.61 ms; no full AR/KS/KC claim. |
| KS0 D1R/D2R0–31 and RR0–15 | Finite feature coverage with resolution/phase limits | 270 physical recordings including configured-key-on complements; 69 baseline feature agreements, 2 finite holds, 15 resolution-limited cases, 2 unresolved peaks. Two fixed-phase rate12 outliers require the recorded starting-phase qualification; no additional timing defect inferred. |
| Selected stage writes and key history | Consistent finite observations | 48 physical recordings with active/opposite-edge controls; global carrier continuity on held/repeated-key tests; early/full release features guard against concealed intermediate restart. Later retriggers/full KS/KC coverage remain. |
| E0 LFO waveform and disabled-path pilots | Consistent finite output features | 42 physical captures and 28 references; deterministic periods measured independently, native W3 retained without a period claim. Moderate combined W2 AM/PM is separately qualified. No exact sample-identity claim. |
| E0 AMD/AMS/AME boundaries | Consistent finite features with quantization limits | 128 cases, 384 physical captures, 256 model outputs. Observation states agree; 384 deterministic model endpoint checks fit common synthetic/decoded-quantum screening bounds. Deep exact-zero holds remain censored. |
| E0 PMD/PMS boundaries | Consistent deterministic features; one weak-noise resolution boundary | 224 settings, 672 physical captures, 448 references. All 672 deterministic endpoint checks fit the frozen finite-grid screen; all 465 resolved periods contain E0 within measured bounds. W3/PMD1/PMS6 retains one unresolved repeat at its activity floor. Full-depth square half-span approximately 794 cents agrees across PCB/models despite the printed nominal 700; no jt51 gap assigned. |
| C0 AMD/PMD storage and INIT order | Consistent finite observations | Eight cases, 24 physical captures and 16 model outputs. Opposite-selector writes preserve the active modulation, own-depth positives change it, and both final INIT orders give equivalent moderate combined state with one shared AM/PM phase. The 129-point squared-Hann method retains six synthetic AMD127 corner failures; precise deep extrema remain unqualified. No byte-identity or exhaustive history claim. |
| C0 channel/operator AM/PM routes | Consistent finite output features | All 32 routes independently calibrated with 96 PCB negative-probe baselines; 192 isolated AM/PM positives and 128 models pass stable-state/period checks and all 256 fixed endpoint screens. No simultaneous-voice or arbitrary-setting qualification. |
| Selected C0 LFO hold/reset/key history | Consistent finite observations | 36 PCB recordings; all 21 ordinary pre/post comparisons fit fixed screens, all nine intentional resets are detected independently of their good post fits. Three whole holds and three final-silence controls get no forced period. Two-sample changes remain unresolved; wider histories remain. |
| Twelve fast LFO rates, C0..FF selection | Consistent finite physical period diagnostics; one retained reference-carrier exception |Separate carrier7/AM73 stages give80 physical captures,39 targets41 entire-zero quiets including two final quiets. All6 physical carriers and72 coarse/fine AM observations qualify under unchanged guards; max endpoint-span error0.097709%, propagated bound0.585938%.26 stereo model outputs retain OPM RIGHT carrier relative RMS0.004426>.003, making its12 AM results conditional. No all256-rate/hidden-counter claim. |
| Audio-noise codes and selected isolation/level controls | Consistent finite sampled features | All 32 codes×3×2 outputs retain compatible candidate lattices and −2044/+2040 PCM levels. Codes30/31 hidden clocks remain unresolved. Sine/isolation/TL/attack/NE controls retain their own states; no seed/full-period or universal-noise claim. |
| NEon off-envelope PCM floor | Reproduced physical/public-output difference; cause unclassified | PCB exact 0 in never-keyed, KEYOFF-tail and pre-AR24 controls; jt51 −1/0 (inside frozen 4-PCM screen), OPM −8/0 (six endpoint outliers). 45 raw-pin recordings independently confirm zero and keyed −9/+8 low-bit visibility. Ten additional warm/long-settle model controls preserve both floors while NEoff controls produce zero. Short-prefix endpoint limits remain; no inferred RTL fix. |
| Algorithm/key-mask/feedback/stereo matrix | Finite routing and public-output coverage; no general arithmetic pass | 229 profiles times three targets with independent paired quiet,1374 matrix records.1092 target-latch observations bipolar and282 exactzero match primary state policies.458 frozen model outputs and2748 target-latch/model comparisons retain absolute descriptors; high feedback is not forced periodic and2/17PCM synthetic guards are not chip bands. |
| Joint-key-on relative output phase | Unclassified physical/model output difference | 36 physical controls retain approximately+1-native-sample M2/C1/C2 phase relative to M1, across order/preheat/repetitions.192 public timing-grid model records give zero/negative JT families and zero OPM RIGHT family. Accepted physical write phase/internal state remains unobserved; no per-operator correction or causal RTL gap inferred. |
| Automatic CSM output at the measured settings | Confirmed public-output production gap | All32 channel/operator routes independently calibrated by192 manual carrier/crossing checks and48 whole-zero background observations. All192 automatic PCB outputs resolve repeated cadence supporting512 native frames; corresponding jt51 outputs are quiet, OPM repeats with overlapping support. Selected256/1024 and AR30 controls support the finite observation.544 total CSM recordings include all paired/final quiet and adverse controls. No exact attack/pulse width, internal cause, simultaneous internal-key or physical IRQ claim. |
| Static contributor/TL/pan/split output matrix | Finite descriptive coverage; overload mechanism unclassified |63 profiles×3 targets/paired quiet,378 matrix captures+2 final quiets and1 separately recovered quiet=381 physical.342 bipolar/36 intentional-zero target-latch observations match pan states.126 frozen models/756 comparisons retain absolute populations/RMS/jumps; unknown voice phases prevent exact ideal-sum closure or a clipping/wrapping diagnosis. Common-held-history controls remain separate. |
| Held-key TL changes with matched no-op/N1 controls | Reproduced physical/model output difference; mechanism unclassified |Six profiles×3 targets with18 paired quiet and one final quiet=37 captures;12 frozen stereo model outputs. All18 geometries and18 actual reference links resolve. N32/TL0 middle RMS27801.387–27913.611PCM versus JT31866.748/OPM27187.713; low return prediction, no-ops and second-low TL40 transfers are retained. No high-region fit or new band. N1-scaled coordinates remain conditional; individual phases and exact latent sums are unknown. |
| Stereo pan controls | Qualified for current wiring; earlier human labels corrected | Primary ACC notes: bit6 left, bit7 right. Actual captures map latch0 to left, latch1 to right. Old left/right artifact names were reversed; latch indices and both-pan results remain intact. |
| Output-visible pan markers | Scoped physical continuity; reference-only output difference retained | Nine physical captures have three left/latch0 zero pulses and continuous right/latch1 output. Constant right carrier has an unbroken phase fit. Separately qualified local/coherent diagnostics find no PCB disturbance at the observed OPM pan-only error scale. No physical same-clock counterfactual, byte-identity claim, oracle patch or causal diagnosis. |
| Transient SH framing disturbance | Acquisition anomaly, retained and excluded | Two earlier failed recordings; all accepted pitch/event recordings pass framing and transfer checks. No causal conclusion about probing/wiring. |
| Selected noise history and LFO/noise coupling | Consistent finite sampled states/supports; no new gap | Four profiles×3 targets with13 entire-zero quiets=25 captures. N0/N1 preserve compatible sampled lattices/levels; N2 has no resolved modulation, not measured period0. N3 retains finite cadence/original±64 support, without sequence/internal-clock inference. |
| Split manual/automatic CSM coexistence controls | Finite support for the existing confirmed CSM output gap | Three profiles×3 targets with10 whole-zero quiets=19 captures plus9 separate STATUS1 queries. All six C2 manual/null controls qualify; RIGHT zero PCM retains actual raw low bits. C3 manual LEFT stays held; C3 RIGHT/C4 both outputs resolve cadence supporting512. No new mechanism/IRQ/first-load claim. |
| Low-LFO finite complements | Coarse full-period and partial-only output evidence, with precision limits | Four profiles×3 targets plus14 whole-zero quiets across two stages=26 captures. All six L2 own carriers qualify independently. Six rate60 coarse periods support1024 retained samples; all six original fine screens remain unqualified (about2.34375% propagated bound). Six rate00 partial changes and six held controls retain periodnull; no256-rate/hidden-update extrapolation. |

## Completed reconciliation supplements

| Observation | Classification | Evidence and limit |
|---|---|---|
| Dense TL/KF/KC and live ordering | Bounded characterization; no additional confirmed gap |500 targets/1004 captures,908 frozen models and reviewed joins. Deep TL zeros, poor reserved-KC sampled fits and the original odd-MUL pattern retain separate limits. See [pitch/level](pitch-supplement.md). |
| Live-register, operator-key and combined histories | Recorded finite descriptors and eligible features |279 history targets/559 captures plus18 key targets/37 captures;186+12 audio models/eight separate timer models.330 history helper calls/660 model links preserve quiet/phase/CSM limits. Exact preceding Rastan trace remains input-missing. See [history](history-measurements.md). |
| Every LFO frequency byte observed | Partial/full/unresolved features; no additional confirmed gap |242 new codes plus14 separately linked originals.540 physical+984 model rows; physical268partial/242periodic/6unresolved/24controls. Models each252/228/4/8;52 new OPM RIGHT results conditional. Different ROI ages and original failed recurrence screens prevent universal period/shape identity. See [all-code LFO](lfo-all-codes.md). |

Detailed methods and evidence locations:

- [Phase measurements](phase-measurements.md)
- [Timer measurements](timer-measurements.md)
- [Native envelope measurements](envelope-measurements.md)
- [Decay, level and release measurements](envelope-stages.md)
- [LFO waveform, depth and gating measurements](lfo-measurements.md)
- [LFO depth storage and write ordering](lfo-storage.md)
- [LFO route isolation and selected history](lfo-history.md)
- [Finite fast-LFO rates](lfo-rates.md)
- [Audio-noise measurements](noise-measurements.md)
- [Algorithms, feedback and joint-key-on phase](algorithm-measurements.md)
- [Finite CSM measurements and all32 routes](csm-measurements.md)
- [Static output mixing measurements](mixing-measurements.md)
- [Common-held-history output measurements](mixing-history.md)

- [Finite audit complements](audit-complements.md)

Long acquisition and the named finite reconciliation rounds are complete.
Full EG KS/KC Cartesian combinations, full slowest LFO periods, arbitrary
simultaneous histories and exact internal overload/accepted-write/IRQ causes
retain their explicit limits. The earlier dated checkpoint schedules are
superseded by [reconciliation](reconciliation.md). Its essential remaining input
is the unavailable original Rastan trace: exact preceding-history replay stays
unmeasured in jt51#7/#8/#13 and prevents full parent#3 completion or starting#14.

## Selected EG KS/KC follow-up

The bounded 23 main/two-carrier matrix (152 physical captures, 50 frozen model
outputs) extends the existing instant-attack and raw-zero/key-scale observations
at selected KC3E/40/41 settings. It adds no new gap classification. Independent
carrier calibration, AR0/AR1 controls and live D1R/D2R0/12 controls are retained
in the [envelope report](envelope-measurements.md#kskc-boundary-and-zero-rate-checkpoint).
All 48 eligible summed-window comparisons lie within their original bounds;
44 are withheld, including wrong-level/unfinished plateaus and unresolved short
attacks. All 24 original model exceptions and four sub-two-window model responses
remain explicit. Agreement of an eligible duration does not clear the previously
measured rate12 granularity gap or establish general feature/sample agreement.

The actual 150 same-input frontend and one descriptor-report parity completed with
terminal 0, preserving all 150 curves and all six scientific documents exactly.
This validates source-promotion parity, not new chip coverage. Production remains
unchanged. Full EG KS/KC combinations remain outside that finite checkpoint;
the later completed histories and audit are recorded in [reconciliation](reconciliation.md).
