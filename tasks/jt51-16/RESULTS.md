# JT51 #16 — measured subsystem dispositions

The held-key measurements support 18-bit modular mixing on both outputs,
published in e868314. The existing CPU/serial continuation additionally
supports different LEFT/RIGHT accumulation windows across all 32 operator/channel
routes; the minimal correction [fe6cad3](http://gitea.jotego.es/jotego/jt51/commit/fe6cad32067277418483c0694a781ff9ef78fb8b) is published on local master and private tea/master. Production pitch
arithmetic remains unchanged because the repeatable bench anomaly contradicts
Yamaha's explicit 440Hz example. Its cause and generality remain unresolved.
See [the serial results](plans/serial-results.md) and
[the existing-interface plan](plans/serial-controls.md).

The existing CPU bus, SO/SH1/SH2 connections and prior 3.57–3.58MHz clock
measurement suffice. No new wiring, second chip, clock measurement or reboot
is required. No ROM/FPGA reload or CPU reset occurred. Rastan #15 remains last.

This report supplements the [offline dispositions](plans/offline-dispositions.md).
See the [private-checkout and reproduction guide](plans/reproduce-round2.md).
Original measurements, observation coordinates and sealed archives remain
unchanged. The [archived post-#14 recheck](plans/candidate-recheck-results.md)
retains 11 unchanged PCM cases and 13 original physical duration bands. The new data is in
`/gdrive/jotego/reverse/YM2151/2026-10-18-jt51-16-round2/`.

## Historical round2 acquisition and method

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
off. N5 selects channel0's four operators and channel1 M1; N32 selects all 32.
A continuously routed reference channel is observed on the opposite output.
Each history measures initial TL32, individual TL32 components, TL32 aggregate,
individual TL0 components, TL0 aggregate and the final TL32 return.

Each record contains 16,384 native stereo frames after at least 0.05 physical
seconds of settling. Component samples 128..8319 train an empirical min/max
mapping of raw reference level and strict monotonic branch to raw component
output;8320..12415 are untouched heldouts. Fixed2048PCM bins include adjacent
bins and 64PCM export uncertainty per component. Missing support fails
eligibility; clipped component endpoints are censored. At least 75% coverage and
three points in each reference sign/branch quadrant are required. Sum intervals
are transformed through fixed clip16 and signed wrap17/18/19-then-clip16 maps,
retaining unions across every wrap discontinuity and adding 64PCM aggregate
export uncertainty. No sinusoidal proxy, per-record phase rotation or amplitude
normalization supplies the latent sum.

New-protocol TL32 closure, all component holdouts, initial-low heldout and final
low-return controls pass in all nine histories. N5 and N32 LEFT use three
independent initializations each:90 recordings including six full quiets.
A pure PAN-bit 6/7 mirror supplies three overloaded RIGHT histories:63 recordings
including three full quiets. Separate audits reread all CAP hashes, exponent/
raw-word/PCM bindings, IDs, inversion, monitor generation/reply order, tool and
HPS boot identities. Every quiet is exactly zero on both outputs.

One original host quiet attempt failed because its cleanup input path was
missing, before USB/device access. Its logs remain intact. A separately pinned
resume script used the existing cleanup input and reused the eight valid
recordings; no successful recording was overwritten.

## Frozen physical results

Each aggregate assesses 12,288 samples. The table reports the covered monotonic
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
repetitions pass all four transfer maps, as expected below the 18-bit wrap
boundary, and provide clipping/low-return positive controls. All TL32 closures
pass.

These are finite empirical hulls, not universal phase/Lipschitz or latent-state
bounds. Host gaps between records do not establish an absolute observation
epoch or accepted write phase. Agreement supports the scoped external transfer
behavior under these held ALG7 controls; it does not identify silicon gate
placement or prove all algorithms and transient states.

## Historical round2 candidate and verification

The candidate reduces global `pre_left/pre_right`, their signed extension and
the final limiter's input from 19 to 18bits. Channel saturation, operator values,
EG/PG state, gain and DAC encoding are unchanged. No explanatory RTL comments
were added.

The unchanged frozen observer qualifies the candidate continuous public
histories. All 27 unaffected public capture CSVs are byte-identical to the
19-bit baseline. Only N32/TL0 aggregate LEFT/exact-LEFT changes; that record's
RIGHT/status/timing columns remain identical. Candidate N32 has zero wrap18
violations; clip16/19 and wrap17 still fail the discrimination check.

The permanent public `mixing` regression in `ver/silicon/` reproduces the
literal held-key component protocol with the same raw-bin method and fixed
coverage/quantization gates. Its 93 checks pass on the 18-bit candidate. The
19-bit baseline fails exactly five checks: the wrap18 aggregate expectation
and both-sign rejection of clip16 and wrap19; all positive/eligibility/history
controls pass. The original 246 checks remain included in `all`.

The full pre-mirror suite passed 339/339 checks, including all 246 unchanged
legacy checks and 93 mixing checks. After adding the mirrored public group,
all 93 shared non-mirrored checks and 66 mirrored checks pass. The 19-bit baseline
fails exactly five mirrored checks as well. Final `all` dispatch includes 405
checks; validation used the full339 run plus the separately tested mirrored
supplement and shared-helper recheck, rather than repeating the slow unchanged
legacy tests. Existing PM and standalone JT51 lint pass.

Full-tree lint completed 98 logs with 12 skipped cores and exactly the same
Verilator diagnostic lines as its repaired-dependency baseline. Its exit1
comes from the four pre-existing errors in rastan/taitox/vlfied
(`IKA87AD.sv` blocking/nonblocking assignments) and toki (loop array assignment),
plus warnings in ktiger/wardnr (`IKA32010.sv` initialization assignments).
No diagnostic names JT51; the missing dependencies have been initialized.
Contra `jtcore contra -mrq` completed with exit0: zero errors,398 warnings,
11,640 ALMs and 62 RAM blocks. The historical round2 CRT MiSTer image was
`release/mister/jtcontra.rbf`, SHA256
`17fd24380b16c64b2e6fcd02f79c10fedf849c2b881ca200a5a715ed53b86e40`.
Its executable RTL matches the recorded candidate hash; generated version
metadata predates the final source commit. At the round2 checkpoint, JT51 master and private tea/master
were verified at e868314898b53cf734cef0e5c2c878aaa46f091e.
The requested comment cleanup was already published as 4c8811e; no new RTL
comments were added. At that checkpoint #16 and #15 remained open.

## Historical round2 archive inventory

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
| `contra-e868314-build.tar.gz` |9|`eb98267bb1ea1230b7a210699c1fb6a5a98736641e528077d8b937c0646788f7`|

## Remaining family dispositions

The subsequent [serial report](plans/serial-results.md) supersedes the earlier
pitch/phase instrumentation prerequisites in historical reports:

- Maximum-off noise is corrected in 31c64cf; keyed TL127 remains−9/+8.
- External OPM carrier/pan exceptions remain reference-only limitations.
- Odd-MUL is a repeatable bench/documentation contradiction. All 243 saved cases,
  fresh held-note/stage controls and independent raw-pin decoding qualify, but
  the experimental arithmetic violates Yamaha's exact nominal example. It is
  excluded from production; nominal guard01110fd passes five checks. Cause
  and generality remain unresolved without asserting a chip defect.
- Stereo assembly is constrained by 96 saved captures covering every 32 route×3.
  The 16 delayed slots place LEFT/RIGHT accumulation boundaries at 31/15.
  PG/EG/operator timing and the original noise substitution remain unchanged.
  The first whole-group-boundary candidate and subsequent special-noise
  candidate are rejected by channel7 sine/noise controls. The final candidate
  passes 405 legacy checks, seven phase controls and three native-noise checks;
  the final permanent-map regression passes 183 checks and rejects both
  provisional candidates. Contra compilation passes with positive reported
  timing slacks.

## Existing-interface continuation, 2026-10-19

The new session completes130 captures: ten readiness/pan/quiet controls,
36 held-note pitch records,48 running-reference phase records,24 targeted
pitch-stage records and 12 direct raw-pin sanity captures. Every group passes
separate ROOT CAP/input/hash/raw-PCM/exponent/generation/boot audits. All
whole-record quiets are exactly zero; nonzero positives and frozen observers
qualify. Reusing the saved96-record full stereo map avoided a redundant
proposed99-record campaign.

The same old CAP records simultaneously contain LEFT(M2,C1,C2)≈(+1,0,0)
and RIGHT≈(+1,+1,+1), relative to M1. Output side explains the apparent change
between protocols. The new running-reference controls and full map corroborate
it. Exact accepted-write epochs and dynamic pan/NE topology remain finite
interpretation limits; no arbitrary operator phase/reset correction follows.

Completed Drive case:
`/gdrive/jotego/reverse/YM2151/2026-10-19-jt51-16-serial-controls/`.

| Archive | Verified file members | SHA256 |
|---|---:|---|
| `initial-serial-controls.tar.gz` |1219|`0bce757ce28d9e6765b4f05c82e9696cea3f0a09ce6101719a02ff744315058c`|
| `phase-public-diagnostics.tar.gz` |1583|`1ffad24f1e739a1afeff4655149ee7b0bc6e649eb16c4e1b3dd22e9bdd1e5586`|
| `pitch-stage-controls.tar.gz` |304|`213222a9e3e1569a7f4f2e601f986a4034ad2ebd3aac7b16698baf544d09f8e1`|
| `raw-pitch-crosscheck.tar.gz` |165|`6c4eff654b85f689f16b9749f413c23e687c4f64ca281862454890b1c953ee03`|
| `pitch-anomaly-experiment-and-nominal-v1.tar.gz` |2006|`107ba03eb3227ce1bab322e8924373ce828431efd7d2461d79c9db92de0ac2c9`|
| `stereo-assembly-analysis-v3.tar.gz` |1087|`767acc04e9fee83dd9cac6647b3931584474d15e0d77e215ca92296ad3604d4e`|
| `published-serial-source-validation.tar.gz` |486|`12820961c234d7954206a7e47563ef22bb584b245480ab50fad68292644ef0c9`|

Every member was reread and hash-verified. Completed archives retain their
original provisional interpretations; the final serial report identifies the
superseding dispositions. Original sealed cases are unchanged. No compound
Rastan run has been used to substitute for isolated controls.

The nominal documentary regression 01110fd is merged to local master and
verified on private tea/master and tea/jt51-16. It changes no executable RTL.
The supported stereo RTL is published as fe6cad3 on local master and private
tea/master and tea/jt51-16. Composed 593-check coverage passes:405 unchanged
legacy,160 routes,23 observer and five nominal pitch checks. Full-tree lint
has 98 logs/12skips and exactly the same19 diagnostic lines as baseline, with
no new JT51 diagnostic. Contra compilation succeeds with exit0, zero errors/398 warnings,11534ALMs
and 62RAM blocks. Minimum reported setup/hold slack is3.305/0.250ns. Its final
image is left at `release/mister/jtcontra.rbf`, SHA256
`78c1188278471a52df6cac3b304386293ba2b783de629fe861e56ce928d34382`.
The exact RTL byte pins match fe6cad3 despite older generated version metadata.
[Reproduction and archive guide](plans/reproduce-serial.md).
