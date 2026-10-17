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
| Raw zero AR/D1R/D2R loses inhibition after key scaling | Confirmed production gap | Isolated D1/D2 holds at all KS, AR0 negative controls plus AR1 positive control. Observable AR0 leakage at KS2/3; KS1 AR0 internal change is diagnostic only in this window. |
| PCB pitch fits a missing multiplier partial-product contribution | Unclassified physical/reference discrepancy | 243 cases after known reset; 114 differ by 8192. Bus/control/capture versus chip behavior remains unresolved. Both models agree; model voting does not establish the chip is defective. |
| Timer coarse periods | Consistent within declared bounds | 100 guarded observations at 10 preloads; first-overflow phase remains uncertain. |
| KS0 AR12–31 outside the rate30/31 gap | Consistent windowed attack features | Three physical repetitions per setting. Fastest attacks remain below projection-window resolution; no sample-identity claim. |
| Stereo pan controls | Qualified for current wiring | Separate left/right/both/neither programs; input/latch 0 is right, latch 1 left. |
| Transient SH framing disturbance | Acquisition anomaly, retained and excluded | Two earlier failed recordings; all accepted pitch/event recordings pass framing and transfer checks. No causal conclusion about probing/wiring. |

Detailed methods and evidence locations:

- [Phase measurements](phase-measurements.md)
- [Timer measurements](timer-measurements.md)
- [Native envelope measurements](envelope-measurements.md)

Open coverage includes slow envelopes and LFO acquisition, full EG stage/rate
and history boundaries, LFO AM/PM, noise, algorithms/feedback, CSM, output mixing
and clipping. These are incomplete measurements, not passing defaults. The
earlier X-Men planning issues are not marked complete by this direct-serial work.
