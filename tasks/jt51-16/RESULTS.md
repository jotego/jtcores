# JT51 #16 — focused physical follow-up

The additional held-key measurements support an 18-bit signed modular sum
before final 16-bit clipping on both outputs. The [published correction e868314](http://gitea.jotego.es/jotego/jt51/commit/e868314898b53cf734cef0e5c2c878aaa46f091e) changes
only that final accumulator width. Local master and private tea/master both
point to that commit. Odd-MUL pitch and joint-key phase remain
unresolved and require package-level bus/accepted-write observation. Compound
Rastan #15 remains last, blocked by those remaining #16 controls.

This report supplements the [offline dispositions](plans/offline-dispositions.md).
See the [private-checkout and reproduction guide](plans/reproduce-round2.md).
Original measurements, observation coordinates and sealed archives remain
unchanged. The [archived post-#14 recheck](plans/candidate-recheck-results.md)
retains11 unchanged PCM cases and13 original physical duration bands. The new data is in
`/gdrive/jotego/reverse/YM2151/2026-10-18-jt51-16-round2/`.

## Physical acquisition and method

The resident P28 monitor and Chameleon protocol `0x960104` were requalified
without replacing the ROM/FPGA or resetting the PCB. Ten readiness recordings
qualify bipolar output, stereo routing and exact-zero quiets. Twelve initial
same-history targets plus twelve matched quiets passed acquisition checks.
Their high-level cosine/harmonic proxies failed the unchanged eligibility
screen. A frozen short-window raw-bin estimator also lacked adequate component
holdout coverage, including in the unchanged JT51 control. Those failures are
retained; no gain, phase or quantization tolerance was fitted to accept them.

The prospective replacement records each component at the native rate while
keeping all selected operators keyed throughout one history. Full INIT occurs
once. Later exposures write only PAN/TL; EVENT is STATUS/END `03/00`. The stimulus
is ALG7/FB0, KC4A/KF0, MUL0, zero detune, AR31, D1/D2=0, RR15, with noise/LFO/CSM
off. N5 selects channel0's four operators and channel1 M1; N32 selects all32.
A continuously routed reference channel is observed on the opposite output.
Each history measures initial TL32, individual TL32 components, TL32 aggregate,
individual TL0 components, TL0 aggregate and the final TL32 return.

Each record contains16,384 native stereo frames after at least0.05 physical
seconds of settling. Component samples128..8319 train an empirical min/max
mapping of raw reference level and strict monotonic branch to raw component
output;8320..12415 are untouched heldouts. Fixed2048PCM bins include adjacent
bins and64PCM export uncertainty per component. Missing support fails
eligibility; clipped component endpoints are censored. At least75% coverage and
three points in each reference sign/branch quadrant are required. Sum intervals
are transformed through fixed clip16 and signed wrap17/18/19-then-clip16 maps,
retaining unions across every wrap discontinuity and adding64PCM aggregate
export uncertainty. No sinusoidal proxy, per-record phase rotation or amplitude
normalization supplies the latent sum.

New-protocol TL32 closure, all component holdouts, initial-low heldout and final
low-return controls pass in all nine histories. N5 and N32 LEFT use three
independent initializations each:90 recordings including six full quiets.
A pure PAN-bit6/7 mirror supplies three overloaded RIGHT histories:63 recordings
including three full quiets. Separate audits reread all CAP hashes, exponent/
raw-word/PCM bindings, IDs, inversion, monitor generation/reply order, tool and
HPS boot identities. Every quiet is exactly zero on both outputs.

One original host quiet attempt failed because its cleanup input path was
missing, before USB/device access. Its logs remain intact. A separately pinned
resume script used the existing cleanup input and reused the eight valid
recordings; no successful recording was overwritten.

## Frozen physical results

Each aggregate assesses12,288 samples. The table reports the covered monotonic
subset; all other points are explicitly ambiguous turn/plateau samples, with
zero missing support. All component endpoint/heldout and history gates pass.

| Target | Rep | Covered | Ambiguous | clip16 / wrap19 violations | wrap17 violations | wrap18 violations |
|---|---:|---:|---:|---:|---:|---:|
| LEFT N32/TL0 |0|11760|528|7556|2524|0|
| LEFT N32/TL0 |1|11758|530|7558|2496|0|
| LEFT N32/TL0 |2|11759|529|7586|2525|0|
| RIGHT N32/TL0 |0|11765|523|7569|3166|0|
| RIGHT N32/TL0 |1|11758|530|7587|2614|0|
| RIGHT N32/TL0 |2|11766|522|7565|3179|0|

Every rejected alternative fails on both observed output signs. N5's three
repetitions pass all four transfer maps, as expected below the18-bit wrap
boundary, and provide clipping/low-return positive controls. All TL32 closures
pass.

These are finite empirical hulls, not universal phase/Lipschitz or latent-state
bounds. Host gaps between records do not establish an absolute observation
epoch or accepted write phase. Agreement supports the scoped external transfer
behavior under these held ALG7 controls; it does not identify silicon gate
placement or prove all algorithms and transient states.

## Candidate and verification

The candidate reduces global `pre_left/pre_right`, their signed extension and
the final limiter's input from19 to18bits. Channel saturation, operator values,
EG/PG state, gain and DAC encoding are unchanged. No explanatory RTL comments
were added.

The unchanged frozen observer qualifies the candidate continuous public
histories. All27 unaffected public capture CSVs are byte-identical to the
19-bit baseline. Only N32/TL0 aggregate LEFT/exact-LEFT changes; that record's
RIGHT/status/timing columns remain identical. Candidate N32 has zero wrap18
violations; clip16/19 and wrap17 still fail the discrimination check.

The permanent public `mixing` regression in `ver/silicon/` reproduces the
literal held-key component protocol with the same raw-bin method and fixed
coverage/quantization gates. Its93 checks pass on the18-bit candidate. The
19-bit baseline fails exactly five checks: the wrap18 aggregate expectation
and both-sign rejection of clip16 and wrap19; all positive/eligibility/history
controls pass. The original246 checks remain included in `all`.

The full pre-mirror suite passed339/339 checks, including all246 unchanged
legacy checks and93 mixing checks. After adding the mirrored public group,
all93 shared non-mirrored checks and66 mirrored checks pass. The19-bit baseline
fails exactly five mirrored checks as well. Final `all` dispatch includes405
checks; validation used the full339 run plus the separately tested mirrored
supplement and shared-helper recheck, rather than repeating the slow unchanged
legacy tests. Existing PM and standalone JT51 lint pass.

Full-tree lint completed98 logs with12 skipped cores and exactly the same
Verilator diagnostic lines as its repaired-dependency baseline. Its exit1
comes from the four pre-existing errors in rastan/taitox/vlfied
(`IKA87AD.sv` blocking/nonblocking assignments) and toki (loop array assignment),
plus warnings in ktiger/wardnr (`IKA32010.sv` initialization assignments).
No diagnostic names JT51; the missing dependencies have been initialized.
Contra FPGA compilation is still running. JT51 master and private tea/master
are verified at e868314898b53cf734cef0e5c2c878aaa46f091e.
The requested comment cleanup was already published as4c8811e; no new RTL
comments were added. #16 and #15 remain open.

## Archive inventory

All members were reread after compression and verified against source hashes.
Each archive has an adjacent `.verification.json` listing member paths and
SHA256 values. Analysis source, method freezes, literal programs and failed
methods are retained alongside the measurements.

| Archive | Members | SHA256 |
|---|---:|---|
| `pilot-captures.tar.gz` |410|`b78b948216e42d1ef23f23f9b02ae9c199bba3cfb1792ec9edfad4f0d987abdc`|
| `native-chain-captures.tar.gz` |1040|`82b8bcbe63dad3d0526b98b311eb19dc03c17ea5997f0180b1966d37d358f95f`|
| `left-confirmation-analysis.tar.gz` |108|`844e153b3d3f47c7d8ff3a9f99083899f2c4cc2022a8658c76d69857b1e4657e`|
| `right-confirmation.tar.gz` |737|`b83e8ea5a55d73e66f8613f66a931ab26f624e6f7a51fdd3dcddd07d18318440`|
| `jt51-e868314-source.tar.gz` |38|`a56b4411098b36912de3b1ee4d7c24ace8e390b4774f7f2870c7b99b794b3720`|
| `published-correction-validation.tar.gz` |240|`b0a884ae6f93dae0b2eb697d722827ca43186888fa01431a10fee5d8d7e6aba1`|

## Remaining families

- Maximum-off noise was already corrected in31c64cf; keyed TL127 remains−9/+8.
- External OPM carrier/pan exceptions remain reference-only limitations.
- Odd-MUL pitch still needs accepted package-level address/data/write
  verification and a second-chip comparison. The physical clock is consistent
  with32.22MHz/9; a clock scaling correction is unsupported.
- Joint-key relative phase still needs a package-level accepted-write phase
  scan. Output timing alone does not establish an operator-reset correction.

The present three serial inputs cannot observe the required parallel bus.
Logic-analyzer availability was requested. No pitch or phase patch is inferred,
and Rastan has not been used to substitute for these isolated controls.
