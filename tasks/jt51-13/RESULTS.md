# Replacement-history results

Physical acquisition, all84 target model runs, their three independent audits,
and the252-row joined public-output audit are complete. The joined table covers
42 targets on the PCB, production JT51 and external OPM, each with three
repetitions per condition and both latches. Separate positive and quiet controls
retain their own roles. Archive publication follows the [archive guide](plans/archive.md).

The final physical set contains 42 targets and 42 paired whole-record quiets:
36 controlled targets and six longer natural-event/isolated captures. Every
target has nonzero bipolar public output on both latches. Every quiet has exact
zero PCM throughout both latches. The additional positive-control cohort has
three independently initialized repetitions at each stride1/3/32, with nine
separate quiet recordings. Its independent audit also passes:18 positive output
streams are nonzero and bipolar, and18 quiet output streams are exact zero.
The imported stride1 baseline quiet precedes its positive; the eight new pairs
use target-then-quiet ordering. The manual baseline retains a retrospective
ROOT-observed exit proof rather than an invented subprocess log.
The archive retains116 physical capture containers in total:102 primary
target/control recordings and14 earlier partial, superseded or exploratory
recordings. Primary qualification does not relabel those earlier attempts.

The independent audits re-read the original capture containers, validate headers,
transfer hashes and serial-word exponents, and compare every captured raw16 word
and decoded linear sample against the saved CSV. They recompute populations,
exact integer sums/squares, RMS, all sixteen fixed1024-sample blocks and the
separate whole-peak normalization. No stream is shifted, cropped or fitted.

## Observed physical levels

The table reports LEFT/latch0 whole-window RMS ranges over three repetitions,
in serial PCM units. Full precision, RIGHT, populations and fixed-block energies
are preserved in the descriptor indexes. Windows have independent recording
origins. These descriptive ranges are not agreement tolerances or isolated
measurements of an envelope rate.

| Probe | Stride / nominal seconds | Conditioned or isolated RMS | Preserved RMS |
|---|---:|---:|---:|
| Original AR12/ALG0 program | 1 / 0.293 | 1972.80–1982.31 | 1956.39–1966.74 |
| Original release-entry program | 3 / 0.879 | 2721.41–2738.75 | 2729.01–2733.54 |
| RR0, KS0, KC00 | 32 / 9.373 | 4269.93–4296.47 | 4271.43–4281.19 |
| RR0, KS3, KC04 | 32 / 9.373 | 4068.95–4114.13 | 4079.71–4104.44 |
| RR0, KS3, KC08 | 32 / 9.373 | 3929.20–3943.74 | 3933.62–3945.94 |
| RR0, KS3, KC10 | 32 / 9.373 | 3397.28–3412.50 | 3393.42–3416.98 |
| Natural replacement ALG0 event | 3 / 0.879 | 12.70–12.71 | 3974.21–4050.16 |

The six controlled probes use identical EVENT bytecode between their conditioned
and preserved variants. The natural comparison deliberately differs: the
preserved EVENT contains1200 writes, four key-ons and the existing multi-channel
background, while the isolated control keys on one selected program. Its large
level difference is therefore not attributed solely to preceding history or to
a routing defect. The small isolated signal remains nonzero and bipolar, with
its exact quantized populations retained.

RawRR0 maps to documented RR base1. The four KS/KC choices give six-bit arithmetic
rate indices2/3/4/6, or mapped low rates1/1.5/2/3. Register labels and the arithmetic
convention are kept separate from observed envelope state. The original attack
probe preserves rawAR12/KS0 atKC1D, giving arithmetic effectiveAR24.

## History and timing

The user authorized this newly recorded input after the original98880-write
CSV could not be recovered. Both deterministic captures of the replacement
have identical209206 writes and timestamps. The prefix preserves every one of
the107500 preceding register writes, including repeated1B writes, followed by
the selected1200-write natural EVENT. Independent compiler and frontend audits
compare the entire ordered sequence to the canonical source bus.

The physical8KiB tables require host pauses. Source intervals are mapped to
4MHz source master cycles using the documented80-clock write allowance and
approximately37.5 master clocks per CPU delay count. The models execute every
chunk in one instance and retain fractional delay carry. Recorded gaps and the
37.5 approximation do not make CPU and public-model bus overhead identical.
Physical ARM also precedes EVENT upload, whereas model recording starts at its
EVENT. Exact accepted-write phase, elapsed-age equality, direct counter state,
continuous MAME timing and whole-song equivalence are not established.

The longer natural captures cover the complete EVENT: conservative completion
bounds plus128 support samples end at8615/8414/8652 of16384 retained frames for
the three preserved repetitions, leaving at least7732 post-bound samples. The
isolated bounds end near2941. Earlier stride1 natural attempts are retained
with their partial EVENT horizons; their complete isolated controls are
superseded by the matched longer geometry. The exploratory preserved capture
also retains its unusually long host gap.

All physical commands ended with valid replies. The final monitor is idle at
generation100,2736 reply markers, status0, no pending command or dropped bytes.
The boot-bank SHA, Chameleon boot identity, capture protocol and capture-tool
identity match the qualified baseline. No boot firmware or FPGA image was
replaced. The final positive/quiet operation leaves the PCB quiet.

## Classification and source evidence

All84 model runs finish with16384 retained frames and their complete EVENT inside
the window. All168 public model streams are nonzero and bipolar. Exact-zero
pretrigger blocks remain in the descriptors; they are not discarded. The
independent saved-output audits rehash every pinned input/output and recompute
public PCM statistics. The final joined audit covers252 targets and84 separate
physical quiet columns;24 model control streams and36 physical positive/quiet
streams retain their separate completed audits. These396 primary descriptors
are not396 independent targets.

The fixed-block plots are available as [LEFT/latch0](http://gitea.jotego.es/attachments/636427b5-1f3b-4477-9cf0-1fe918c5caa9)
and [RIGHT/latch1](http://gitea.jotego.es/attachments/6d911ca9-c1e7-4552-9732-e1a8d0273159).
Both PNG and PDF originals are archived. Every plotted point is the raw RMS of
one fixed1024-sample block; each stream retains its own recording origin. There
is no phase, age, gain or event alignment and no waveform agreement threshold.

The original attack/release and natural isolated windows show finite transients
on all three sources. The natural preserved window retains its different mixed
EVENT context; its shapes and RMS differences do not isolate a history defect.
The two lowest configured release families show a distinct production hold
instead of the physical fade. Their final classification is recorded below
and in the [combined inventory](plans/gaps.md). The previously supported six
requirements retain their own evidence and limits. No RTL has changed.

### Whole-window public model levels

These LEFT/latch0 ranges summarize three repetitions in serial PCM units. They
are descriptive whole-window values; the fixed-block curves preserve the actual
transient shape. The physical ranges are in the earlier table. RIGHT and every
full-precision value are retained by the joined index.

| Probe | Original condition | JT51 RMS range | OPM RMS range |
|---|---|---:|---:|
| original-attack | conditioned | 1992.81–2027.30 | 1997.88–2014.64 |
| original-attack | preserved | 1969.98–2003.16 | 1983.88–1992.18 |
| original-release | conditioned | 2619.55–2668.45 | 2715.59–2733.87 |
| original-release | preserved | 2667.65–2731.59 | 2719.00–2728.59 |
| rastan-event | isolated | 12.62–12.65 | 12.71–12.78 |
| rastan-event | preserved | 4284.79–4369.84 | 3964.86–4023.81 |
| rr0-ks0-kc00 | conditioned | 5749.94–5749.96 | 4269.26–4274.27 |
| rr0-ks0-kc00 | preserved | 5749.94–5749.97 | 4272.33–4274.48 |
| rr0-ks3-kc04 | conditioned | 5750.10–5750.23 | 4112.32–4113.39 |
| rr0-ks3-kc04 | preserved | 5750.12–5750.23 | 4071.66–4077.62 |
| rr0-ks3-kc08 | conditioned | 3880.22–3881.47 | 3921.03–3922.37 |
| rr0-ks3-kc08 | preserved | 3903.44–3944.70 | 3916.48–3951.06 |
| rr0-ks3-kc10 | conditioned | 3336.53–3338.67 | 3407.76–3410.11 |
| rr0-ks3-kc10 | preserved | 3317.39–3401.03 | 3407.28–3418.23 |

### Confirmed additional low-release requirement

At raw RR0 with KS0/KC00 and KS3/KC04, PCB and OPM output fades after key-off
while production JT51 stays near full level through all15 complete late blocks.
This repeats in both history conditions, all three repetitions and both latches.
The adjacent KC08/KC10 controls fade in all three sources. The carrier uses
MUL8, ALG7/FB0 and C2 TL0 with the other target operators at TL127; no odd-MUL
pitch assumption or exact operator silence is needed.

For KS0/KC00, physical block1 RMS is5490.882–5529.257 and block15 is
2996.752–3016.637. JT51 stays at5776.734516 in every block1–15. At KS3/KC04,
physical RMS falls from5409.784–5487.464 to2671.330–2697.743; JT51 remains near
5776.69–5776.82. Raw peak levels independently corroborate the physical fade
and production hold. Every physical completion bound plus128 samples is at
560–653, and each model KEYOFF plus128 is at469, before block1 starts at1024.
Thus these are complete post-command observations, with no onset alignment.

The [independent saved-only review](plans/low-release.md) verifies144 target
streams across all four configurations,48 model journals,24 physical completion
records,48 paired quiet outputs and20 separate stride32 control outputs. It
adds a seventh finite public-output requirement to the six previously supported
requirements. It does not claim infinite hold, exact release time, direct EG
state, an internal cause or universal rate/carrier agreement. The conditioned
program already reproduces the difference; a music prefix is not essential.
The existing combined [jt51#14](http://gitea.jotego.es/jotego/jt51/issues/14)
receives all seven requirements; no RTL fix is included in this task.

Physical indexes: `artifacts/physical-raw-energy-01/descriptor-index.json` and
`artifacts/physical-natural-raw-energy-02/descriptor-index.json`. Their final
saved-output audits and execution proofs are adjacent. Model inputs, actual
commands, per-chunk journals and audits are under `artifacts/model-proposal-*`
and `artifacts/models-*`. The [requirement map](plans/coverage.md) and
[public-interface/timing plan](plans/model-history.md) bind their scope.
