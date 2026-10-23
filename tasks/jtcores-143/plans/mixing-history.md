# Common-held-history output measurements

Finite follow-up to [static mixing](mixing-measurements.md) for
[jtcores #143](http://gitea.jotego.es/jotego/jtcores/issues/143).
Production jt51 remains `985a573dcfc1ff135553a39f7eae21d18ba57cbe`;
independent OPM remains `a0ab44be60cb28b68431779829454ddf3284f272`.
The completed physical batch has 37 captures and 12 frozen stereo model outputs.
The observed high-level output differences persist when TL changes without a
new key edge. Individual voice phases and the exact hidden sum remain unknown.

## Stimulus and independent observations

Six complete profiles use ALG7, KC4A/KF0, MUL0, zero detunes, held AR31/KS0
envelopes and no noise/LFO/CSM. N32 selects all operators; N1 selects channel0
M1. Each has TL32 initially, then TL0, TL32 or TL40 in its middle stage, then
returns to TL32. The TL32 middle is an actual matched no-op. All32 TL registers
are written in fixed order at each stage, including inactive operators. The
complete initial register image, key masks and literal EVENT are checked.

All EVENTs have the same structure: delay4096; pan all eight channels RIGHT-only;
delay1024; write all32 TLs; delay1024; restore both pans; delay4096; repeat the
pan/TL sequence for the return to TL32. There is no EVENT KEYON, KEYOFF,
frequency or EG write. The LEFT/latch0 output supplies two long zero markers;
RIGHT/latch1 stays observable throughout. These output markers bound excluded
intervals; they do not timestamp accepted internal TL writes.

Three independent initializations per profile give18 targets. Each target has
its own preceding4096-frame native quiet recording after measured>=0.5s cleanup.
One final quiet makes37 physical captures:18 targets and19 quiets. Target capture
has16384 stereo frames, native stride1 and measured>=0.05s post-INIT settling.
Cleanup stops CSM/timers FIRST, disables noise, sets all32 RR15 and applies all8
KEYOFF writes; quiet EVENT is STATUS03/00. All19 entire quiet recordings are zero
on both outputs. Every word, exponent, CSV sample, input/transfer hash, count,
boot/image identity and ordered reply chain passes independent raw audit.

Models execute the corresponding model-format INIT and same307-byte EVENT once
per profile with the previously frozen executables. Model INIT includes cleanup
conditioning and8192 preheat delay counts. A model count is32 master clocks;
physical monitor CPU loops are a distinct timing protocol. Each of12 stereo
outputs has16384 native frames,64 master clocks per frame, literal event sidecar,
valid public signed16 PCM and both signs on both columns. Auxiliary/internal
columns are not physical evidence. No model was rebuilt or corrected.

## Frozen analysis and qualification

The marker observer requires exactly two LEFT zero runs of at least256 samples,
excludes each run plus128 samples on both sides and requires supported initial,
middle and return interiors of at least1536 samples. Initial analysis starts at
128. A fixed-frequency native4124 cosine/sine/DC fit uses the first1024 initial
samples; the next512 are withheld. That original prediction is never replaced
by a middle or return fit. Return observations retain both the independent
marker bound and a conservative host-completion bound plus128 samples.

Physical host bounds use exact decimal JSON times and
`ceil((event_host_end-arm_host_start)*56093.75)`, with the user's3.59MHz upper
clock. Actual bounds are10196–13363 native frames before the128 guard; all
remaining return windows qualify. This upper clock follows the user's on-pin
3.57–3.58MHz measurement with0.01MHz tolerance, rather than a precision frequency
estimate. Model sidecar completion bounds are separately derived from public
DATA transactions, not treated as equivalent physical accepted writes.

The observer retains absolute residual RMS/mean/max, coefficient/phase/DC
transfers, raw levels/jumps, independent raw zero crossings and free-frequency
diagnostics. N32/TL0 middle fitting is forbidden. Whole-record RIGHT free fits
are allowed only for the two held-low no-op profiles. All18 physical geometries
resolve and all57 permitted physical free fits resolve; the six whole-noop
increments are4124.000188–4124.000314. These numbers define no new purity band.
Shorter model initial/middle interiors have fewer than eight crossings, so their
free fits remain unresolved; return and whole-noop diagnostics resolve. Duration
and support differences are preserved.

Generic qualification precedes model/physical analysis:1215 grid observations
retain648 supported and567 unresolved states;81 low-gain pairs retain57 consistent
and24 null states. Injected return phase/gain/DC/drift and outside-marker errors
are detected. Unequal per-voice gains with the same aggregate remain
unidentifiable. An initial15-case harness applicability failure is preserved;
the corrected harness requires both compared observations to be supported and
does not change the observer, source arrays or numerical method. Generic
quantization values and screening bounds are not inferred physical tolerances.

The public CSV adapter has41 retained Go synthetic controls and six independent
Python CLI profiles, plus parser/timing/reference/geometry/exclusivity controls.
The separate physical runner qualifies all37 raw/metadata and74 CSV bindings
before running18 feature extractions. Its synthetic contract includes33 binding
rejections, six exact host-ceiling cases, five malformed times, four CLI cases
and two unresolved-reference policies. Actual same-repetition references are all
available: six N1 no-op links and12 N32 no-op/N1 links,18 links total. None of the
unresolved-reference omission policies was needed for this physical dataset.

## Results and limits

| Physical profile | Initial withheld RMS PCM | Return against unchanged initial prediction RMS PCM | Middle/initial AC gain |
|---|---:|---:|---:|
| N32 TL32→0→32 |12.441–12.758|12.399–12.688|No middle fit|
| N32 TL32→32→32 |12.115–12.587|12.119–12.584|0.999984–0.999994|
| N1 TL32→0→32 |0.752–0.784|0.764–0.766|16.014150–16.014700|
| N1 TL32→32→32 |0.748–0.766|0.763–0.772|0.999965–0.999997|
| N32 TL32→40→32 |11.980–12.417|12.257–12.716|0.499274–0.499294|
| N1 TL32→40→32 |0.755–0.776|0.763–0.778|0.499286–0.499293|

Ranges contain all three independent physical repetitions. The no-op values are
observed baselines, never subtracted corrections or acceptance tolerances.
N32 TL40 AC coefficient distance from its same-repetition N1 scalar is
0.201–0.388PCM. This second-low response supports a scoped transfer observation;
it does not prove all32 voices have identical scalar gains up to TL0.

N32/TL0 middle output has RMS27801.387–27913.611PCM over2187–2188 samples,
204–206 adjacent jumps>=4096PCM and extrema−32768/+32704. Frozen jt51/OPM
middle RMS values are31866.748/27187.713PCM over1810/1813 samples, with139/167
such jumps. Each model's own low/no-op/TL40 behavior remains in the reports.
These are descriptive differences under distinct segment durations and
capture/key-on/bus histories. Their persistence through a held-key TL change
does not identify a clipping/wrapping mechanism, internal width or causal fix.

The local scientific figure
`artifacts/mixing-output/common-held-history/figures/conditional-middle-v1/`
plots every supported N32/TL0 RIGHT sample against its original low-fit AC
prediction multiplied by the matched N1 TL0/TL32 gain. This horizontal coordinate
is explicitly conditional on a common-scalar hypothesis. It establishes neither
an exact hidden sum nor a common physical/model phase. No high-region fit,
phase/gain/DC adjustment, alignment, normalization or tolerance band is applied.

![Supported held-history TL0 output samples](http://gitea.jotego.es/attachments/5058c429-4c0a-49db-9935-b88ab98f4968)

## Provenance and retained processing history

All evidence below is under `artifacts/mixing-output/common-held-history/`:

| Evidence | SHA256 |
|---|---|
| `physical-v1/physical.json` |`c094faea9b52af567355eb836edff92c9c197d0a04581729989913304c594e15`|
| Independent raw audit `physical37-independent-v3/completed-v3-physical-v1/audit.json` |`cdb3396fc8476a9830ad719c763fc2449ae4517dc911b6a512c54f8383534147`|
| Final feature handoff |`fed5251e8b00808ac5dae3201c7ae5812d7dc349b89846a9d6a4ce4f9324a41f`|
| Feature summary |`5d11d1312e03fd3f4f03be58092fa4ff14950a80c88b2d79f1502cd705879af0`|
| Final ROOT feature review |`15a916524028e084fc7ff852f0e347196f6eac50841490cca0997bf8da6ef292`|

Features are in `physical-features-v1/completed-physical-v1`; models are in
`public-models-v1`. All294912 full physical curve rows match their original RIGHT
samples. Final ROOT review verifies100 handoff file pins. The original package
mistakenly expected24 reference links; a packaging-only correction records the
actual18, preserving original reports and all numerical records without a rerun.
A supplemental read-only precheck's Path/string error is likewise preserved;
the frozen feature runner launched once and completed without retry.

The batch began at43/0 after a separately archived idle-only recorder rearm,
and ended at117/222. Capture, raw audit and feature handles all terminated0.
No PCB reset, ROM reload, FPGA reload, retake or production RTL edit occurred.
The PCB was left quiet with the resident RAM monitor ready. Wider EG KS/KC,
remaining LFO rates, noise coupling and CSM corners remain separate work;
these observations do not close the overall audit.

## Reproduce the source tools

Run from `tasks/jtcores-143` with fresh output paths. The runtime observer uses
the unchanged strict method JSON and already bounded/hash-linked timing input;
physical acquisition, ROOT readiness and host-bound orchestration stay in the
local frozen campaign evidence.

```
go run host/mixing_history_programs.go -output artifacts/fresh-history-programs
go build -o artifacts/fresh-history-observer host/mixing_history.go host/mixing_history_input.go host/mixing_history_observe.go host/mixing_history_reference.go host/sine_fit.go
go test host/mixing_history.go host/mixing_history_input.go host/mixing_history_observe.go host/mixing_history_reference.go host/sine_fit.go host/mixing_history_test.go host/mixing_history_generic_test.go host/mixing_history_qualification_test.go
```

Pass `-method host/testdata/mixing-history-method.json` to the observer. It retains
the original explicit profile, timing, column, marker and optional matched
reference flags. The known-q mathematical kernel is compiled only with tests.
Default tests use temporary directories; optional
`JT143_MIXING_HISTORY_REPORT_DIR` must name a new exclusive report directory.

Promotion validation reproduces all20 catalog files in two fresh directories,
the complete1323-observation generic report and eight diagnostic curves, and
the complete41-observation actual-adapter synthetic report byte-for-byte.
Four runtime adapter source files remain byte-identical to the originals;
generator and generic math bodies are unchanged. The normative method JSON and
existing free-frequency fitter retain their original exact hashes. Test glue
only supplies permanent fixture paths, exclusive report lifecycle, entry points
and independent catalog/CLI controls. Standalone builds, explicit-group tests,
test-binary build and vet pass.

Fresh extraction of the existing12 model outputs and18 physical targets
reproduces all30 curve files byte-for-byte. Complete numerical, state, geometry,
timing and reference report content is exact; only
`provenance.executable_sha256` and `curve.path` differ. Original CSV, timing,
no-op and calibration arguments remain literal unchanged inputs. This parity
check performs no new model run or physical capture. Its evidence is in
`artifacts/mixing-output/common-held-history/promoted-validation-v1/`.
