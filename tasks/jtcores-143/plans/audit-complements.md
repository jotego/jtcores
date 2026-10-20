# Finite noise, CSM and low-LFO complements

**All70 physical captures, model22 and their same-input source-parity comparisons are reviewed.** This bounded complement set addresses selected remaining histories and observation limits. It neither closes full Cartesian coverage nor changes the six confirmed production-gap entries in [the inventory](gaps.md). Production jt51 remains `985a573dcfc1ff135553a39f7eae21d18ba57cbe`; no implementation fix is included.

## Profiles and acquisition contract

All register values below are hexadecimal. The [frozen literal specification](../host/testdata/audit-complements-method.json) supplies every byte: all addresses20–FF appear once, in ascending order, with only the declared overrides. Unselected operator TL is127; selected TL0/AR31/D1R0/D2R0/RR15 provides held controls. Each INIT ends with8192 CPU delay counts. KEYON bit assignments are M1=`08`, M2=`20`, C1=`10`, C2=`40`; bit6 routes LEFT/latch0 and bit7 RIGHT/latch1.

| Profile | Exact distinguishing stimulus | Observation |
|---|---|---|
| N0 | C7/C2, ALG7, KC4A/MUL0, KEYON47; NE/code=`80` initially and after EVENT | Unchanged code00 history control |
| N1 | Same voice, initially NE/code=`9F`; EVENT writes`0F=80`, with no new key edge | Running code31→00 history |
| N2 | Same noise voice, `18=FF`, W2, AMD40/PMD80, AMS1/PMS0, AMEoff; initially TEST02; EVENT writes`01=00` | AMEoff noise-envelope control |
| N3 | N2 with C7/C2 AMEon (`BF=80`) | Noise-envelope magnitude/cadence |
| C2 | C0/M1 LEFT, C7/C2 RIGHT, ALG7/KC4A/MUL8; only C0/M1 manually keyed (`08=08`); Timer A80/00; EVENT`14=05` | Timer running, CSMoff; held manual versus never-manual null |
| C3 | C2 INIT; EVENT`14=85` | Manual-held and automatic paths coexist |
| C4 | C3 without any manual KEYON | Automatic-only split control |
| L0 | C0/C2 both outputs, ALG7/KC00/MUL0, KEYON40, W0, AMD40/PMD80, AMS1/AMEon/PMS0, `18=60`; EVENT releases TEST02→00 | Coarse full-period observation only |
| L1 | L0 with`18=00` | Partial output change only; no period estimator |
| L2 | L1 with AMEoff (`B8=00`) | Separate carrier and drift control, acquired first |
| L3 | L1 with EVENT preserving TEST02 | Held-reset control |

Every N/C EVENT is `02 00 08 01 rr vv 00`:2048 delay counts, one listed register write, END. Every low EVENT is19 bytes: delay chunks65535,65535,65535,65535,4 (total262144 counts), then the listed TEST write and END. C2–C4 each receive a **separate** post-capture STATUS`03 00`; no status read is inserted into the target EVENT.

Cleanup always stops CSM first (`14=30`), disables noise (`0F=00`), writes all E0–FF=`0F` **before** eight channel KEYOFFs, then END. Its SHA256 is `024e6a9a81173c068190eb78346e3e6c16d893da0eb19674209af9c51a5359ea`. Each paired/final quiet follows a measured wait≥0.5s after the cleanup reply and records4096 native stereo frames, with strict whole-record zero on both latches. Quiet EVENT is`03 00`.

N/C targets contain16384 native stereo frames, stride1. Low targets contain4096 retained frames, stride1024 (4,194,304 native frames, about75s); retention has no antialias filter. The low carrier is independently known as native increment162, retained165888. Projection uses W16/H4 and only fully supported windows. The guaranteed early low gate ends at128; native early observations use512 samples.

Physical post selection is `ceil((event_host_end−arm_host_start)×(3590000/64)/stride)+128`, in recorded samples. This uses immutable caller timestamps and ROOT's conservative3.59MHz ceiling derived from the user-reported3.57–3.58MHz with0.01MHz tolerance, not a directly quoted3.59MHz measurement or an accepted-write timestamp. Minimum remaining horizons are N0/N1:4096; N2/N3:6407; C2:1024; C3/C4:3136; L0:3112; L1/L2/L3:1536. Complete protocol104/CAP04 words, exponents, decoded CSV, input/transfer hashes, identities, reply/generation/marker chain, reset/drop state and cleanup waits are independently audited. Acquisition validity never requires model agreement or a convenient target feature.

| Physical stage | Targets | Paired quiets | Final quiets | Captures | Separate STATUS | Reviewed state |
|---|---:|---:|---:|---:|---:|---|
| N0–N3 ×3 |12|12|1|25|0|Complete |
| C2–C4 ×3 |9|9|1|19|9|Complete |
| L2 ×3 |3|3|1|7|0|Complete; all six own-carrier checks qualify |
| L0/L1/L3 ×3 |9|9|1|19|0|Complete after separate L2 review |
| Total |33|33|4|70|9|All70 reviewed |

The two low stages have **two final quiets** and26 captures. All70 contain33 targets,33 paired quiets and four separate final quiets:37 entire-zero quiet captures. The full chain is69/1614→218/2061,149 generations/447 marker bytes, including nine additional CSM STATUS commands. These totals exclude earlier campaigns.

## Qualification and timing evidence

The original [182-configuration qualification](../artifacts/audit-complements-method-v1/numerical-v1-summary-v2/REPORT.md) ran once:36 noise positives,12 noise controls,96 low AM cases (48 each rate60/00),24 held carriers and14 low controls. All frozen expectations were met; the separate ten schema/CLI controls are not extra numerical cases. All48 rate60 positives resolve coarse periods while **all48 original fine flags remain false**, because the propagated endpoint bound exceeds1%. All48 rate00 cases have periodnull and never dispatch a period estimator. All24 carriers pass the scoped free-fit/crossing screen. Generic PRNG signals are not chip sequences.

Limits remain visible: moderate drift and a phase jump are diagnostic-only rather than automatically rejected; irregular AM is unresolved. Clipping, inadequate horizon or contaminated prefix may retain a coarse core result while independent applicability guards reject it. The native1186 alias rejection shares identical retained PCM with native162, demonstrating that PCM alone cannot establish the original carrier. No guard was relaxed after data.

The [reviewed timing/lifecycle evidence](../artifacts/audit-complements-timing-v1/ROOT-completed-timing-lifecycle-review.json) covers all11 literal programs and11 fake-endpoint lifecycle configurations. Assembled-monitor public-bus taps establish minimum whole prefixes1199 native/148 retained against requirements512/128, and worst CPU command2.7509768048473445s at3.56MHz, below the existing5s command poll. Virtual lifecycle checks cover long/native completion and the frozen failure paths. These prove finite CPU execution and caller lifecycle, not physical USB/SSH latency or actual75s acquisition. Earlier ROM-launch/API failures remain preserved. The independently reviewed physical L2 stage below subsequently qualified the actual long acquisitions and all six output carriers.

## Completed physical noise25

The [independent noise audit](../artifacts/audit-complements-physical-noise-independent-v1/REPORT.md), reviewed by ROOT (`4d255724…`), covers12 targets and13 entire-zero quiets:25 records,69/1614→119/1764 generations/markers. All raw, conditioning and actual-horizon gates pass; issues and feature outliers are empty. All26 quiet latch columns contain4096 raw`3004` words, exponent1 and PCM0. Actual post bounds3920–7169 are retained unchanged.

N0/N1/N2 each give six `steady_two_level` reports. N0/N1 preserve sampled candidate divisors1,2,4,8,16,32 and −2044/+2040 levels across their distinct histories; the coarsest compatible lattice32 is not a unique internal-clock identification. N2 gives six `no_resolved_energy_modulation` results: its numeric default period0 and empty bounds **are not a measured period**.

N3 gives six `not_stationary_two_level` descriptors and six resolved energy cadences. Each repetition's two latches agree on these original native-sample measurements:

| Repetition | Measured energy period | Original support bounds |
|---|---:|---|
|0|1057.3829970611082|[993.3829970611082,1121.3829970611082]|
|1|1056.825073001689|[992.8250730016889,1120.825073001689]|
|2|1056.852401859504|[992.852401859504,1120.852401859504]|

The unchanged observer uses32-sample power, independent crossings and±64-sample support. These are finite output-energy observations. They do not establish a noise polynomial, seed, full sequence period, hidden update count or a new production gap.

## Completed physical CSM19 and nine separate status reads

The [independent CSM audit](../artifacts/audit-complements-physical-csm-independent-v1/REPORT.md), reviewed by ROOT (`d6af6bcb…`), covers nine targets and ten whole-zero quiets:19 captures plus nine separate STATUS commands,119/1764→166/1905 generations/markers. All raw/conditioning/horizon and C2 control gates qualify; issues, conditioning issues and feature outliers are empty. All19 write-only capture completion bytes are0; all nine later standalone STATUS replies are1, each with its own generation/marker chain. These are different observations, not contradictory status claims.

Exactly18 original energy invocations and three C2 LEFT whole-native-record phase invocations are retained. All three C2 LEFT controls pass the unchanged rounded65984/RMS<0.01rad/bipolar and independent crossing guards; RMS values are0.002033817135589663,0.002034096411480008 and0.0020339062483284917rad. All three RIGHT controls are16384 exactzero PCM frames, including their entire512-frame prefixes. Their literal per-record exponent1 words are `3000:14400,3001:1024,3002:320,3003:320,3004:320`, all biased-mantissa512/PCM0. Zero PCM is therefore preserved without pretending the target raw words equal the quiet-only `3004` population. All ten quiet captures independently contain4096 whole-zero frames on both latches, raw`3004` only.

C2 LEFT and C3 LEFT each retain three `no_resolved_energy_modulation` results; C2 RIGHT retains three `quiet_exact_zero` results. C3 RIGHT and both C4 latches provide nine `finite_repeated_energy_cadence` observations. C3 RIGHT period511.4428550427874 has original support[447.4428550427874,575.4428550427874]; C4 LEFT/RIGHT period511.425483052476 has support[447.425483052476,575.425483052476]. The reported support includes the configured512-native-frame timer hypothesis. No period is inferred from an unresolved numeric default0; no constant-sine fit is imposed on C3/C4. These manual/null and automatic observations complement the existing confirmed CSM output gap without adding a new gap or an internal mechanism claim.

The physical whole-record C2 guard remains distinct from the original model post-crop phase ledger and its two retained OPM fit exceptions. The retained packaging-only raw-word assertion failure was corrected without rerunning an audit/scorer or changing a scientific guard.

## Completed physical low-carrier7 and low-main19

The [L2 audit](../artifacts/audit-complements-physical-lowcarrier-independent-v1/REPORT.md) covers three stride1024 targets and four native whole-zero quiets,166/1905→180/1947. All six independently reported repetition/latch carriers pass the unchanged165888 free-frequency/crossing and applicability guards, without an expected increment selecting the fit. Repetition0/1/2 measured increments are165888.00025289645/165888.00040413046/165888.00031809544; relative sine RMS is0.0007546592713950742/0.0007533047223199426/0.0007551266937513049. Original integer crossing brackets contain165888. All six reset-held baselines are stable with29 projection points; all six published states are `no_resolved_modulation`, periodnull. Actual posts283/282/283 leave3813/3814/3813 retained samples. ROOT reviewed this stage before authorizing low-main.

The [low-main audit](../artifacts/audit-complements-physical-lowmain-independent-v1/REPORT.md), reviewed by ROOT (`62e165d1…`), covers nine stride1024 targets and ten native whole-zero quiets,180/1947→218/2061. All raw/conditioning/actual-horizon/report-retention gates qualify; all18 original report/curve pairs are applicable with stable29-point pre128 gates. Actual posts281–284 and remaining3812–3815 samples remain literal. A generic raw prefix512 descriptor is not substituted for the guaranteed reset-held prefix128.

All six L0 observations resolve three rising crossings/two complete cycles. Each row is shared by its two latches:

| Repetition | Coarse period, retained samples | Original support |
|---|---:|---|
|0|1024.0000000000002|[1008,1040.0000000000005]|
|1|1024|[1007.9999999999999,1040]|
|2|1024.0000000000002|[1008,1040.0000000000005]|

All six **retain** `finite_precision_mismatch_or_bound_unqualified` and fine-match=false. The endpoint span-period bound is24 samples, approximately2.34375%; the original1% guard is unchanged. Coarse period support neither establishes fine precision nor adjacent-rate discrimination.

All six L1 observations are `partial_features_only`/`continuous_partial_features_no_period`, periodnull. Their literal late-minus-early attenuation values are:

| Repetition | LEFT/latch0, dB | RIGHT/latch1, dB |
|---|---:|---:|
|0|−0.5666278792829367|−0.5666278792829367|
|1|−0.5662546866079126|−0.5662546866079126|
|2|−0.5666194476195816|−0.5674733942550727|

All six L3 results are `no_resolved_modulation` with periodnull and retained continuous two-window descriptors; their tiny literal residual changes remain in JSON. The matched L2 AMEoff and L3 held-reset controls support the scope of the observed L1 output change, without a new statistical/chip band, inferred full cycle, slope extrapolation or hidden-update count. Log normalization8170 is an origin, not a measured full-level calibration. Successful report retention does not turn the six fine-unqualified results into passes.

## Completed public model22

[All22 model outputs](../artifacts/audit-complements-method-v1/reference-model22-audit-v1/REPORT.md) completed once (jt51 and OPM for each profile). Both public latches, complete CSV cadence and literal public sidecar horizons qualify:44 latch records and48 primitive analyses (16 low,16 noise,12 energy,4 phase). Low outputs use4096×stride1024, others16384 native; actual post bounds are257 and1153 respectively. Model clocks and physical CPU/caller bounds are separate evidence.

N0/N1 are two-level in both models; N2 is steady/no-resolved energy modulation. N3 retains nonstationary two-level diagnostics and resolved energy cadence: jt51 period1055.9999999999998/support[991.9999999999998,1119.9999999999998]; OPM1057.273125596713/support[993.273125596713,1121.273125596713]. These broad finite supports and different stochastic histories do not justify an exact-sequence or new defect claim.

C2 LEFT is held/no-resolved energy modulation and RIGHT exactzero in both models. C3 LEFT remains held/no-resolved; jt51 RIGHT is quiet, OPM RIGHT repeats (511.47486939541545, support[447.47486939541545,575.4748693954155]). C4 is quiet on both jt51 outputs; OPM LEFT/RIGHT repeat at511.4604290726802/511.4438047282656, each with original±64 support. These reference observations retain the already recorded CSM discrepancy; the separately reviewed physical controls above are not gated by cross-model agreement.

Both OPM C2/C3 LEFT manual phase fits retain exit1 under the unchanged controlled-sine RMS guard0.01, despite crossings rounding65984. No free-amplitude replacement, phase correction or revised threshold turns them into passes. Both jt51 manual fits qualify. Raw completion and conditional carrier fits remain separate.

All four L2 model carriers qualify independently; the six physical carrier checks above were separately qualified. All four L0 model observations resolve period1023.9999999999998 retained samples, original support[1007.9999999999995,1040], three rises/two complete cycles. Fine qualification remains false (propagated2.34375% bound), so rate60 is coarse-only. L1 has four `partial_features_only` reports with periodnull; continuous late−early attenuation is −0.570620477491639dB in these records. L2/L3 have four no-resolved reports each. A4096-sample rate00 record covers at most1/16 of its nominal65536-sample hypothesis before exclusions; no slope-to-period extrapolation or hidden128/256-update interpretation is made. The actual matched physical controls above retain their own observations and limitations.

## Reproducible portable extraction

The source tools comprise14 portable files: eight Go runtime files (`complements_programs`, `complements_noise_energy`, `complements_low_score`, `complements_input`, `complements_partial`, `complements_low_fine`, `complements_energy`, `complements_noise`, all`.go`); three original structural tests (`complements_programs_test.go`, `complements_input_test.go`, `complements_low_test.go`); the thin `complements_test.go` launcher; public-CSV-only `complements_csm_review.py`; and `testdata/audit-complements-method.json`. Existing observer/tone/sine-fit/phase/CSMenergy dependencies remain unchanged. Runtime bodies preserve original bytes; the generator changes only its embedded-specification path. The Python guard body is preserved verbatim.

Run these reviewed explicit build groups from `tasks/jtcores-143/host`. They are reproduction instructions, not another executed numerical campaign:

```bash
go test -v complements_test.go -run TestOriginalComplementsPromotion -count=1
build_dir=$(mktemp -d)
go build -trimpath -o "$build_dir/programs" complements_programs.go
go build -trimpath -o "$build_dir/noise-energy" complements_noise_energy.go complements_energy.go complements_noise.go tone.go complements_input.go
go build -trimpath -o "$build_dir/low-score" complements_low_score.go lfo_fast_observer.go complements_partial.go complements_low_fine.go tone.go sine_fit.go complements_input.go
go build -trimpath -o "$build_dir/csm-energy" csm_energy.go tone.go
go build -trimpath -o "$build_dir/phase" phase.go tone.go
```

The launcher independently builds/vets all five groups, runs the three original test groups, validates strict CSV/CLI/exclusive-output controls and reproduces the generator. Default output is `t.TempDir`; an optional `JT143_COMPLEMENTS_REPORT_DIR` must be fresh and exclusive. Each generator mode emits exactly25 files:22 INIT/EVENT binaries, shared cleanup and STATUS binaries, plus the catalog. All24 binary payloads match; default and explicit-spec modes each reproduce them, with only22 catalog path rebases per mode. This is two reproductions of the same11-profile catalog.

The [stored-input extraction proof](../artifacts/audit-complements-source-promotion-artifact-v1/REPORT.md) retains nine exact report/curve pairs and the tenth original alias exit1/diagnostic, without rerunning the182 grid. The [actual model22 parity proof](../artifacts/audit-complements-model22-parity-plan-v1/COMPLETED-REPORT.md) replays all48 original primitive argv once:24 curves are byte-exact; their reports/stdout differ only at `/curve/path`; eight stationary curve-free reports are fully exact; all energy/phase stdout and all48 stderr streams are exact. Both OPM phase exit1 results survive. All609 before-pins stayed unchanged and255 output pins were checked. No models or waveforms were regenerated. Source parity is evidence of preservation, not additional chip coverage.

[Physical noise/CSM source parity](../artifacts/audit-complements-noise-csm-source-parity-v1/REPORT.md) is also reviewed:24 noise reports/12 exact power curves and18 explicit CSM schemas preserve18 energy/three phase primitives, guard objects and diagnostics. Raw/horizon/STATUS context is verbatim passthrough, not a second acquisition audit. [All six L2 source-parity results](../artifacts/audit-complements-lowcarrier-source-parity-v1/REPORT.md) preserve reports/stdout except only curve-path relocation and retain byte-exact curves and carrier/pre128/post/periodnull fields (ROOT review`61de553a…`). [All18 low-main source-parity comparisons](../artifacts/audit-complements-lowmain-source-parity-v1/REPORT.md) are now reviewed (`4d94ccde…`):18 reports/stdout match after only `/curve/path` relocation and18 curves are byte-exact, preserving all six fine-unqualified and12 partial-null results. Across the physical data this completes66 outer comparisons/69 primitive results/36 exact curves; the48 model22 comparisons are separate.

The bounded eleven-profile physical measurement set is complete. Reviewed source tools and this report are included in this checkpoint. FullCartesian coverage, precise first-load, deferred P128/P1 CSM, all256 full LFO periods and further histories remain unmeasured; they do not become passing defaults. This report adds no seventh confirmed gap or causal RTL fix. The existing six confirmed gaps remain for the combined implementation issue. Primary public-interface sources are the Yamaha notes, printed10–14/16/21 (PDF11–15/17/22), as indexed in the [frozen method](../artifacts/audit-complements-method-v1/METHOD.md).

The later [reconciliation](reconciliation.md), [history](history-measurements.md)
and [all-code LFO](lfo-all-codes.md) reports supersede the future schedules above
while retaining every original finite result and unresolved feature. Exact
Rastan-history input remains missing; the six confirmed gaps are unchanged.
