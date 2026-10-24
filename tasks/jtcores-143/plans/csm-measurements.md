# Finite CSM measurements

Work for [jtcores #143](http://gitea.jotego.es/jotego/jtcores/issues/143).
Production jt51 remains frozen at `985a573dcfc1ff135553a39f7eae21d18ba57cbe`;
the independent OPM reference remains at
`a0ab44be60cb28b68431779829454ddf3284f272`. No implementation is changed by
these measurements. Raw captures and campaign drivers remain local artifacts.

## Primary scope and interfaces

Yamaha's application notes, printed pages 12–14 and 16 (PDF pages 13–15 and 17),
describe Timer A's period as `64 * (1024 - NA)` master clocks and register14 bit7
as permitting automatic key-on in all sound-source slots on Timer A overflow.
Register08's manual key masks are independent of register-slot ordering:

| Operator | Register offset | Manual key mask |
|---|---:|---:|
| M1 | 0 | 08 |
| M2 | 8 | 20 |
| C1 | 16 | 10 |
| C2 | 24 | 40 |

The channel occupies the low three key-register bits. The primary description
does not establish exact automatic pulse width, manual-key priority, first-key
behavior on timer load, phase reset, or a particular CSM attack waveform.
Physical IRQ and accepted bus-write timing remain unobserved. The independent
public-interface/source map is `artifacts/csm/interface-summary.md`; source
hypotheses are kept separate from physical output observations.

All recordings use native stereo frames, nominal 55937.5 Hz, with latch0 LEFT
and latch1 RIGHT. Capture mode3 applies invert15 to correct the open-drain
adapter; independent word decoding verifies that configuration and decodes the
already-corrected words. The user's on-pin 3.57–3.58 MHz measurement with
0.01 MHz tolerance supports nominal 3.58 MHz. Period comparisons primarily use
native sample counts and do not depend on finer absolute clock accuracy.

## Stimuli, capture qualification and cleanup

The selected voice is channel0/C2, ALG7/FB0, KC4A/KF0, MUL8 with zero detunes,
TL0, AR31 or the explicit AR30 sibling, KS0, D1R0/D2R0/D1L0/RR15, both pans.
Other operators have AR0/KS0/TL127/RR15; other channels have pan0. TEST, noise,
AM and PM are disabled. TL127 is not assumed to guarantee exact silence:
inactive controls are measured independently.

Targets contain 16384 frames per latch. Immediately preceding cleanup captures
contain 4096 frames per latch. Cleanup FIRST writes14=30 to disable CSM, stop
both timers and clear flags, then disables noise, writes RR15 to all32 operators,
and finally writes KEYOFF to all8 channels. At least0.5 seconds is measured
after the INIT completion reply before arming quiet capture. Every quiet record
must be zero throughout on BOTH outputs, with valid exponents and framing.
The earlier noise cleanup lacks the stop-CSM write and cannot qualify this use.

Twelve adverse preflight captures independently establish this cleanup after
all32 automatic-CSM/RR0 and all32 manually-held/RR0 histories, three repetitions
of each positive/quiet pair. All six positives have bipolar first512 prefixes;
all six quiet records are entirely zero. The minimum observed wait is
0.500072669 seconds. STATUS03 inside each preflight capture EVENT gives1 after
positive histories and0 after cleanup. Independent raw audit SHA:
`c93d8f503a2bd6688a62c9db623f26286988c64521450e6192e4f76b89ed1ffd`.

The selected physical fixtures use short EVENTs ending immediately after the
intervention write. Their original longer EVENTs and original model results
remain preserved. The short form removes only the trailing3072-count delay and
STATUS instruction. Status is instead read by a separate03/00 command after
capture, with its own generation and three reply markers. A write-only
completion00 is never treated as an observed timer flag.

The guaranteed first512 samples follow ARM-before-EVENT and the literal initial
delay. Post-event analysis starts at
`ceil((event_host_end - arm_host_start) * 55937.5) + 128`.
This host upper bound is measured per recording, rather than replaced by a
planned delay. At least1024 samples remain for state tests; cadence tests require
`6 * nominal_period + 64`, including6208 at period1024. Insufficient horizons
and raw-valid feature failures are retained without a retake or changed guard.

Raw qualification checks CAP04 headers, requested/native counts, zero framing
errors, every exponent1..7, all raw words and PCM values against both CSVs,
input/transfer/metadata hashes, the unchanged boot/capture-tool/monitor image,
and the complete ordered generation/reply chain. These checks are independent
of target waveform or reference agreement.

## Frozen energy method

The original numerical method is
`artifacts/csm/method-before-models.json`, SHA
`77d4bf6a31fc069fbf06570ed9a81ab862344e7f7301b0191d3107cb810f6ae8`.
It uses a32-sample rectangular power window, hop1, peak floor32 PCM,
q10/q99 power contrast at least0.2, rising midlevel crossings clustered by
64-sample gaps, and at least five retained rises. Median crossing spacing is
estimated without an expected-period input. Periods below128 and interval
spread above64 remain unresolved; finite support is measured median±64.

Of1134 generic sine-burst controls,1121 resolve with their true period inside
the unchanged support band;13 irregular/unresolved controls are retained.
Thirteen negative held/silent/stuck/tiny/noise/fast/irregular controls reject a
cadence claim. These are finite method qualifications, not chip tolerances or
an implementation of the YM2151 timer/key/envelope algorithm. A held carrier or
quiet output receives no forced period.

## Selected physical results

Six AR31 pilot fixtures and ten further selected fixtures each have three
targets and three paired quiet controls. The two stages contribute96 matrix
captures plus two separate final quiet captures. With the adverse preflight,
this is110 physical recordings. All raw, chain, quiet, horizon and separate
status checks pass. The later stage's minimum remaining target horizon is8406
frames, and all31 quiet records in that stage are entirely zero.

AR31 14=81 and14=85 give repeated physical output near512 frames. The first
stage's measured medians are511.425483–511.504055, with18–22 retained rises and
maximum interval spread2.542257. Independent OPM supports this cadence and
output extent. Matching frozen jt51 automatic targets remain quiet. This is a
selected-output functional discrepancy; exact attack shape, key pulse width and
internal cause are not assigned from it.

Further independently measured physical medians are256.465943 at nominal256,
1024.710324–1024.918110 at nominal1024,511.42548–511.44286 when enabling CSM
on an already-running Timer A, and511.42548–511.50405 in the AR30 automatic
siblings. All30 later automatic output observations support their nominal
period within the original±64 band; their physical/OPM finite support intervals
overlap. AR30 preserves the automatic-output observation across a second
configured attack rate without establishing a general CSM attack-shape result.

Manual positives and manually held histories independently fit rounded native
increment65984, phase RMS below0.01, with independent rising-crossing checks.
The18 later carrier checks retain phase RMS approximately0.00203355–0.00204335.
The manually held physical carrier remains continuous with CSM enabled in the
specified experiment. This is finite output evidence, rather than a universal
manual-priority or internal-key assertion.

CSM off, neither timer running, and Timer B alone give measured quiet controls.
Disabling CSM while leaving Timer A running, or stopping Timer A while leaving
CSM set, gives bipolar history prefixes and exact-zero final4096 physical tails.
The frozen models retain their sparse/low-level window differences. Those
classifications remain explicit; no cadence is forced onto these tails and no
exact release latency is inferred.

Actual separate flag reads give1 for the IRQ-enabled automatic fixtures and0
for the listed disabled-flag controls. Audio triggering persists with flag
acquisition disabled. The already documented timer-flag mismatch remains a
separate observation; status is not a physical IRQ measurement.

Independent pilot audit SHA:
`68549519572d24095bc3a754533e67afa96b3c2dd65d92c6efb1ddb0732dfd6c`.
Independent remaining-selected audit SHA:
`b45d306fb5d2c7f44677755096aec8d8b0e7d28abd610fa7f0ca6a4ce019fd0e`.
The latter deliberately separates four raw qualification gates from retained
case observations. It has no invented general conformance flag. Physical and
terminal hashes are linked in each audit and in ROOT's separate review.

## All32 route extension

The frozen72-profile catalog contains32 manual positives,32 automatic CSM
profiles and8 same-channel background nulls. Each selected operator has its own
complete public register image and matched manual/background controls. All144
stereo whole-model recordings are independently audited; alongside68 selected
pilot/preflight recordings (including retained long/short EVENT variants), the
CSM reference set contains212 stereo CSVs, or424
public output-column traces.

Physical acquisition is split deliberately: first32 manual routes and8 background
channels, each repeated three times, then the32 automatic routes only after
independent review of all controls. The numerical methods and stimulus bytes
are frozen before route captures.

The controls stage is complete:120 targets,120 paired quiet captures and one
final quiet, with120 separate status commands. All32 manual routes independently
qualify192 carrier fits and independent crossing checks. Free increments are
65983.999580–65984.002407, rounding to65984; phase RMS is
0.002028029–0.002043175 radians. All48 whole-output observations from the eight
background channels are exact zero. All240 first512 target-output prefixes are
zero; all120 actual separate status reads give0. All121 cleanup records are zero
throughout on both outputs; minimum measured wait is0.500078158 seconds. The
shortest actual remaining target window is9080 samples, exceeding1024.

The independent controls audit has four raw and five feature gates, all true,
with no raw issues or feature errors. Audit SHA:
`7a29e20fc628f2f03d873ea9be9f7bf33db12a452275b5507111243b0bd7a18a`.
Its480 descriptive physical/model comparison rows have no reference-agreement
gate. ROOT's separate review is `artifacts/csm/route-controls-root-review.json`.

After that review, the existing idle-only monitor recorder rearm archived its
1024-byte window and renewed markers3096→0 while generation79, the ROM bank,
mapping and monitor image stayed unchanged. The window contains the recorder's
recent ring; complete earlier chronology is preserved in capture/status metadata.
This is neither a PCB reset nor a ROM reload. Report SHA:
`fa886474da59ab98ea826cdf59b63af477a7cdbdff7c19f9c3dddccbdc640fdf`.

The automatic stage adds96 targets,96 paired quiet captures and one final quiet,
with96 separate status commands. All32 routes have three independently
initialized targets and BOTH measured outputs:192 nonzero observations, each
with resolved finite cadence. Measured periods are511.425483052–511.504054612
native samples, with18–24 retained rises and maximum interval spread2.542256535.
Every unchanged support interval includes512. All97 quiet captures are entirely
zero on both outputs, all192 first512 output prefixes are zero, and all96 actual
separate status reads give0. The shortest actual remaining target window is9351
samples, exceeding3136; minimum cleanup wait is0.500068748 seconds.

All192 physical outputs retain extrema−6304/+7568. Corresponding frozen jt51
outputs are quiet in all192 descriptive comparisons, while all192 OPM comparisons
resolve repeated output with support overlapping the physical interval. Matching
physical manual and background controls qualify independently for every route.
This extends the confirmed automatic-output discrepancy across all32 configured
routes. It does not prove simultaneous internal key events, exact attack shape,
pulse width, accepted bus phase, or a particular RTL cause.

The automatic independent audit has four raw and four feature gates, all true,
with no raw issues or feature errors. Audit SHA:
`3fb9f9f341d1863c0892e03203b7a52847ea45b7e114a5b93aabeb5b47f64d81`.
ROOT's separate review is `artifacts/csm/automatic-routes-root-review.json`.
The two route stages contribute432 matrix captures and TWO separate final quiet
captures. Together with12 adverse preflight and98 selected-stage recordings,
the CSM campaign contains544 physical recordings. Source generation counts are
separate from physical coverage.

The reproducible selected-output figure is
`artifacts/csm/figures/selected-csm-output.png`, SHA
`5338baf59616b206e84a327058e476490d670e8268fe6f9c2e85c362e69cb909`.
Its three panels show separate2048-frame windows after each recording's measured
post-event bound. Raw CSV hashes and plotted intervals are retained in the
adjacent provenance JSON. There is no write-time alignment, phase adjustment or
gain normalization; the figure illustrates channel0/C2, rather than replacing
the all32 numerical audit.

## Reproduction and verification

Run these from the repository root; each CLI has its own main/type declarations,
so use explicit Go source lists and fresh output directories:

```
go run tasks/jtcores-143/host/csm_programs.go -output NEW_LONG31 -attack 31
go run tasks/jtcores-143/host/csm_programs.go -output NEW_LONG30 -attack 30
go run tasks/jtcores-143/host/csm_short_programs.go -input NEW_LONG31/cases.json -output NEW_SHORT31
go run tasks/jtcores-143/host/csm_short_programs.go -input NEW_LONG30/cases.json -output NEW_SHORT30 -names a512-csm-on-irqoff,a512-csm-on-irqon,manual-key-positive
go run tasks/jtcores-143/host/csm_routes_programs.go -output NEW_ROUTES
go run tasks/jtcores-143/host/csm_preflight_programs.go -output NEW_PREFLIGHT
go test tasks/jtcores-143/host/csm_energy.go tasks/jtcores-143/host/csm_energy_test.go
go test tasks/jtcores-143/host/csm_short_programs.go tasks/jtcores-143/host/csm_short_programs_test.go
```

The short converter emits EVENTs and a manifest, preserving unknown metadata,
INIT/model_INIT and original EVENT provenance. Shared STATUS03/00 comes from
the preflight/routes generator. The preflight generator emits two adverse INITs
and STATUS; its cleanup is copied from the identical common024e cleanup above.
No generator or converter authorizes hardware acquisition.

Promotion reproduces318 original binary output paths and the common cleanup
copy, with identical manifest metadata after only explicit path normalization.
Both original energy qualification reports reproduce byte-for-byte. The four
original CLI bodies are unchanged below their first-line comments. Existing
energy test stimulus/math/assertions are unchanged; routine reports now use
temporary directories, or a fresh exclusive directory selected with
`JT143_CSM_REPORT_DIR`. The converter validates all source hashes/operations and
historical EVENT shape before creating output and rejects malformed catalogs,
invalid selections and reused output paths. Five standalone builds, tests, vet,
CLI/parser/exclusivity checks and independent raw/feature audits pass. Exact
commands and per-file proofs are under `artifacts/csm/promoted-validation`.

Production RTL and frozen campaign executables remain unchanged.

Fast-period corners, exact pulse width/first-key timing, additional mixed manual
masks, broad histories, physical IRQ and internal phase remain outside this
finite experiment. Existing envelope discrepancies must remain distinguishable
from a newly observed automatic-output difference.
