# LFO rate supplement: completed finite observations

The supplement is complete as a bounded measurement and saved-output comparison: **242 newly exercised active rate codes**, with the **14 original codes linked separately**, and all original partial, unresolved and conditional results retained. Together the evidence contains an observation for every frequency byte. It does **not** contain 256 newly measured complete periods or a universal accuracy/conformance verdict.

The final dataset joins **540 physical public-latch observations and 984 model public-output observations**, 1,524 rows. Acquisition, model processes, saved feature calls, join and independent output audit are complete. No new production gap, RTL change or implementation authorization follows from these observations.

## Stimuli, coverage and controls

The new active fixtures use one ALG7 C2 carrier, W0, AMD64/AMS1/AME enabled, PMD/PMS0 and TEST02 held during INIT. EVENT retains the literal delay and releases TEST. Other modulation, noise and route state is fixed by the reviewed catalog. The old codes are `00,60,C0,CF,D0,DF,E0,E1,E7,E8,EE,EF,F0,FF`; they are evidence links, not invented new rows.

Physical acquisition contains **270 targets and 275 entire quiets**, 545 captures. The 258 active targets are 242 distinct new codes plus 16 extra boundary repetitions. Codes `01,5F,61,7F,80,BF,C1,FE` each have three independently initialized targets; the other new codes have one. Twelve separate carrier/TEST-held targets qualify the new slow/middle geometries. Each target retains both latches. Every raw capture passed its independent decode, transfer/hash/count/framing/exponent/caller/monitor/conditioning checks, and all 275 entire quiets were zero on both latches. The LFO acquisition ended with reviewed quiet at generation172/markers3114.

| Geometry | Retained frames / stride | Native / retained carrier increment | Declared held prefix |
|---|---:|---:|---:|
| Slow | 4096 / 256 | 648 / 165888 | 128 |
| Middle | 16384 / 64 | 4124 / 263936 | 512 |
| Fast | 16384 / 4 | 65984 / 263936 | 512 |

Slow and middle carrier/held controls qualify separately. Fast reuses the original reviewed six-output physical carrier control on the same bench. All physical observation rows have qualified own-geometry carrier support. This is separate from model-carrier outcomes.

## Original outcomes, without selecting repetitions

Counts below are individual latch/output rows, including their separate controls. Different replication counts mean the physical/model totals must not be read as an agreement percentage.

| Original observer state | Physical | JT51 | OPM |
|---|---:|---:|---:|
| Partial features only; no observed period | 268 | 252 | 252 |
| Periodic measured | 242 | 228 | 228 |
| Aperiodic or unresolved | 6 | 4 | 4 |
| Carrier/held control; no resolved modulation | 24 | 8 | 8 |
| Total | 540 | 492 | 492 |

The original fine diagnostic is eligible/matching on 242 physical and 228 results per model; the six physical and four-per-model unresolved results retain fine false. This is the frozen, independently qualified finite-grid precision check against the nominal hypothesis, not a new cross-device feature-agreement band or universal chip tolerance. Every original applicability flag is true, independently of carrier and period/fine qualification.

Physical middle **BE/r0, both latches** remains unresolved under the original recurrence RMS/span screen (approximately0.15214/0.15197 versus the unchanged0.15 limit). Physical fast **FE r0/latch0, r1/latch1 and r2/both** also remains unresolved (approximately0.15218–0.15369). Other FE repetitions remain individually visible. Each model retains **FA and FE, both output columns** as unresolved. These states do not establish physical aperiodicity, a zero period or a confirmed production defect. No observation was reacquired to replace a failed feature screen.

The four new slow/middle carrier observations per model qualify. The **prior fast OPM RIGHT carrier remains unqualified**, relative sine RMS0.004425787671399019 exceeding the unchanged0.003 screen. All **52 new fast OPM RIGHT rows remain conditional** on that separate carrier result, while their original raw, applicability, coarse and fine fields remain intact. The joined carrier dimension is physical 540 true, JT51 492 true, OPM 440 true/52 false.

## Finite timing and interpretation limits

The nominal native rate is55937.5Hz from the user-reported clock. The physical caller-bound computation uses a conservative3.59MHz ceiling derived by ROOT from the reported3.57–3.58MHz and0.01MHz tolerance; that ceiling is not a directly quoted measurement. The W16/H4 extractor, activity/recurrence/support rules and coarse/fine bands are unchanged.

Physical slow posts735–742 leave3354–3361 retained samples; middle posts2556–2577 leave13807–13828; fast posts2053–2195 leave14189–14331. Actual model-sidecar ROIs leave3455 slow,14207 middle and14510 fast samples. Sidecars describe JT51 public DATA strobes or OPM API presentation, not proven internal latch phases. Model delay is32 master clocks/count; the monitor's CPU path and physical caller/host bounds are different timing evidence. The early/late partial windows therefore have **different ages and origins** across devices. No alignment, fitted phase correction or time warp makes them equivalent.

All198 physical slow active observations retain periodnull. Their saved late-minus-early attenuation changes are−8.086314..−0.095397dB, with post-window spans0.102183..8.555705dB. Lower-middle61–7F likewise remains partial-only. These describe finite continuous advance; they are not extrapolated into a full cycle, clock, internal state count or seed. The slowest full cycle is far beyond this single finite capture. The separately linked old00 evidence also remains within its original partial limits. From80 upward, a period is available only when the unchanged activity, recurrence, independent crossing and minimum-cycle/support rules qualify.

The plots show the original observations without new fitting. Overlapping model outputs can obscure one another in the period/partial panels, including a filled LEFT point beneath a conditional RIGHT point; the per-column support map and tables retain that distinction. Missing full periods and unresolved states remain visible. These plots must not be used to infer a newly defined model/physical agreement band.

## Execution and integrity evidence

The model batch used frozen production JT51 `985a573dcfc1ff135553a39f7eae21d18ba57cbe` and external OPM `a0ab44be60cb28b68431779829454ddf3284f272`, through unchanged whole-output public wrappers. Each model ran246 unique profiles:242 active plus four slow/middle carrier/held controls. Every internal clock was executed; stride only selected retained outputs. Slow/middle captures contain1,048,576 native frames each and fast65,536, totaling413,663,232 native capture frames and5,677,056 retained stereo frames across both models.

The first controller exited1 after17 complete successes, one operational120-second timeout and one cancelled peer. Those successful outputs and partial attempts remain immutable. ROOT reviewed a fresh475-run continuation excluding all17 successes, with a600-second operational guard and unchanged scientific methods/argv. It stayed at two workers and exited0 as managed session10398. Replacement05/06 captures preserve the original partial-file prefixes byte for byte. This was computational recovery, not a feature-failed retake.

Independent492/984 integrity audit73745 exited0 and verified every raw/event/geometry/horizon/report/curve identity and814 frozen input pins. ROOT then rehashed826 source and7899 retained output pins, including the partial attempts, before releasing the completed join. Join12116 exited0 in the recorded isolated Python3.12.3/matplotlib3.11.2/numpy2.5.4 environment. Its own source/output checks and ROOT review preceded the distinct saved-output audit78949, which exited0: all1524 keys, count/state/CSV/report/curve dimensions, old14 separation and three nonblank PNG/complete PDF pairs passed; issues are empty. That audit read4,400,676 saved curve rows and retained all52 conditional carrier rows. No model, scorer, decoder, new fit or new threshold ran during the join/output audit.

## Archived evidence

The permanent archive entry point is `/gdrive/jotego/reverse/YM2151/README.md`.
Its campaign `SUPPLEMENT.md` links all three PNG/PDF figure pairs. Extracting
`supplement-measurements.tar.zst` restores the `ym2151-archive-20261018/` root.
Within its `artifacts/`, `lfo-final-report-v1/REPORT.md` preserves the original
relative links to each raw, model, score, binding and audit file. That original
report has SHA256 `7062c478d4673ca74d374344f24308a4c9e36a680dae526079bff6338e8c2029`.

The complete joined rows and original exception/control/support tables are in
`lfo-final-joined-v1/`. Its source/output manifest has SHA256
`d67dc1e1b4a8824e994c080d653add236a0bbfcfed533f1086bf1ea4573cf82d`.
The distinct `lfo-final-output-audit-v1/audit.json` has SHA256
`76dc4afecefd61b8d1c7c393d671c2910dbecd845ea920c3d36dcee148ddc7ba`.
ROOT's subsequent review rehashed all12408 input pins and viewed all three
figures. [The archive guide](archive.md) gives the complete extraction/path map;
[reconciliation](reconciliation.md) keeps the unavailable Rastan input separate.

Only this permanent prose publication and its evidence links were prepared
after the completed audits. Numerical artifacts, source kernels and RTL remain
unchanged. Original computational and report-packaging failures remain preserved.
