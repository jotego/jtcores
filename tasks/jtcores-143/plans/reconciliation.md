# YM2151 measurement reconciliation

The available finite measurements requested in jtcores#143 and jt51#4–13
are recorded on the qualified Diet Go Go/direct-serial bench. The original
98,880-write Rastan trace is unavailable: the user answered “Not anymore”
to the location question. Exact preceding-history replay remains
**unmeasured / input-missing** in jt51#7/#8/#13. Parent jt51#3 therefore
remains open, and implementation jt51#14 remains blocked by #13.
Distilled fresh or one-prior-note programs are separate experiments.

Production JT51 stays `985a573dcfc1ff135553a39f7eae21d18ba57cbe`.
No RTL fix or architectural change was made. Frozen external OPM evidence
stays separate from silicon evidence; agreement between models is not a vote
on chip behavior.

## Completed supplement

| Family | Physical targets | Captures including independent quiets | Usable model recordings |
|---|---:|---:|---:|
| TL/KF/KC and live pitch ordering |500|1004|908 audio |
| Live-register and combined histories |279|559|186 audio, eight separate timer runs |
| Ordered operator key histories |18|37|12 audio |
| Previously absent LFO codes and geometry controls |270|545|492 audio |
| Total |1067|2145|1598 audio, eight timer runs |

The 2,145 physical captures contain 1,067 targets and 1,078 entire-zero quiets.
Every capture has an independent raw decode/transport/conditioning review.
Sixteen additional monitor STATUS/positive-control/cleanup commands are
separate observations, not audio captures. The final entire quiet completes
at generation172/markers3114. No new reset, FPGA reload or physical retake
was needed during these supplemental acquisitions.

The [pitch/level report](pitch-supplement.md) retains deep-TL quantization,
reserved-KC poor fits and the original odd-MUL discrepancy without assigning
a new gap. The [history report](history-measurements.md) retains all330 physical
helper calls/660 model links, intentional quiet/failed phase fits, fast CSM
limits and timing uncertainty. The [all-code LFO report](lfo-all-codes.md)
retains 540 physical and984 model results in a 1,524-row joined export.
Slow partial observations never become extrapolated full periods; the old14
code observations remain separate from the242 new codes.

The initial LFO model timeout and cancelled peer remain archived. Seventeen
successful originals were reused unchanged; a reviewed475-run continuation
changed only the operational120→600 second wall guard. All native clocks,
stimuli and numerical guards were retained. The joined492-model/984-output
integrity audit passed, followed by the separate saved1,524-row export audit.
Original unresolved states and52 conditional new fast OPM RIGHT results remain
visible. The original500-target join's missing-Matplotlib failure and successful
render-only recovery likewise remain separate; its tables were not regenerated.

## Original issue requirements

All43 original checkboxes are accounted for without rewriting their requests:
five old-platform setup items are explicitly superseded, six setup items are
qualified on the replacement bench,28 scientific items have bounded recorded
evidence, three exact-history items lack their original input, and one final
campaign/implementation condition remains blocked by that missing input.
Old X-Men/Z80/K054539 instructions remain historical context.

| Issue | Measurement disposition |
|---|---|
| jt51#4/#5 | Replacement bench, decoding, conditioning and reference scope complete |
| jt51#6 | Finite pitch/level and ordering scope complete |
| jt51#7 | Three scope items complete; exact Rastan prefix remains unchecked |
| jt51#8 | Three scope items complete; exact disputed startup/history replay remains unchecked |
| jt51#9 | Wave/depth/sensitivity/routes/history plus every rate-code observation recorded, with explicit limits |
| jt51#10 | Finite noise-code/routing/history scope complete |
| jt51#11 | Finite timer-status/CSM scope complete; physical IRQ and subclock cause remain unobserved |
| jt51#12 | Finite stereo/mixing/pan scope complete; latent phase and overload mechanism remain unclassified |
| jt51#13 | Bounded interaction/repetition/inventory work recorded; original music prefix and campaign-completion condition remain unchecked |
| jt51#3/#14 | Parent measurement campaign open; combined implementation reserved and blocked by #13 |

Completed independent rounds do not depend on replaying the unavailable trace.
Only stale execution-order dependencies are removed when closing those rounds;
the essential #7/#8/#13 blockers and #14→#13 dependency remain.

The [gap inventory](gaps.md) retains six supported production requirements:
timer status flag creation/sticky clear, noninstant effectiveAR30/31,
raw-zero-rate inhibition after key scaling, D1L15 zero PCM tails, scoped
rate12 D1/D2 attenuation granularity, and automatic CSM public output.
The supplement adds no confirmed requirement and clears none of those six.
Odd-MUL pitch, relative operator phase, static/held mixing, the small NE floor,
poor reserved-KC fits, LFO feature failures and reference exceptions keep their
separate classifications. Full Cartesian coverage and unobservable internal
timing are not passing defaults.

## Archive and reproducibility

The permanent entry point is `/gdrive/jotego/reverse/YM2151/README.md`.
The campaign directory is `2026-10-18-diet-go-go-jtcores-143/`.
Its original `measurements.tar.zst`, original inventory and original browse
tree remain immutable. The entire reconciliation task is preserved separately
in `supplement-measurements.tar.zst`, with its inventory and verification
outside the archived tree. [The archive guide](archive.md) records extraction,
hashes, source identities and path mapping. New report/figure copies are under
`supplement-browse/`; final issue readbacks and commit proofs stay outside the
sealed task archive.

Integrity checks establish preservation and reproducibility. Each scientific
result retains its original applicability, carrier qualification, observation
window, unresolved state and uncertainty.
