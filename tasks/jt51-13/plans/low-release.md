# Low raw-RR0 release: independent saved-output review

The saved evidence supports an additional **finite public-output release
requirement** for the two tested low-rate configurations. In both history
conditions, all three repetitions and both latches, PCB and OPM amplitudes
decrease after key-off; JT51 remains near its full earlier level through the
late portion of the same finite window. Adjacent KC08/KC10 controls decrease
on all three sources. This is not a claim of infinite hold, an internal cause,
one EG count, exact release timing or universal carrier agreement.

Review process22471 exited0. It used saved files only:144 target streams
(4 configurations x2 conditions x3 repetitions x3 sources x2 latches),24
physical command/completion records,48 model EVENT journals,48 paired physical
quiet streams and20 separate stride32 positive/quiet control streams. Existing
CSV block integer sums of squares and raw extrema were independently compared
with all144 saved descriptors. No model, energy helper, hardware command, fit,
alignment or new acceptance band ran. Prior six requirements remain unchanged.

## Exact stimulus and interpretation

All cases use channel6, ALG7/FB0, both pans, selected C2 MUL8/DT1=DT2=0, TL0,
AR31, D1R0/D2R0/D1L0/rawRR0. The other three target operators have TL127, which
is attenuation rather than guaranteed silence. All other channel pans are off;
CSM/noise/LFO sensitivity/TEST hold are disabled in the reconstructed literal
register image. Both preserved and conditioned final images were checked.
AR31's known attack behaviour is not used as a new attack-shape comparison.

The EVENT is delay8192,8199 or8211; register08=7E (all four channel6 keys on);
delay10408; register08=06 (all four keys off); END. Model journals contain these
two exact writes, with no later EVENT write. Physical replies and completion
markers follow the complete unchanged bytecode. These are not observed chip
acceptance timestamps. All literal INIT/EVENT files and metadata are pinned.

Yamaha application notes printed page9/PDF10 describe key-off entering release
and attenuation advancing, with RR key-scaled. Figure2.12, printed20/PDF21,
defines RR input R=2*storedRR+1 and RATE=2R+Rks. The tested labels are:

| Stored RR | KS | KC | Rks | Arithmetic RATE | RATE/2 label |
|---:|---:|---:|---:|---:|---:|
| 0 | 0 | 00 | 0 | 2 | 1 |
| 0 | 3 | 04 | 1 | 3 | 1.5 |
| 0 | 3 | 08 | 2 | 4 | 2 |
| 0 | 3 | 10 | 4 | 6 | 3 |

These are public-register arithmetic labels, not recovered internal EG counts.
The general attack/decay timing table's infinite low-rate entries are not used
as a numerical release oracle; the finite release requirement here rests on
the directly repeated physical observations. This is separate from raw-zero
AR/D1R/D2R inhibition and its previously recorded requirements.

## Fixed-block observations

Each entry is the minimum--maximum over12 observations per source: two history
conditions, three repetitions and both latches. Values are existing raw PCM RMS
from1024-sample blocks, with block indices zero-based. The full arrays and raw
peak levels are in observations.json; there is no onset alignment.

| Configuration | Source | Block1 RMS | Block15 RMS |
|---|---|---:|---:|
| ks0-kc00 | physical | 5490.882--5529.257 | 2996.752--3016.637 |
| ks0-kc00 | jt51 | 5776.735--5776.735 | 5776.735--5776.735 |
| ks0-kc00 | opm | 5487.037--5496.227 | 2993.339--2996.927 |
| ks3-kc04 | physical | 5409.784--5487.464 | 2671.330--2697.743 |
| ks3-kc04 | jt51 | 5776.688--5776.820 | 5776.688--5776.820 |
| ks3-kc04 | opm | 5417.418--5473.493 | 2667.973--2692.651 |
| ks3-kc08 | physical | 5402.451--5430.674 | 2407.531--2418.546 |
| ks3-kc08 | jt51 | 5315.829--5410.630 | 2371.211--2411.198 |
| ks3-kc08 | opm | 5371.956--5421.591 | 2392.485--2414.767 |
| ks3-kc10 | physical | 5209.514--5247.305 | 1548.036--1560.436 |
| ks3-kc10 | jt51 | 5086.092--5214.137 | 1507.850--1545.918 |
| ks3-kc10 | opm | 5216.553--5234.730 | 1551.463--1556.968 |

For KC00, JT51's late-block RMS is exactly5776.734515967369 in every block1--15
of every selected stream. For KC04 its within-trace late RMS span is only
0.043691--0.170520PCM. The PCB's corresponding within-trace changes are
2494.130--2512.620 and2738.454--2790.922PCM.

This is also visible in raw peaks, independently of block RMS averaging:
KC00 PCB peaks fall from7920--8000 in block1 to4320--4368 in block15; OPM has
the same endpoint peak ranges, while JT stays8176. KC04 PCB peaks fall from
7824--7920 to3856--3912; OPM falls from7824--8000 to3872--3912; JT stays8176.
The adjacent configurations have falling RMS and raw peaks in JT as well.

## Timing, controls and limits

All physical final-completion host upper bounds with the pre-existing128-sample
guard lie at retained sample560--653. Model KEYOFF public timestamps plus the
same128-sample guard lie at469. Thus every compared late block (beginning with
sample1024) lies after those conservative bounds, with15 complete late blocks
retained. A short or unexecuted key-off cannot explain the plateau.

The nominal window is9.372746369s at stride32/Fs55937.5. Physical header-derived
native rates span55865.921788--55991.041433Hz; model clocks remain nominal.
Actual rates and different ARM/EVENT origins are retained rather than aligned.
No precise common key-off latency, time constant or exact model/PCB decay-rate
agreement is claimed. The low-RR effect appears with and without the complete
replacement prefix, so a prefix-only gap estimate is not necessary to observe it.

All48 paired quiet outputs are exact zero. The six separate physical stride32
positive streams are bipolar, as are the four model positive streams; matched
six physical/four model quiet controls are exact zero. Identical decimation and
public-output paths therefore pass their nonzero/quiet controls. KC08/KC10
provide additional declining-release positives within this four-case family.

Carrier phase, decimation and quantization remain limits on detailed waveform
interpretation; this review does not newly qualify carrier frequency or recover
a native envelope. They are not a plausible supported explanation for this
repeated large public-level difference: the same literal low-KC programs decay
on PCB/OPM, JT receives completed key-off writes, and raw peak levels corroborate
RMS. Residual TL127 operators and AR31 attack differences are retained in the
program scope rather than asserted absent. Nothing here establishes the RTL
mechanism, excludes all untested parameter combinations, or changes old bands.

## Suggested requirement for jt51#14

For the tested rawRR0 programs at KS0/KC00 and KS3/KC04 (arithmetic RATE2/3,
labelled1/1.5), key-off must produce observable release attenuation over the
finite approximately9.373s recording, as on the PCB and OPM, rather than the
observed near-full-level late JT51 output. Keep literal programs, adjacent
controls, both history conditions, three repetitions and both latches as the
regression evidence. Do not describe this as infinite hold or an internal fix.

The complete saved review packet is `artifacts/low-release-review-v1/`; its
original report SHA256 is
`b1bc83d06d76107e9dd5d60521cf43f428c01d535623f20721d2bbb13909b845`.
The [archive guide](archive.md) locates the raw windows, programs and journals.
