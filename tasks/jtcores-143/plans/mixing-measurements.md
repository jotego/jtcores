# Static output mixing measurements

Work in progress for [jtcores #143](http://gitea.jotego.es/jotego/jtcores/issues/143).
Production jt51 remains `985a573dcfc1ff135553a39f7eae21d18ba57cbe`; independent
OPM remains `a0ab44be60cb28b68431779829454ddf3284f272`. No implementation or
reference correction is included. The complete63-case static matrix has passed independent raw transport and
analysis-integrity audits. Waveform/model descriptors remain observations.

## Frozen matrix and public observations

The immutable63-profile matrix has48 sum cases, nine pan cases and six split
cases. Sum cases combine contributor counts1/2/3/4/5/8/16/32 with literal
TL0/8/16/24/32/48. Pan cases use4/8/32 contributors atTL32 with neither output,
LEFT only or RIGHT only. Split cases use all32 contributors atTL0/24/32:
channels0–3 feed one output and4–7 the other, then the routing is reversed.

Every INIT explicitly disables TEST, noise, LFO modulation, CSM and timers,
sets ALG7/FB0, KC4A/KF0, MUL0/zero detunes, AR31/KS0, D1R0/D2R0/D1L0/RR15,
and writes the full224-register channel/operator image. Unused operators have
TL127. Contributor order is M1/C1/M2/C2 within successive channels, with primary
register offsets0/16/8/24 and key masks08/10/20/40. All eight channel KEYON writes
occur in order0..7. This ordering does not establish simultaneous phase reset.
The original target EVENT is00; target completion00 does not read status.

Physical targets contain16384 stereo frames at native stride1 after a measured
post-INIT wait>=0.05s. Each has an immediately preceding4096-frame quiet capture
after measured wait>=0.5s. Cleanup is the CSM-qualified stop-FIRST14=30,
NEoff/all32RR15/all8KEYOFF sequence, followed by STATUS03/00. Each capture consumes
two monitor generations and six fresh reply markers. Raw success is independent
of target waveform, pan, carrier-fit and model-agreement observations; failed
cleanup stops before the next target.

The63-profile model set has126 immutable stereo CSVs and252 public output-column
traces. Both models execute the same model-format INIT bytes, including1790016
master clocks of cleanup conditioning and262144 preheat clocks; physical-format
INIT has no such delay bytecodes. Model preheat and physical measured host wait
remain separate protocols. Original executables, public projections, CSVs,
sidecars and descriptive reports are pinned. Model internal/diagnostic columns
are not accepted as physical evidence.

Both physical latches are analyzed directly: latch0 LEFT, latch1 RIGHT, from
primary pan-control evidence. Every raw serial word is retained, with exponent,
biased/signed mantissa and unspecified low-bit populations. Integer decoding is
`(mantissa - 512) << (exponent - 1)`, with valid exponents1..7; no raw word is
reconstructed from PCM. CAP04 headers, all CSV/raw/PCM words, payload/metadata/
transfer hashes, boot/HPS/image identities and exact ordered reply chains are
checked independently.

The frozen descriptor retains absolute observed mean, RMS/AC RMS, integer
sums/squares, extrema, sign/zero and complete level/difference populations,
endpoint counts/runs, large jumps and quarter-record features. Jump threshold
4096 and endpoint queries−32768/+32704 are unchanged. Finite-window mean is an
observation, not an independently isolated analog DC offset. There is no phase,
gain or DC adjustment and no new chip-conformance tolerance.

## Completed nine-case pilot

The original model-pilot selection is reused physically: sumN1/N4/N5/N8/N32 at
TL0, sumN32 atTL32, N32/TL32 LEFT-only and neither-pan, and splitTL32 normal.
Three repetitions each give27 targets,27 paired quiet captures and one final
quiet:55 captures,110 monitor generations and330 reply markers. There are54
target-output observations,45 bipolar and nine intentional pan-zero; every pan
quiet policy matches the measured state.

The six N1 output checks independently fit rounded native increment4124 with
unchanged8170/−8 fitter defaults and phase RMS0.002032102–0.002034953, below the
existing0.01 guard. No stride8 free-fit guard is transferred to this native case.
All28 quiet captures are zero throughout BOTH outputs. Their actual word is
3004, exponent1, biased mantissa512. Quiet-word populations are observed rather
than required to have that canonical encoding.

| Pilot setting | Physical extrema | Physical RMS across repetitions/latches | Jumps>=4096 per record |
|---|---|---|---|
| N1/TL0 | −8176/+8160 | 5776.066–5779.487 | 0 |
| N4/TL0 | −32704/+32640 | 23103.506–23116.874 | 0 |
| N5/TL0 | −32768/+32704 | 25998.875–26013.441 | 0 |
| N8/TL0 | −32768/+32704 | 28934.873–28947.855 | 0 |
| N32/TL0 | −32768/+32704 | 27879.503–27913.164 | 1538–1560 |
| N32/TL32, both pans | −16064/+16032 | 11336.766–11343.122 | 0 |

The splitTL32 channels retain approximately−8144..+8128 PCM, with no jump meeting
the unchanged4096 threshold. The LEFT-only control has zero RIGHT output;
neither-pan is zero on both outputs. These are measured finite states and
descriptors, not an internal clipping or wrapping diagnosis.

There are108 descriptive pilot comparisons against the two model outputs for
each target/latch. Physical-minus-model RMS differences across all54 target
columns are−3970.526..+13.987 for jt51 and−172.456..+539.492 for OPM. Original
per-case values, levels, jumps, endpoint dwell and quarter observations remain
retained; model agreement is not a raw gate. Unknown interchannel/operator
phases and ordered KEYON prevent treating this static N/TL matrix as exact
linear-sum closure or an identified internal width/limiter mechanism. Further
common-held-history controls need their own method and qualification.

Independent pilot audit:
`artifacts/mixing-output/physical-pilot-independent-v2/completed-v3-pilot/audit.json`,
SHA`53bb9ddfe676549b2b7ea1bed9953b1a55ac563196816c2ddec736c26eee2cc5`.
All three raw gates and both analysis-integrity gates pass, with55 records and
no issues. All110 public-column descriptors/populations are independently
regenerated and checked. ROOT's feature review is
`artifacts/mixing-output/physical-pilot-root-review.json`.

## Retained first-quiet path failure

Before the completed pilot, an attempted run stopped after its FIRST quiet
capture, before any target. ROOT passed a relative output directory. The capture
wrapper used the absolute prefix to name its remote export; the independent
transfer-ownership check hashed the relative prefix and correctly rejected that
different name. Original FAILED metadata and complete capture/log files remain
unchanged. That file was never silently accepted into the pilot matrix.

Canonical absolute-prefix re-decoding verified all4096 words/CSV samples per
latch, valid exponents, input/transfer/reply hashes and zero output. A read-only
live poll independently confirmed the actual idle generation/marker state51/1452,
rather than trusting the failed driver's stale49/1446 bookkeeping. The original
relative ownership check still rejects. A first independent JSON-key comparison
failure is also retained; JSON canonicalization corrected only derived report
comparison, with numerical/raw guards unchanged.

Recovery audit SHA:
`0f38960ef53862cd9aa49e736298829fea7ada24b3d165c111cb5ef3270681df`.
It records one retained EXTRA quiet and zero pilot targets. No capture retake,
target/register resubmission, reset or ROM reload was needed for recovery.
The new driver changes exactly one boundary to `args.output.resolve()` and uses
fresh proposal/readiness/output identities. Its path proof reproduces both the
absolute ownership pass and original relative rejection. The completed55-record
pilot starts from the independently reviewed recovery quiet and has separate
unique capture IDs. This predecessor quiet remains outside that55 count.

## Completed remaining54 and combined63 results

The remaining54 cases preserve immutable manifest order after excluding exactly
the nine pilot names. Their three repetitions give162 targets,162 paired quiet
captures and one final quiet:325 captures,650 submitted INIT/EVENT programs and
1950 reply markers. Physical inputs comprise54 distinct original INIT files,
one shared EVENT00 and the unchanged cleanup/STATUS pair. The54 separate model
INIT files are pinned metadata, rather than additional physical submissions.

ROOT reviewed the completed pilot before authorizing this stage from its actual
final quiet at161/1782. It needs no reply recorder rearm; planned final state is
43/3732, which the completed run reached. Its terminal reports325 captures,
162 targets and163 quiet controls. The new runner preserves acquisition/raw/descriptor bodies and the
canonical output-path boundary. Its separate independent auditor is frozen
before new remaining physical data reads.

Both actual acquisition handles and both independent audits terminated0. The
remaining audit has325 records, no issues, all three raw gates and both
analysis-integrity gates true. Its650 output descriptors and complete primary
raw/exponent/mantissa populations reproduce independently. Audit SHA:
`a143c88110e2b1b0afe75be53f0dad4280091e8450d550a651546e3a2757a273`.

The complete63-case matrix contains378 matrix captures (189 targets/189 paired
quiet) plus TWO separate campaign-final quiet captures=380. The retained
recovery predecessor adds one separate quiet, giving381 total physical captures
and192 quiet captures without increasing target coverage. All quiet recordings
are entire zero on both outputs. The760 campaign public columns include378
target columns:342 bipolar and36 intentional pan-zero, with no pan-state
mismatch. The separate recovery quiet adds two public columns.

All126 immutable stereo model recordings and756 target-latch/model comparison
rows are retained. Across the378 target columns, physical-minus-model RMS
ranges are−3970.526..+13.987 for jt51 and−356.184..+539.492 for OPM.
These are descriptive ranges across different profiles, not a single fitted
gain or error tolerance. Low-level, overloaded, split and pan profiles remain
separate. No reference is patched to match the physical observations.

The combined report is `artifacts/mixing-output/physical-full63-summary-v1`.
Its126 case/latch rows preserve all three physical repetitions as min/max
ranges;378 individual target-latch rows and252 exact model-latch rows retain
original values and source hashes. Full distributions, endpoint dwell,
first differences and quarter features remain in the frozen descriptor reports.
The scientific RMS figure selects all48 sum profiles and shows repeat/output
ranges without phase alignment, normalization, an ideal-sum curve or a chip band.
Unknown voice phases, ordering and latch ages still prevent exact linear-sum
closure or identification of a clipping/wrapping mechanism. Common-held-history
controls are prepared separately and are not included as measured coverage here.

Combined summary SHA:
`edc364d5d2497aa11f9910d025773dbe8862c18ac24b504073a08523a1ff3ed3`.
The final state is verified idle generation43/markers3732; no PCB reboot or
ROM reload was needed. Any later campaign requires its own reviewed protocol
and actual readiness; no future counter state is inferred from this checkpoint.


## Reproduce the promoted tools

Run from `tasks/jtcores-143` with fresh output paths:

```
go run host/mixing_programs.go -output artifacts/fresh-mixing
go run host/mixing_validate.go -input artifacts/fresh-mixing
go run host/mixing_describe.go -input INPUT.csv -column linear -lower-level -32768 -upper-level 32704 -output artifacts/fresh-description.json
go test host/mixing_qualify.go host/mixing_qualify_test.go
```

The explicit-file test builds the four standalone tools and runs the original
finite qualification once:103 trials and21 control records. It reproduces130
catalog files and checks literal stimulus errors, self-consistent wrong TL,
empty digests, duplicate JSON fields, malformed CSV, invalid CLI and exclusive
output refusal. Optional `JT143_MIXING_REPORT_DIR` must name a new directory;
without it the reports use the test's temporary directory. The four promoted
CLI files remain byte-identical to their frozen originals.

Promotion validation additionally compares all130 catalog files with the frozen
catalog, and all21 complete descriptor JSONs with the frozen `c0479a7d` observer
on identical CSV paths/arguments. Reports that embed relocated executable paths
and hashes are preserved with their actual identities; the whole relocated
qualification report is not claimed byte-identical. Four builds, standalone
and test-pair vet, focused test and test-binary build pass. Evidence is under
`artifacts/mixing-output/promoted-validation-v1`, including compatibility,
source/build identities and provenance. No test launches models or hardware.
