# Measurement gap inventory

Work in progress for jtcores #143. Production jt51 remains at
`985a573dcfc1ff135553a39f7eae21d18ba57cbe`. Collect the measurement set before
opening combined implementation work, following the user's jt51 #3 instruction.
No RTL change or candidate patch has been made.

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
| Stereo pan controls | Qualified for current wiring; earlier human labels corrected | Primary ACC notes: bit6 left, bit7 right. Actual captures map latch0 to left, latch1 to right. Old left/right artifact names were reversed; latch indices and both-pan results remain intact. |
| Output-visible pan markers | Scoped physical continuity; reference-only output difference retained | Nine physical captures have three left/latch0 zero pulses and continuous right/latch1 output. Constant right carrier has an unbroken phase fit. Separately qualified local/coherent diagnostics find no PCB disturbance at the observed OPM pan-only error scale. No physical same-clock counterfactual, byte-identity claim, oracle patch or causal diagnosis. |
| Transient SH framing disturbance | Acquisition anomaly, retained and excluded | Two earlier failed recordings; all accepted pitch/event recordings pass framing and transfer checks. No causal conclusion about probing/wiring. |

Detailed methods and evidence locations:

- [Phase measurements](phase-measurements.md)
- [Timer measurements](timer-measurements.md)
- [Native envelope measurements](envelope-measurements.md)
- [Decay, level and release measurements](envelope-stages.md)
- [LFO waveform, depth and gating measurements](lfo-measurements.md)
- [LFO depth storage and write ordering](lfo-storage.md)

Long acquisition is now available (see [qualification](long-acquisition.md)).
Open coverage includes full EG KS/KC combinations and remaining history
boundaries, remaining LFO rates/isolation/history and further storage cases, audio noise,
algorithms/feedback, CSM, output mixing
and clipping. These are incomplete measurements, not passing defaults. The
earlier X-Men planning issues are not marked complete by this direct-serial work.
