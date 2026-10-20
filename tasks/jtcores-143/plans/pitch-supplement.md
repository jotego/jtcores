# Supplemental TL, pitch-order, KF and upper-KC measurements

The bounded supplement is complete: 500 physical targets and 908 real frozen-model outputs have independent public-data/report audits. The completed comparison contains 2000 physical-latch/model pairs, 8000 separately bounded region rows and 2816 original plotting points. All five saved-output integrity gates pass, issues []. The two figures use the original point values; ROOT reports meaningful, readable presentation. This is an observation report, without a new chip-conformance tolerance.

| Family | Physical targets | Unique INIT/EVENT pairs | Coverage |
|---|---:|---:|---|
| TL |138|128|TL0..127 plus independent repeats of 0/32/64/96/127|
| Live ordering |18|6|KC-first/KF-first at 1E→20, 3E→40, 5E→60; 3 physical repetitions each|
| KF |210|192|KF0..63 at KC20/40/60; repeated KF0/31/63 controls|
| Upper KC |134|128|Raw KC80..FF; repeated 80/C0/FE controls|

All targets use the frozen isolated channel 0/C2, MUL8 stimulus cohort, native 16384-sample capture and paired native 4096-sample quiet context. There are 504 quiet records across 1004 captures. Selected 23 profiles have three independent physical captures; the remaining 431 unique profiles have one descriptive capture. The 454 canonical pairs each have one output per model; shared baselines are explicitly mapped to the 500 physical records and are not fabricated model repetitions.

Original state retention: physical TL contains 52 whole-record exact zero latch observations and 120 post unresolved_low_or_short observations. The 880 remaining physical post fits have the original fit-observed-not-automatic-pass state. Physical live-prefix fits retain 12 insufficient-crossing and 24 observed states. Each model retains 48 whole-zero TL latch columns and 112 post unresolved TL columns; each live model prefix retains 4 insufficient-crossing and 8 observed states. All original fit helper processes exited 0, including unresolved-success JSON. These availability/state counts do not assert native frequency or carrier conformance.

Canonical TL104–127 are whole-record exact zero in both latches in all three datasets (physical, JT51 and OPM). The physical count of 52 versus each model’s 48 comes only from four additional physical latch records at TL127 repetitions 1 and 2. It does not indicate an earlier physical zero threshold.

Descriptive differences below use the already saved joined values. Frequency ranges include only pairs with both original sampled-fit values; missing values remain in the full data. Physical and model post intervals differ and remain recorded independently.

| Family | Model | Latch/model pairs | Post RMS Δ range (PCM) | Sampled-frequency pairs | Maximum absolute Δ sampled Hz |
|---|---|---:|---|---:|---:|
|TL|jt51|276|-0.28673712 .. 0.35970379|156|0.00018677276|
|TL|opm|276|-7.1667035 .. 0.4911055|156|0.00017858055|
|live_order|jt51|36|-3.380534 .. 2.6224397|36|9.4088014e-06|
|live_order|opm|36|-3.6882141 .. 2.6627402|36|6.4101685e-05|
|KF|jt51|420|-4.1451764 .. 5.3613226|420|8.104937e-05|
|KF|opm|420|-4.4282295 .. 5.346098|420|0.00057499413|
|KCbit7|jt51|268|-13.682883 .. 10.940825|268|14.112237|
|KCbit7|opm|268|-13.838539 .. 10.864792|268|14.173313|

Operational history is explicit. Model controller 40485 and independent model audit 86166 exited 0. Original join 43067 exited 1 after writing its three complete tables because /usr/bin/python3 lacked Matplotlib; the original source did not write terminal 0 or provenance. Those tables and the failed log remain unchanged. ROOT-approved render-only recovery 67515 exited 0 in isolated /tmp/ym2151-plot-venv, using the entire original plots()/scalar function bodies unchanged and exact `supplement-joined500-v1/points.csv` SHA f0340dd7c59310b084ee69953a0a1335b1f40231ac7e7398969511bdef0aefa7. No join, model, scorer or table was rerun. The original failure, venv ensurepip/no-pip failures, successful explicit-target pip log/freeze/module identities and actual recovery receipt remain recorded. Independent saved-output audit 45994 exited 0 and checked 46 pins plus all original pair/CSV/fit field linkages.

The TL figure retains zero RMS observations and omits unavailable fitted-amplitude values without substituting zeros. The KF figure retains all original physical repetitions and distinct model/latch points at KC20/40/60. ROOT viewed both via view_image and requested no presentation changes; that review is separate from a scientific/conformance vote.

Limits: high/upper KC results are sampled-equivalent observations without native alias unfolding. Original low-KC 243/MUL1 observations are a different stimulus cohort; only the new matched MUL8 anchors support same-cohort lower/upper comparisons. Fixed physical prefix 512 does not establish accepted chip write phase. Neither dataset is phase/time aligned to the other; no gain, DC, phase or waveform correction was applied. Deep-TL unqualified/zero states remain data, and single-code characterizations do not become repeated statistical verdicts. The original Rastan trace is unavailable, so its exact music/history requirement remains pending separately.

All artifact paths in this report are relative to `tasks/ym2151-archive-20261018/artifacts/` in the reconciliation supplement. See [archive.md](archive.md) for the archive and extraction context. Original tables are `supplement-joined500-v1/{joined-observations.json,descriptor-comparisons.csv,points.csv}`; figures are `supplement-join-render-recovery-v1/figures/*.png`; the independent saved-output audit is `supplement-joined500-independent-v2/audit.json`. The model and physical completed packets retain the full source/executable/input/capture/report provenance.

Largest sampled-fit differences remain observations requiring ROOT interpretation, with no new tolerance or retake. The existing joined output has upper-KC differences around 14.17 nominal sampled Hz. The ranked source/quality values are preserved in `supplement-final-report-v1/largest-sampled-frequency-observations.json`; those original fit errors and sampled-only limits accompany the values.

| Physical record | Model/latch | Physical sampled Hz | Model sampled Hz | Physical relative fit RMS | Model relative fit RMS |
|---|---|---:|---:|---:|---:|
|KCbit7-tl000-kcfc-kf00-static-r0|opm/1|26092.08305|26106.25637|3.1785201|5.4626464|
|KCbit7-tl000-kcf9-kf00-static-r0|jt51/1|26570.12368|26584.23592|3.1800485|5.4597222|
|KCbit7-tl000-kcf9-kf00-static-r0|opm/1|26570.12368|26584.23592|3.1800485|5.4599032|
|KCbit7-tl000-kcf9-kf00-static-r0|jt51/0|26570.12389|26584.23592|3.1816747|5.4597222|

The approximately 14.17 Hz upper-KC differences have poor original relative fit RMS values of about 3.18 and 5.46. These fits do not qualify a carrier/fundamental or a native alias-unfolded frequency. They establish no new confirmed production gap and do not justify a numerical retake.
