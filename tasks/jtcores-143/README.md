# Diet Go Go YM2151 measurements

The bounded direct-serial measurements and issue reconciliation for
[jtcores #143](http://gitea.jotego.es/jotego/jtcores/issues/143) are recorded in
[reconciliation](plans/reconciliation.md), the [coverage report](plans/validation.md)
and [gap inventory](plans/gaps.md). The original campaign and the complete
reconciliation supplement are preserved through the [archive guide](plans/archive.md).

The supplement adds2145 independently reviewed physical captures: pitch/level,
live-register/operator histories and242 previously absent LFO codes. The
[all-code LFO report](plans/lfo-all-codes.md) retains partial/unresolved observations
and conditional reference results. Production jt51 remains985a573 unchanged.
Exact Rastan preceding-history replay lacks its original input; jt51#7/#8/#13
and parent#3 remain open, and implementation#14 remains blocked by#13.
Earlier checkpoint paragraphs below retain their historical observation limits.

The held-history source tools and explicit Go build/test groups are documented
in [mixing-history.md](plans/mixing-history.md#reproduce-the-source-tools).
The [fast-LFO rate checkpoint](plans/lfo-rates.md) adds80 physical captures across
twelve selected rates and independently qualifies all six physical carrier
outputs. The retained OPM RIGHT model-carrier exception remains explicit.

## Hardware and initial state

PicoROM is **P28_27C512_70ns**, device `E66550A14758A021`, replacing the 64 KiB
`jw_02.14m` sound ROM. Its original volatile image was backed up locally; it was
all FF bytes. Reset is unconnected and remains high impedance. The installed
diagnostic firmware was built from PicoROM commit
`c2fa947d8c1ca8a1e7cb0b9b4b4dcd331aff5fff` in
`/nobackup/jtmisc/reverse/PicoROM`, specifically the P28 target. It reports
`diag_version=jtkcpu-1.6`. POG/P32 builds have different pin assignments.

Chameleon96 USB Linux is at `192.168.96.96`, using the retained SSH configuration
`~/jtcores/tasks/SiliconRE-5/scripts/ssh-config` and alias `chameleon96-usb`.
The capture design assigns J3.16/18/20/22 (FPGA E5/F5/A6/A5) as input-only 1.8 V
pins. These are the same assignments as the previous qualified capture design.
Raw observations identify two staggered strobes on bits 0/1 and SO-like data on
bit 2. The user confirmed that the outputs pass through open-drain inverters
into the 1.8 V domain. Both decoders correct inversion before interpreting edges
or data (mask 15, including the unused fourth input). Absolute left/right names
are qualified by the pan bits and primary Yamaha documentation: latch channel 0
is left (register20 bit6), channel 1 is right (bit7). Earlier test names reversed
these human labels; original artifact filenames are retained as provenance.
Tools retain latch-based labels so evidence remains tied to input pins.

The user reports a YM2151 clock of **32.22 MHz / 9 = 3.58 MHz**, confirmed on-pin
at 3.57–3.58 MHz with 0.01 MHz measurement tolerance. Nominal native sample rate
is **55,937.5 Hz**. Raw SH timing independently measures about 55,937 Hz. The
package marking reported by the user is **9223 EAEG**. A user-confirmed PCB power
cycle returned the resident monitor's fresh `B0 2A 00` boot frame; Chameleon96
and PicoROM remained running. [Phase measurements](plans/phase-measurements.md)
record the discrepancy that persisted after that reset.

## Sound CPU monitor

Source root `setprj.sh` before project commands. Build with cc65's `ca65` and
`ld65` on PATH, or provide their paths as `CA65` and `LD65`:

```
bash tasks/jtcores-143/scripts/build-monitor.sh
```

The 8 KiB boot image is repeated through a 64 KiB ROM. After testing all 8 KiB
of sound RAM without using a stack or RAM variables, boot copies the 173-byte
monitor to RAM at logical 2200. Its code no longer depends on the flashable ROM.
Mappings are MPR1=F8 (RAM), MPR2=88 (YM2151), MPR3=01 (control/comms ROM),
MPR4=02 (command table). Interrupts are masked. The host may replace the table
while the CPU idles, verifies its USB readback, then writes a new generation
and its complement. A completed command returns a three-byte frame.

Use Python with PyUSB installed. The workstation already has it in
`~/jtcores/tasks/jtkcpu-1/tools/venv/bin/python`. `pico_link.py` reuses that task's
small USB protocol client. The checked-in sources contain no credentials.

```
python scripts/monitor.py install
python scripts/monitor.py poll --seconds 60 --until-reply
python scripts/monitor.py run timer-a --until-reply
python scripts/monitor.py run clear --until-reply
python scripts/monitor.py run timer-b --until-reply
python scripts/monitor.py run tone --until-reply
python scripts/monitor.py run silence --until-reply
```

Those examples run from this task directory. `install` disables ROM service,
uploads and verifies the whole image, arms communications at physical 3C00,
then enables service. **Use it for initial installation, not for routine tests.**
An arbitrary CPU state might require a PCB power cycle to enter the monitor.
The first physical install happened to return its boot frame without one.
Keep PicoROM USB powered during PCB power cycles so the volatile image survives.

The host records pending commands in `artifacts/monitor-state.json` and rejects
overlapping submissions. After a timeout, use `poll` before issuing another test.
Do not delete the state to bypass a pending operation. A reset during a pending
test is reported as an error. Each PicoROM session has a 4096-marker limit;
current runs use three markers per reply. Use the verified-idle rearm procedure
below before exhausting that budget.

Bytecode, supplied as a binary file with `run --program FILE`:

| Bytes | Operation |
|---|---|
| `00` | Complete and return `D0 generation status` |
| `01 register value` | Wait for YM2151 busy, then write register/value |
| `02 low high` | Delay by a 16-bit CPU loop count; zero means no delay |
| `03` | Read YM2151 status into the completion frame |

Startup returns `B0 generation status`. Unknown opcodes return completion status
FF. Host tables must fit 8 KiB and end in 00; this is a trusted experiment format,
not a sandbox for arbitrary bytecode. CPU delay counts are not calibrated timer
measurements. Timer smoke tests only check overflow/reset flag behavior.

## Capture design

The board/HPS transport, PRNG, raw and PCM modes reuse
`~/SiliconRE/Konami/054539/chameleon96`. This task adds mode 3 for Yamaha.
It measures intervals between alternating SH falling edges and samples sixteen
SO bit cells at their centers. It preserves the full serial word, including
the three unspecified bits. Invalid/missing strobes increment framing errors;
the analyzer rejects captures with any framing error.

Protocol ID is 960104. Existing modes 0/1/2 keep their existing file format;
mode 3 uses `C96CAP04`, an 80-byte little-endian header with the same fields as
`C96CAP02`, version 4 at offset 12, mode 3 at offset 52, and the latest measured
stereo-frame interval in FPGA clocks at offset 68. Offsets 72/76 stay zero.
This interval is integer-quantized and gives approximate absolute sample rate.
In mode 3, PERIOD (offset 28) is a stereo-frame stride, 1..1024. The recorder
retains the first qualified pair, then every Nth complete pair. Native framing
checks continue during skipped frames. Recorded sample rate is the native rate
divided by stride; the 16,384-frame buffer spans about 300 seconds at stride 1024.
This selection has no anti-alias filter: choose a known carrier below the
recorded Nyquist frequency. Use stride 1 for waveform/noise comparisons.
The reader preserves v3 behavior: `C96CAP03` ignored PERIOD and remains native.
Payload words start at latch channel 0 and alternate 0/1. Each 16-bit word has
three unspecified bits at [2:0], an offset-binary mantissa at [12:3] and exponent
at [15:13]. The analyzer reports exponent zero as invalid.

The framing basis is Yamaha's YM2151 terminal description and
[YM3012 data/timing documentation](https://ftpmirror.your.org/pub/misc/bitsavers/components/yamaha/YM3012_199204.pdf),
particularly its serial ordering and SH latch timing. The local source scan is
retained in artifacts. No assumption of standard I2S framing is made.

Build after sourcing root `setprj.sh`, with Quartus 20.1.1 and `dtc` on PATH:

```
bash tasks/jtcores-143/board/build.sh tasks/jtcores-143/artifacts/c96-yamaha104-build
```

Use `board/load-fpga.sh` on the board with the compiled RBF/DTBO in
`/lib/firmware` and matching `host/c96-capture.c` compiled as
alongside the loader as `/home/root/jtcores143/c96-capture`. Invoke the loader
with `yamaha104`; firmware filenames are `c96-yamaha104.rbf` and
`c96-yamaha104.dtbo`. The previous `yamaha` image remains loadable.
The loader quiesces fabric drivers, uses the old
kernel's configfs `path` method, probes the design ID and preserves SD boot files.
Record backups and hashes of replaced runtime files first. The original boot
image and USB recovery remain available. Example board commands:

```
./c96-capture configure 3 15 0
./c96-capture capture /tmp/unique-name.cap 1 32768 1 151
```

Transfer with legacy SCP (`scp -O`), compare HPS and PC SHA256, then analyze:

```
go run host/analyze.go artifacts/unique-name.cap
```

Mode 1 raw recordings can be decoded independently by the same tool. It checks
metadata, strobe order, timing stability and SO bit-center margins. `-csv PREFIX`
exports decoded words for each channel to fresh files.

## Verification

The installed Verilator 5.018 needs the established task wrapper that removes
the unsupported `--quiet` argument:

```
export PATH=$HOME/jtcores/tasks/SiliconRE-5/scripts/verilator-compat:$PATH
simunit-all.sh --only c96_yamaha_sampler
bash tasks/jtcores-143/ver/replay/sim.sh
go test tasks/jtcores-143/host/analyze.go tasks/jtcores-143/host/analyze_test.go
```

Run these from the repository root with its environment sourced. Replay requires
a local raw capture (`high.cap` by default; override with `YAMAHA_REPLAY`). It
compares every full RTL word with the independent offline decoder, including
channel identity and unspecified low bits.

`scripts/check-monitor.lua` runs the assembled image in local MAME `dietgoe`
(the installed MAME 0.260 ROM set matches this clone). It verifies RAM boot,
communications, timer status, live command generations and physical YM2151
register writes. `CHECK_TONE=1` additionally exercises a multi-page tone table.
Always wrap MAME in `timeout 5m`. Retain and inspect its PASS output: MAME's
process status alone does not report Lua assertions. The optional WAV has been
checked non-silent and measured at about 440 Hz.

The [jt51 harness](ver/jt51/README.md) accepts the same binary register programs.
Generate one offline (from this task directory) using
`python scripts/monitor.py emit tone --output artifacts/fresh-tone.bin`, then run
`bash ver/jt51/sim.sh artifacts/fresh-tone.bin artifacts/fresh-jt51.csv`.
It has been checked for a 64-clock native sample cadence and a nonzero 440 Hz
tone matching MAME. Its steady pitch is now compared against post-reset PCB
recordings and an [independent OPM oracle](ver/opm/README.md). Transient capture
alignment remains unqualified.

## Steady phase measurements

Generate the complete 243-case PG matrix from the canonical tone, using a new
output directory. It covers all KC values, all KF values at KC=4A, all DT1 values
at KC=4A, all DT2 values at KC=40 and all MUL values at KC=40. It adds multiplier
interaction sweeps at KC=4A/50/60:

```
python scripts/monitor.py emit tone --output artifacts/fresh-tone.bin
go run host/programs.go -base artifacts/fresh-tone.bin -output artifacts/fresh-pg
```

Each generated program contains the full initialization and one controlled
single-operator voice. The manifest includes program hashes. Apply a program
with `monitor.py run --program FILE --until-reply`, capture mode 3, and submit
the identical file to the jt51/OPM harnesses. Transfer hashes and zero framing
errors are prerequisites for accepting a physical capture. Preserve failed
recordings separately; do not include their samples in a result.

The phase fitter regresses inferred sine phase against native sample index.
Its result is independent of master-clock calibration and initial phase:

```
go run host/phase.go host/tone.go -sample-rate 55937.5 artifacts/capture-0-0.csv
go run host/phase.go host/tone.go -column left -sample-rate 55937.5 artifacts/jt51.csv
go test host/phase.go host/tone.go host/phase_test.go host/tone_test.go
```

It requires a controlled, unmodulated single sine of known peak amplitude
(default 8170, quantization offset -8), consecutive samples, and positive
effective phase advance below one eighth of the sample rate. It rejects silent,
non-sinusoidal, changing-frequency and malformed inputs. This estimates an
effective 20-bit phase increment from output; it does not read internal chip
state or establish transient envelope equivalence. `-sample-rate` is optional
and adds a calibrated frequency without altering the fitted increment.

## Timer measurements

[Timer results](plans/timer-measurements.md) record a physical status-flag gap
in production jt51 and the uncertainty of period-boundary observations. The
production revision remains frozen while measurement gaps are collected.

```
go run host/timer_programs.go -output artifacts/fresh-timers
bash ver/timer_flags/sim.sh
```

The standalone timer conformance probe intentionally returns failure against
the frozen baseline; it is not registered in CI. Its README distinguishes
physically measured status behavior from unobserved physical IRQ behavior.

Artifacts, generated fixtures, builds, ROMs, captures and local state stay out of git.

## Native envelope events

The [envelope report](plans/envelope-measurements.md) records pretrigger
qualification, AR12–31 and key-scale boundaries, isolated D1/D2 zero-rate holds,
and AR0 negative controls with a nonzero AR1 control. The capture helper retains
exact inputs, timing bounds, device identities, replies, hashes and decoded data.
The models record throughout event bytecode, with exclusive event-clock sidecars.

```
go run host/envelope_programs.go -base artifacts/fresh-tone.bin -output artifacts/fresh-ar
python scripts/capture-event.py artifacts/fresh-ar/ar14-init.bin artifacts/fresh-ar/keyon.bin artifacts/fresh-ar14 --capture-id 2000
go run host/envelope.go host/tone.go -increment 65984 -window 32 artifacts/fresh-ar14-0-0.csv
```

These commands run from the task directory; use Python with PyUSB. The capture
helper accepts the qualified Yamaha protocol 960103/960104 recorder; stride
greater than 1 requires 104.
For decay/hold analysis use `-curve-only`; attack timing against a reduced final
level is not meaningful. The [gap inventory](plans/gaps.md) separates confirmed
production gaps, unresolved physical/reference differences and remaining scope.

## Longer event acquisition

`capture-event.py` accepts `--stride N` (default 1) and `--words COUNT` (even,
4096..32768, default 32768). It accepts native v103 or stride-capable v104,
checks identity before using the stride, and computes its timeout from the
requested duration. Capture manifests distinguish nominal recorded and native
rates. The HPS `capture` command also uses a Yamaha duration bound; it no longer
uses the raw-clock timeout for native or decimated serial data.

A low carrier KC00/MUL0 was independently measured at increment 162 before using
large strides. At stride 1024, analyze its envelope with increment 165888 and
sample rate 54.62646484375 Hz. The main KC4A/MUL8 carrier must not be used for
that low recorded rate. See `plans/long-acquisition.md` for qualification.

## Rearm the finite PicoROM reply recorder

The existing PicoROM diagnostic firmware stops its reply marker recorder at
4096 events. Before exhaustion, renew only a verified idle session:

```
python scripts/monitor.py rearm --output artifacts/fresh-rearm.json
```

The helper holds the normal monitor lock and refuses pending/partial/unverified
CPU state, unconsumed replies, inactive/stopped/dropped capture or an advancing
producer. It archives the old 1 KiB reply window and metadata before end/start.
ROM service must be enabled with the qualified 64 KiB address mask. The 8 KiB
boot bank hash, ROM-enable/mask and generation pair must remain equal;
no ROM upload or CPU reset is performed. The new recorder must be active/empty
and the CPU must not produce an unexpected frame. Failures remain in the report.
The first live qualification archived 3171 markers, then passed generations 32/33
through separate fresh USB clients, without a second boot frame or reply drop.
Run guard tests with the qualified PyUSB Python environment:

```
python scripts/test_monitor.py
```

## Decay, level and release experiments

See [methods and coverage](plans/envelope-stages.md). Generate fresh cases from
an emitted canonical tone table:

```
go run host/decay_programs.go -base artifacts/canonical-tone.bin -output artifacts/fresh-stages
```

Profiles `d1` and `d2` begin with a keyed-on stable level, then write the active
stage's rate. `release` starts from the same level and keys off. `d1l` and the
selected `d1-keyon`/`d2-keyon` complements configure the rate before key-on and
begin recording from silence. Each manifest records exact INIT/EVENT paths,
hashes, carrier, stride, window and frame count. Automatic scheduling uses
qualified high/native or divided/stride carriers; a carrier above recorded
Nyquist is rejected. Slow horizons are qualified by reference pilots rather
than assumed from the attack sweep.

Acquire with `capture-event.py` using each manifest's stride and twice its frame
count as `--words`. For example, the slow D1R1 case uses stride 64 and 32768 words.
For that case export and score the fixed amplitude curve:

```
go run host/envelope.go host/tone.go -curve-only -increment 263936 -window 32 -sample-rate 874.0234375 -csv artifacts/fresh-amplitude.csv artifacts/fresh-capture-0-0.csv
go run host/decay.go -window 32 -sample-rate 874.0234375 artifacts/fresh-amplitude.csv
```

Use `-keyon` on the decay scorer only for the configured-key-on complements.
Unresolved peaks, incomplete falls and features below the two-window limit
remain explicit results. Level sweeps compare absolute tail statistics and
retain low-level quantization limits; a missing relative-quality score is not
a passing result. Validate the scorer with:

```
go test host/decay.go host/decay_test.go
```

Generate finite stage-write and key-history controls separately:

```
go run host/history_programs.go -base artifacts/canonical-tone.bin -output artifacts/fresh-history
```

These sixteen fixtures include inactive and active stage writes, repeated high
key-on, repeated key-off, release/rekey and early repeated key-on during AR12.
Each manifest gives ordered writes, delay counts, baseline and positive-control
roles. Use the same event capture helper at native rate. For a held/repeated-key
comparison, apply the global `phase.go` fit across the complete recording;
independently fitting each side of the event could conceal a phase restart.
Model CPU-delay approximations preclude absolute intervention-latency claims.

## LFO waveform, depth and gating measurements

[LFO methods and coverage](plans/lfo-measurements.md) distinguish sample-period
measurements, finite depth/gate observations, quantized-zero bounds and unscored
noise sequences. Generate from a fresh canonical tone; profiles are `pilot`,
`am-depth` (128 cases) and `pm-depth` (224 cases):

```
go run host/lfo_programs.go -base artifacts/fresh-tone.bin -output artifacts/fresh-lfo -profile pilot
```

Default `-sampling extended` uses MUL4/stride2 for deterministic waves and gates;
W3 always uses native MUL8/stride1. `-sampling native` reproduces the original
short pilots. Keep each manifest's actual stride/rate/carrier and horizon when
capturing. The designated TEST bit is held during INIT, then released by EVENT;
no other TEST bits are used.

The isolated AM/PM extractor has separate guaranteed-held and guaranteed-post
bounds; the uncertain event region belongs to neither. For a stride2 PM pilot:

```
go run host/modulation.go host/tone.go -mode pm -increment 65984 -sample-rate 27968.75 -native-stride 2 -window 32 -hop 4 -pre-end-sample 512 -start-sample POST_BOUND -expected-period 2048 -csv artifacts/fresh-pm-curve.csv artifacts/capture-0-0.csv
go test host/modulation.go host/tone.go host/modulation_test.go
```

Use `-mode am` for isolated AM; use `-waveform noise` without an expected period
for native W3. A wrong expected rate cannot become a returned measurement.
Missing logarithms, insufficient cycles and low-depth resolution remain explicit.
The fixed global sine fit is reserved for disabled controls.

The separate joint estimator is qualified for the moderate W2/E0 pilot with
both depths64, AMS1/PMS4. It uses a fixed Hann-weighted projection and phase
differences, and preserves invalid low-amplitude segments:

```
go run host/joint_modulation.go host/tone.go -increment 65984 -sample-rate 27968.75 -native-stride 2 -window 128 -hop 8 -phase-lag 16 -pre-end-sample 512 -start-sample POST_BOUND -csv artifacts/fresh-joint-curve.csv artifacts/combined-0-0.csv
go test host/joint_modulation.go host/tone.go host/joint_modulation_test.go
```

These are output-domain features with stated window bias and synthetic
cross-talk limits. They do not qualify arbitrary combined waveforms/depths or
prove exact sample identity. All generated programs, CSVs and figures stay local.

Separate pan-marker fixtures retain a continuous right output while briefly
muting the left output three times. They include matched model controls with
the same delay sequence and no pan writes:

```
go run host/lfo_marker_programs.go -base artifacts/fresh-tone.bin -output artifacts/fresh-markers
```

These use C0, MUL0/stride 8 and recorded increment 32992. The marker method and
its finite continuity limits are documented in the LFO report; the joint E0
estimator's original qualification does not automatically extend to this setup.

## LFO depth storage and INIT ordering

[Storage methods and results](plans/lfo-storage.md) cover opposite-selector
writes, matched nulls, own-depth positives and reversed AMD/PMD INIT ordering.
The separate fixed 129-point squared-Hann extractor preserves the measured
sharp-corner limitation at AMD127:

```
go run host/lfo_storage_programs.go -base artifacts/fresh-tone.bin -output artifacts/fresh-storage
go run host/lfo_projection.go host/tone.go -column linear -csv artifacts/fresh-storage-curve.csv artifacts/capture-0-1.csv
go test host/lfo_projection.go host/tone.go host/lfo_projection_test.go
```

These commands run from the task directory. Use model column `right`, physical
latch1, and the exact C0/stride 8/MUL0 fixture; every constant/support is recorded.
This kernel leaves the earlier 128-point joint estimator unchanged. Coherent
comparisons use one late-data phase shift shared by AM and PM, with no per-event
alignment or physical sample-identity claim.

## C0 LFO channel/operator routes and selected history

[Methods and results](plans/lfo-history.md) cover individual carrier qualification
for all 32 channel/operator routes, ordered negative gate probes, isolated AM/PM
positives, and selected hold/reset/free-running/key-on histories. The primary
register/key mapping is explicit: offsets 0/8/16/24 use masks 08/20/10/40.

```
go run host/lfo_history_programs.go -base artifacts/fresh-tone.bin -output artifacts/fresh-history
go test host/modulation.go host/tone.go host/lfo_routes_test.go
```

These commands run from the task directory. Route features use the separately
qualified window64 isolated extractor at recorded increment32992/stride8;
129-point squared-Hann history curves retain their own support and floors.
Intentional KEYOFF silence and held TEST states have distinct checks. An
unchanged post-event fit alone does not establish uninterrupted earlier LFO
phase, and intentional reset controls must not be forced to match a null.

## Audio noise and off-envelope controls

[Noise methods and results](plans/noise-measurements.md) cover the 32 frequency
codes, selected NE/channel/operator/TL/EG controls, and an independent raw-pin
check of the off-state PCM floor. All targets require measured cleanup followed
by a separate quiet capture; keyed TL127 is an audible positive control.

```
go run host/noise_programs.go -output artifacts/fresh-noise
go test host/noise_score.go host/tone.go host/noise_score_test.go
go run host/noise_score.go host/tone.go -column linear -start-sample 128 artifacts/capture-0-1.csv
```

These commands run from the task directory. Use native stride1. Physical INIT
and model INIT differ deliberately: model INIT contains its finite cleanup wait;
physical use must measure the post-reply wait and verify both outputs quiet
before target INIT. Capture metadata now records the actual settle interval.
The native-rate classifier reports compatible sampled lattices and explicit
unresolved states; it does not recover every internal noise update, a seed,
polynomial or full sequence period. Physical exact-zero off-state output and
the tiny model residuals remain distinct from the coarse endpoint screen.

## Algorithms, feedback and joint key-on phase

[Methods and results](plans/algorithm-measurements.md) cover229 native profiles,
each with three targets and three independent quiet observations, plus separate
joint-key-on phase controls. Full key-mask/algorithm routing states, feedback
isolation, static stereo and full-level feedback stress retain absolute PCM
descriptors. Relative output phase and high-feedback periodicity remain explicit
limits; a finite harmonic residual is not a universal conformance verdict.

```
go run host/algorithm_programs.go -output artifacts/fresh-algorithms
go test host/algorithm_score.go host/tone.go host/algorithm_score_test.go
go test host/algorithm_phase.go host/tone.go host/sine_fit.go host/algorithm_phase_test.go host/algorithm_frequency_test.go
go run host/sine_frequency.go host/sine_fit.go host/tone.go -column linear INPUT.csv
```

Run these from the task directory. Separate model/physical INITs retain their
conditioning semantics. The phase observer uses one common timeline with
marked transitions excluded; its phases never correct complex algorithm
waveforms. Optional task-wrapper public bus/key-on phase diagnostics are
documented under `ver/jt51` and `ver/opm`; default output bytes are preserved.
The original full-sweep export failure, same-buffer recovery and idle recorder
rearms are retained in the local evidence, with no retaken measurement or reset.


## Static output mixing and overload descriptors

[Methods and results](plans/mixing-measurements.md) cover48 contributor/TL sums,
nine pan and six split-output profiles. Three repetitions give189 targets and
189 paired quiet captures; two campaign-final quiets and one separately recovered
first quiet make381 physical captures. Independent raw and descriptor audits pass.
The378 target-latch observations comprise342 bipolar and36 intentional pan-zero.
Absolute PCM/RMS/populations remain descriptive; unknown voice phases prevent
an exact ideal-sum or internal clipping/wrapping diagnosis.

```
go run host/mixing_programs.go -output artifacts/fresh-mixing
go run host/mixing_validate.go -input artifacts/fresh-mixing
go test host/mixing_qualify.go host/mixing_qualify_test.go
```

Run these from this task directory. The test builds all four standalone tools,
retains the original103 finite qualification trials/21 control reports, and
checks independent literal, malformed-input and exclusive-output refusals.
Original CLI bodies, thresholds and all130 generated catalog files are preserved.
Full scientific plots,126 model recordings,756 comparisons and capture provenance
remain local artifacts. Common-held-history controls are a separate next step.

## EG key-scale/key-code checkpoint

The [finite KS/KC envelope checkpoint](plans/envelope-measurements.md#kskc-boundary-and-zero-rate-checkpoint)
adds 23 main profiles and two held-carrier profiles: 152 physical captures and
50 frozen model outputs. Its descriptor report retains 138 physical and 92 model
observations; 48 eligible comparisons lie within the declared bounds and 44 are
withheld. Original model exceptions and sub-two-window limits remain explicit.
The source-promotion parity reproduced all 212 legacy and 50 new payloads, all
150 retained physical feature reports/curves, and the completed descriptor
report. This adds bounded KS/KC evidence, not full EG or chip completion.

Reproduce the fixed stimuli and whole-trace observer with explicit standalone
Go groups (new output paths):

```
python3 scripts/monitor.py emit tone --output NEW_TONE.bin
go run host/decay_programs.go -base NEW_TONE.bin -matrix ks-kc-main -output NEW_MAIN
go run host/decay_programs.go -base NEW_TONE.bin -matrix ks-kc-carriers -output NEW_CARRIERS
go build -o NEW_EG_TOOL host/eg_features.go host/eg_observer.go host/tone.go host/sine_fit.go
./NEW_EG_TOOL -export-geometries NEW_GEOMETRIES.json
./NEW_EG_TOOL -geometry native-kc40-mul8 -profile attack -input DECODED.csv -output NEW_FEATURE.json -curve NEW_CURVE.csv
```

The canonical tone must match SHA256
`d8f414e301521e4522739c7c845693e16dec01e4a265751f2352dbaab07e4c16`.
The frontend consumes decoded whole traces; capture/raw/conditioning audits
remain separate. Format completed descriptors with their actual reviews:

```
python3 scripts/eg-report.py --catalog NEW_MAIN/cases.json --geometries NEW_GEOMETRIES.json \
  --physical-audit ACTUAL_MAIN_AUDIT.json --model-audit ACTUAL_MODEL_AUDIT.json \
  --model-exceptions ACTUAL_MODEL_EXCEPTIONS.json --physical-review ROOT_MAIN_REVIEW.json \
  --model-review ROOT_MODEL_REVIEW.json --output NEW_DESCRIPTOR_REPORT
```

Focused source checks use explicit file groups; the existing standalone
envelope/decay CLIs keep their original interfaces:

```
go test host/decay_programs.go host/decay_programs_test.go
go test host/eg_features.go host/eg_observer.go host/tone.go host/sine_fit.go host/eg_features_test.go
python3 scripts/test_eg_report.py
```

The [finite audit complements](plans/audit-complements.md) add70 physical
captures:33 targets and37 entire-zero quiets across eleven selected noise,
split-CSM and low-LFO profiles. All six long-acquisition carriers qualify;
rate60 retains six coarse period results with its original fine screen unqualified,
and rate00 remains partial-only with no period extrapolation. The22 frozen
model outputs preserve both conditional OPM phase-fit exceptions. All48 model and66 physical outer source-parity comparisons are reviewed,
preserving69 physical primitives and36 exact physical curves.
The six confirmed gaps stay in the combined inventory; no new gap is inferred.
