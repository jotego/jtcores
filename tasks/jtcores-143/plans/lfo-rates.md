# Finite fast-LFO rate measurements

Follow-up to [LFO depth/waveform](lfo-measurements.md) and
[route/history](lfo-history.md) work for jtcores #143. Production jt51 stays
`985a573dcfc1ff135553a39f7eae21d18ba57cbe`; independent OPM stays
`a0ab44be60cb28b68431779829454ddf3284f272`. This batch covers twelve selected
fast rates, rather than all 256 settings or the slowest complete period.

## Frozen stimuli and measurement method

The exact rates are C0, CF, D0, DF, E0, E1, E7, E8, EE, EF, F0 and FF. A
thirteenth profile supplies a constant AMD0 carrier control. All isolate channel0
C2, ALG7, KC4A/KF0, MUL8, zero detunes, W0, AMD64/AMS1/AME1 and PMD/PMS0.
TEST02 holds the LFO in INIT; EVENT is exactly delay8192, TEST00, END. There is
no KEYON or frequency write during EVENT. Complete literal register images,
ordered writes, all thirteen original INIT/EVENT pairs and geometry are pinned.

Each target records 16384 stereo frames at stride4, nominal retained rate
13984.375Hz, native increment65984 and retained increment263936. All native
frames run in each model; retention is exact subsampling. Projection uses the
existing sine/cosine/DC observer, window16/hop4. No anti-alias filtering occurs;
the declared carrier and native provenance are required independently of the
retained samples. First512 frames form a declared held baseline, checked for
actual bipolarity and stability. The calibrated physical CPU delay supports
that choice but supplies no exact accepted TEST-write timestamp.

The unchanged published observer retains its median period, interval bands,
activity and recurrence states. A separate predeclared diagnostic uses the first
and last independently detected hysteretic rising crossings, dividing their
span by the number of intervening cycles. Its endpoint allowance is
`2*(window+2*hop)/(crossings-1)`. Fine qualification requires the original 1%
screen, propagated-bound coverage and relative bound<=1%, plus adequate horizon,
activity, raw range and baseline checks. Rounded primary Yamaha frequency-table
entries motivate the nominal rational hypothesis; they are not exact printed
numbers or a measured hidden-counter specification. The original coarse method
is never replaced or widened to make the fine diagnostic pass.

The inverse-sine phase fitter is outside its scope at retained263936. Carrier
qualification instead uses the existing free-frequency fit without an expected
frequency input: rounded increment263936, absolute increment error<0.1 and
relative PCM sine RMS<0.003. Independent integer sign-crossing brackets must
contain263936. Interpolated crossing points and whole-record fits remain
descriptive, not replacement guards. Relative PCM RMS is not phase RMS.

## Independent qualification before models and hardware

The method and exact finite grid were frozen before numerical experiments.
All3456 native-forward generic positives pass, covering independent amplitude,
dB and 128/256-step waveform classes, phases, ages and quantizers. These stair
classes assert no physical hidden update count. Quantization precedes stride
retention. All48 carrier/null cases qualify; all48 deliberately 3.2–3.3% wrong
periods are distinguished by the fine screen. Ten of those wrong cases remain
periodic under the original broad coarse method, whose original states stay
visible. Maximum generic fine error is0.018561%, maximum propagated bound
0.585938%. Eight adverse/alias controls retain their specified states.

A legal/aliased native pair has identical retained PCM, explicitly demonstrating
that PCM fitting alone cannot identify preexisting aliasing. Quiet, stuck/tiny,
noise, drift, short and clipped cases retain their negative/unresolved states;
the clipped coarse-periodic case is fine-ineligible. The same generic grid
qualifies the free-frequency carrier method, maximum relative RMS0.002584.
These are finite instrument controls, not a universal physical tolerance.

Generator validation reproduces26 payloads, all224 final channel/operator
registers, globals/key masks and the exact seven-byte EVENT. Twenty original
malformed/contaminated-base and CLI/exclusivity cases reject. The first generator
version incorrectly rejected canonical intermediate TL127 initialization;
that original failure is preserved. V2 only permits that trusted intermediate
write, preserving final state, payloads and numerical guards. The final scorer
retains the originally declared carrier horizon1024 and a descriptive whole
carrier fit. Six positive/state cases and24 CLI/input/output-refusal checks pass.

## Completed model and physical observations

The thirteen profiles ran once on each frozen whole-output model:26 stereo
records,52 public columns and425984 retained stereo frames. Every model CSV has
256-masterclock cadence, exact input/EVENT sidecar and16384 rows. Original model
post3072/pre512 leaves13312 frames; the public TEST-write ceiling is1025. All52
whole/prefix/post outputs are bipolar, with raw range−8176/+8160.

All48 AM coarse/fine observations qualify numerically. Three of four carrier
controls qualify. **OPM RIGHT carrier relative RMS0.004425788 exceeds the fixed
0.003 limit**, while its frequency/crossing guards pass. That exception remains
unmodified; its twelve AM diagnostics are conditional. No model patch, new
guard or majority vote is used to remove it.

Physical acquisition is deliberately staged. First, three independently
initialized carriers, three paired native quiets and one final quiet make seven
captures. All six carrier outputs qualify: retained increments
263935.999895–263936.000084, relative RMS0.001427984–0.001430025, independent
crossing intervals containing263936 and stable/bipolar held baselines. ROOT
reviewed these actual results before authorizing any rate sweep.

Then twelve rates × three independent initializations give36 targets/36 paired
quiet plus a separate final quiet:73 captures. Overall there are80 captures,
39 targets and41 quiets, including TWO final quiets. Quiets use native4096 frames,
measured>=0.5s stop-CSM-first cleanup and STATUS03/00. Targets use measured>=0.05s
post-INIT settling. All41 entire quiets are zero on both outputs. Raw transport,
conditioning and feature gates stay separate; all are true, with no issues or
feature outliers in either stage. No reset, reload, retake or retry was needed.

Physical post is frozen as
`max(ceil((event_host_end-arm_host_start)*14023.4375)+64,1794)+80`, using
ROOT's conservative3.59MHz upper bound, derived from the user's on-pin3.57–3.58MHz measurement and0.01MHz tolerance. Each AM case must retain at least
`ceil(3*nominal_period)+40` frames after that bound. Actual posts are1971–2785;
all36 horizons qualify. This bounds EVENT completion, not an accepted internal
write, and does not redefine the independent first512 baseline. Short horizons
would retain raw validity and withhold scoring without shifting the ROI.

All72 physical output observations retain their original coarse periodic state
and pass the original fine screen. Maximum absolute endpoint-span error is
0.097709%; maximum propagated bound is0.585938%. Each observation, repetition,
latch, original median, recurrence statistic and endpoint bound remains in the
retained reports. No physical/model waveform alignment is applied.

| Rate | Nominal retained period | Physical endpoint-span range, six observations |
|---|---:|---:|
| C0 |4096.000000|4096.000000–4096.000000|
| CF |2114.064516|2111.998889–2114.741061|
| D0 |2048.000000|2048.000000–2048.000000|
| DF |1057.032258|1056.615495–1057.231348|
| E0 |1024.000000|1024.000000–1024.155962|
| E1 |963.764706|963.707545–964.050611|
| E7 |712.347826|712.400238–712.502903|
| E8 |682.666667|682.564370–682.885220|
| EE |546.133333|546.078463–546.242061|
| EF |528.516129|528.443901–528.641539|
| F0 |512.000000|511.998503–512.056604|
| FF |264.258065|264.228137–264.272346|

The scientific figure in `artifacts/lfo-rate-fast12-v1/figures/period-span-v1/`
shows all72 physical and48 model diagnostics, explicitly marking conditional
OPM RIGHT. Overlapping outputs may coincide. No exact printed-table, hidden
counter, cycle-exact reset, seed, precise bus latency or all-rate claim follows.
Slow LFO staircase timing and the approximately1200s slowest period remain
outside this batch and beyond one300s buffer. Partial advancement is not a
measured complete cycle.

![Original fast-LFO period diagnostics](http://gitea.jotego.es/attachments/755bfb52-20a0-4eb4-a92a-a8cdb4565680)

## Provenance

All paths below are under `artifacts/lfo-rate-fast12-v1/`:

| Evidence | SHA256 |
|---|---|
| Pre-math `method-before-math.json` |`65136d6507de1a758a26130c60cd070b50f271f5dd09ccb81109ec535051216b`|
| Staged physical `METHOD.json` |`bd7b0293f85f4d6cd9cfe1c2ccf32a5fa339fa696eb109dd016842a692249efb`|
| Carrier independent audit |`cd6d9f7b3624025c4a6258d15bf899e8804074b5b3adf5870b295fecdfc1ce7e`|
| AM independent audit |`dae0cff6f8bffe62f0739de52b8fc733566c631208a570d4714316ec6e825ad0`|
| ROOT AM final review v2 |`c4d19153ca25349cd361d9328370e06e723692b87d036ba1fd253e00ef59daac`|

`physical-carrier-independent-v1/` and `physical-AM-independent-v1/` retain raw,
conditioning, individual score/curve and summary sources. ROOT verifies all150
AM output pins and71 frozen source pins. Audit handles30102/8776 and capture
handles50951/35756 all terminate0; final quiet monitor state is21/702. Original
syntax, future-gate schema and summary-only optional-field processing failures
are preserved. None changed numerical kernels or caused a physical/scorer retry.
Other subsystem boundary work remains separate; this is finite rate coverage.

## Source reproduction

Run from `tasks/jtcores-143`, using fresh output paths:

```
python scripts/monitor.py emit tone --output artifacts/fresh-tone.bin
go run host/lfo_fast_programs.go -base artifacts/fresh-tone.bin -output artifacts/fresh-fast-lfo
go build -o artifacts/fresh-fast-score host/lfo_fast_observer.go host/tone.go host/sine_fit.go host/lfo_fast_fine.go host/lfo_fast_score.go
go test host/lfo_fast_test.go -run TestOriginalFast12Promotion -count=1 -timeout=20m
```

The focused test builds explicit standalone groups and runs the original
generic qualification once. It needs no hardware, model executable or local
capture artifact. Temporary reports are the default;
`JT143_LFO_FAST_REPORT_DIR` optionally selects a new exclusive output directory.
The existing modulation CLI, tone projection and free-frequency source stay
unchanged. Physical capture and independent raw/conditioning audits remain in
the frozen local campaign evidence.

Promotion preserves four complete frozen runtime sources exactly and appends
only the unchanged fixture exporter to the original generic test source. The
thin outer test runs the original3456/48/48/8 grid once, reproduces26 payloads,
validates all224 registers and every manifest field, and preserves20 generator
and six positive/24 negative scorer controls. The full generic scientific-content
digest is fixed before the rerun; only48 `signal_csv` output-root prefixes are
rebased. Complete remaining report content and suffixes match. Existing report
roots are rejected before tests, without modifying old data. Explicit builds,
four vet groups and focused tests pass; shared sources remain untouched.

Fresh scorer extraction of52 existing model columns,72 physical AM columns and
six physical carrier columns gives130 complete JSON reports and130 curves,
all byte-identical to their frozen originals. Exact input paths, profile/rate,
columns, actual post/pre512 and all other arguments are retained; only the
executable and fresh output destinations change. The OPM RIGHT carrier exception
is reproduced exactly. Extraction creates no new model run or physical capture;
actual new executable identities remain in the promotion provenance under
`artifacts/lfo-rate-fast12-v1/promoted-validation-v1/`.

The later [all-code supplement](lfo-all-codes.md) adds the242 previously absent
codes with separate partial/unresolved limits; this original checkpoint remains
unchanged as evidence for its twelve selected rates.
