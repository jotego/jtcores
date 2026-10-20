# jt51 #16: offline dispositions and the next measurement round

PCB is powered off. No acquisition, board access, reference-algorithm inspection,
RTL edit or original archive mutation was performed. This report uses the sealed
`tasks/jtcores-143` measurements and production JT51 source. It does not inherit
the old experimental RTL as truth. The literal input and report pins are in
`artifacts/offline-audit-v1/evidence-pins.json`.

## Dispositions

| Family | Current disposition | Action available without PCB |
| --- | --- | --- |
| NE-on maximum-off envelope floor | A scoped production public-output correction is supported by existing physical triplicates and independent raw pins. | Gate the fully off noise contribution to zero, then rerun never-keyed, delayed KEYOFF, finite attack, TL127 and nonzero noise positives against frozen data. Preserve the original 4-PCM screen: this is additional exact-zero behavior, not a retrospective failed coarse screen. |
| Opposite-pan disturbance in external OPM output | Reference-only limitation at the measured scale, not an identified JT51 defect. | Preserve OPM conditional feature states; exclude it as an exact pan-independent oracle in these cases. JT51 matched/control outputs were already byte-identical. No additional JT51 change or PCB run is justified by this observation. |
| External OPM RIGHT carrier fit failures | Reference-only conditional observations; external-model/internal/export cause unresolved. | Retain original failing carrier flags and conditional fast-LFO RIGHT rows; do not promote derived comparisons to conformance. No JT51 correction follows. A serial-output-vs-public-cache adapter diagnostic could distinguish export timing offline, but requires a separately reviewed interface extension; no third-party arithmetic is needed. |
| Odd-MUL pitch | Strong physical/model output difference, cause unresolved. | The 243-row saved ledger independently reproduces 114 deltas of -8192 and 129 zero deltas. It disproves a blanket mask-after-multiply repair. No production arithmetic change is supported before bus/control isolation. |
| Joint-key relative operator phase | Physical/model output phase families differ; accepted-write timing unresolved. | Existing 36 physical controls and 192 public-grid records exclude the particular tested public presentation residues as an explanation, but do not establish physical acceptance or internal reset phase. No per-operator phase patch. |
| High-level static/held-key mixing | Physical/model output difference with mechanism unresolved. | Preserved common-held-key controls exclude needing a fresh KEYON for the difference; no-op and second-low TL controls qualify low-return stability. They do not establish all per-contributor gains/latent sums at high level. No clip/wrap/width/gain patch. |

The floor is the only additional JT51 behavior here that can now be corrected
without requesting another measurement. It needs a minimal public-output
regression, not only a unit assertion on an internal tap. Root owns all RTL work.

## Exact floor evidence and source-local explanation

The new saved-output audit reads 36 physical CSV streams, ten warm/cold public
model records and the complete 243-row pitch ledger. All assertions passed.
Never-keyed physical targets are zero throughout, KEYOFF final4096 samples are
zero, all paired cleanup streams are zero, and TL127 targets contain both -9/+8.
Frozen public JT51 has -1/0 after warm history and after four additional seconds.
Original independent mode1 raw-pin decoding confirms actual zero words3004 and
resolves the low-bit TL127 positive; this report does not claim a new raw decode.

The own-source expression in `jt51_noise.v` is
`{mix_sgn, eg[9:2] ^ {8{out}}, {3{mix_sgn}}}` with `mix_sgn=~out`.
Direct two's-complement evaluation gives -1/0 for eg1020..1023 and -9/+8 for
eg1016..1019. Thus there is a source-local negative-one path at maximum envelope
attenuation, consistent with the public output difference. This arithmetic is
not a measurement of silicon's internal envelope values. Gate **maximum off**
only; there is no evidence to clamp the whole 1020..1023 quantization bucket,
change ordinary noise gain, alter the LFSR, or discard the low-level positive.

## Minimal future acquisition, after offline fixes

All items need three independently initialized repetitions, their matched
nonzero positive and full-record quiet controls. Start from a fresh reviewed
resident-monitor/capture state; record actual monitor generation/complement,
reply-marker counts, INIT/EVENT hashes, master clock and protocol/image identity.
Historical end generations are not current readiness evidence. Preserve raw
SO/SH1/SH2 with inversion mask15; latch0 LEFT/bit6 and latch1 RIGHT/bit7. Require
valid framing/exponents/hash/counts and nonblank carrier positives. The previous
28-pin PicoROM/9223 EAEG chip and 3.57–3.58MHz measurement identify the old bench,
not a promise about the next power-up. Do not re-run the entire campaign.

### 1. Odd MUL: accepted bus image and a second chip

Reuse complete `generated-pg-v2/mul-kc4a-{00,01,02,03,04}.bin` programs and
`mul-kc50-{00,01,02,03}.bin`, with unaffected KC40/MUL1 as control. They isolate
ALG7, channel0 C2, TL0/AR31, D1R=D2R0, detunes/LFO/noise/feedback off. Changed
registers are KC28=4A or50 and C2 DT1/MUL58=00..04; key08=40. Preserve all other
full-image bytes, not merely these highlighted writes. Capture native16384
frames and both latches, plus full quiet. Record accepted /CS,/WR,A0,D0..D7 at
the YM package alongside master clock, SO and SH strobes, proving actual58/28
values and write spacing; a host completion reply proves neither. Replay the
small same set on a second known-good YM2151 if the pin bus is correct. This is
the smallest control separating bus/setup interpretation from single-chip
behavior before considering a shared architectural multiplier correction.

### 2. Joint-key phase: package-level acceptance epoch

Reuse `algorithms-feedback/phase-programs-v2/phase-forward-{init,event}.bin`,
the reverse and leak companions, and both original preheats8192/16384. ALG7,
native increment4124/MUL0, joint KEYON08=78, TL-isolate M1/M2/C1/C2 while keeping
all keyed. Capture the actual package KEYON address/data-strobe interval and
master clock together with serial latches. Exercise genuinely shifted accepted
key edges over the64-master-clock native frame, retaining real strobe width,
busy/status constraints and accepted phase in the record. Minimum initial
diagnostic phases should straddle each16-clock operator boundary; expand only
if the result depends on them. The previous public-model presentation sweep
was not a physical accepted-phase sweep. Retain RIGHT as the continuous phase
timeline; exclude marker windows and128-sample guards. No independent origin
fit per operator. If the +1 family persists independently of accepted phase,
it supports a scoped output requirement; it still does not identify reset RTL.

### 3. High-level mixing: same-history contributor exposure

Reuse held-n32-tl32-00-32 plus N1 equivalents and TL32 no-op/TL40 controls in
`mixing-output/common-held-history/v2/programs-a`. The exact307-byte EVENT
changes no key/frequency/EG state: delay4096, mute LEFT via each channel pan,
delay1024, all32TL writes, delay1024, restore both pans, delay4096, return32.
Its existing raw conditional coordinates must remain unchanged.

Smallest new discrimination: in ONE keyed history expose each channel/group at
TL0, with the other contributors muted by pan rather than KEYOFF, then expose
the total, returning to the same low TL32 control between exposures. Keep each
group's pan and TL changes bracketed on the continuous serial timeline, measure
both outputs, and verify return phase/level before accepting a predicted sum.
Acquire all channel components needed to form the SAME-history sum; separate
independent static captures cannot substitute. Start with N5/TL0 (first overload)
and N32/TL0 (large-jump case), not a new63-case scan. Qualify predicted aggregate
closure at a non-overloaded level first. If the minimal component protocol
itself perturbs the continuous timeline, retain it unresolved rather than
fitting a phase/gain correction. Only then compare clipping, finite accumulator
or scheduling hypotheses; output saturation endpoints alone identify none.

### 4. Reference-only observations

No PCB session is needed to justify a production JT51 change here, because none
is indicated. The physical pan triplicates already exclude an OPM-size
disturbance under the original fixed diagnostics, not arbitrary tiny coupling
or exact sample identity. A later reference-maintenance effort can sample its
public SO/SH outputs and independently decode them, comparing like-age latched
values against the API DAC cache. This is an external adapter/output question;
do not mask samples, retune fits, or copy its internal algorithm into JT51.

## Scope order

Finish supported #14 corrections and the maximum-off noise fix first. Recheck
affected isolated data against that new baseline with the original eligibility
guards. Retain the three physical-control requests above in #16. Rastan #15
remains last: its1200-write/4-keyon/background window and isolated one-keyon
window have different EVENT contents and capture epochs, and cannot establish
another causal routing correction by an RMS difference.
