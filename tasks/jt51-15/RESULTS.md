# Rastan integration investigation

Issue [jt51#15](http://gitea.jotego.es/jotego/jt51/issues/15) remains open. Its isolated prerequisites #14 and #16 are closed. Production baseline is JT51 `fe6cad32067277418483c0694a781ff9ef78fb8b`, on local master and private `tea/master`; the completed source/build checkpoint is parent `303a07afa7619600f71f1bfa3eb86d6b48449818`.

## Selected case and input identity

The first target is the original distilled channel 6 AR12/ALG0/FB5 attack. Its 28 operator/note parameters are preserved. The diagnostic projects it onto LEFT and supplies an independent C2/channel 0 envelope reference and PAN marker on RIGHT. The three EVENTs retain distinct initial delays 8192, 8199 and 8211. Each has a separately initialized whole-record quiet control. These are marked diagnostic inputs, not byte-identical original EVENTs.

This original fixture is distinct from the authorized replacement MAME history. The replacement contains 209,206 register writes and 418 all-operator key-ons; its selected natural EVENT has 1,200 writes and four key-ons. The lost original 98,880-write trace remains lost. The original release fixture is separately labelled ALG1/FB7. Neither selected note invokes the unresolved post-DT1 bit13 odd-MUL condition; production pitch remains unchanged.

## Completed timing qualification

Twelve reference calibration recordings pass independent raw CAP/input/PCM/hash/generation/boot audits and the prospectively frozen observer: three C2/ch6 positives, three marker-only controls, and six whole-record stereo quiets. All six active RIGHT references admit one raw grid phase; the paired C2 LEFT grids lag RIGHT by one native sample within the declared ±3 allowance. All six quiets are zero. Physical marker widths are 30 or 31 samples, consistent with the CPU-timed public model prediction of 30.5833 samples. These finite public-output correlations do not expose internal counters or accepted KEY clocks.

The public CPU timing adapter uses exact monitor instruction-cycle costs, integer 4/3 CPU/YM timing with retained fractional carry, page costs, and planned clear-busy polls. Its 2,447 scheduler checks and seven saved CPU timing cases pass. Legacy default and 37.5 timing paths retain byte-identical public outputs. Canonical model WR pulses do not establish electrical PCB setup/hold timing.

Three independently initialized marked AR12 targets and their three paired quiets have now been recorded. All six pass raw/input audits; all three RIGHT references qualify. The target records are bipolar and nonzero; the quiet records are zero. No reset, ROM/FPGA reload, additional wiring or repeated clock measurement was needed. The measured 3.57–3.58 MHz clock and existing inverted SO/SH1/SH2 interface are sufficient.

## Comparison in progress

Three matching public-model baselines pass their full RIGHT-only probe. Before LEFT descriptor analysis, the complete phase catalog was frozen: three matching EVENTs × ten reference-derived idle seeds × 64 KEY residues = 1,920 candidates. Catalog SHA256: `493a5e967fe5cba311cb813d0dbd207274f50c84823d3acb17f2f40224bdc301`.

All eight declared marker epochs and five fixed windows remain admitted. Target onset, gain and phase are never fitted. The frozen observer accepts all three target descriptors and all three quiet descriptors. Full candidate rendering and RIGHT qualification are in progress; no model discrepancy, Rastan fix or new RTL change is claimed by this checkpoint. Retained-history and physical one-change controls remain outstanding.

## Archive

New OPEN case: `/gdrive/jotego/reverse/YM2151/2026-10-19-jt51-15-rastan-integration/`.

Completed calibration archive: `reference-calibration.tar.gz`, SHA256 `46ae2e273b07ec7c69baf438175c4a0af9d75a270d0ecef595f437176009f6d3`. All 408 data members plus its embedded manifest were reread; all source members were rechecked. Adjacent manifest and verification JSON record the result. Initial failed attempts are retained. This individual archive is immutable; the enclosing investigation remains open. Earlier sealed cases remain unchanged.

Task work: `/nobackup/tasks/jt51-15/round1-20261019-integration/`. See [reproduction and admission](plans/reproduce.md).
