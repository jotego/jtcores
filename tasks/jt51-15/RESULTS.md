# Rastan integration investigation

Issue [jt51#15](http://gitea.jotego.es/jotego/jt51/issues/15) remains open. Its isolated prerequisites #14 and #16 are closed. Production HDL remains identical to JT51 `fe6cad32067277418483c0694a781ff9ef78fb8b`. The new FPGA regression runner is `dca9207097cd2fed458755c39c424e52c5763ef0`, merged into local master and private `tea/master`; the completed isolated source/build checkpoint is parent `303a07afa7619600f71f1bfa3eb86d6b48449818`.

## Selected case and input identity

The first target is the original distilled channel 6 AR12/ALG0/FB5 attack. Its 28 operator/note parameters are preserved. The diagnostic projects it onto LEFT and supplies an independent C2/channel 0 envelope reference and PAN marker on RIGHT. The three EVENTs retain distinct initial delays 8192, 8199 and 8211. Each has a separately initialized whole-record quiet control. These are marked diagnostic inputs, not byte-identical original EVENTs.

This original fixture is distinct from the authorized replacement MAME history. The replacement contains 209,206 register writes and 418 all-operator key-ons; its selected natural EVENT has 1,200 writes and four key-ons. The lost original 98,880-write trace remains lost. The original release fixture is separately labelled ALG1/FB7. Neither selected note invokes the unresolved post-DT1 bit13 odd-MUL condition; production pitch remains unchanged.

## Completed timing qualification

Twelve reference calibration recordings pass independent raw CAP/input/PCM/hash/generation/boot audits and the prospectively frozen observer: three C2/ch6 positives, three marker-only controls, and six whole-record stereo quiets. All six active RIGHT references admit one raw grid phase; the paired C2 LEFT grids lag RIGHT by one native sample within the declared ±3 allowance. All six quiets are zero. Physical marker widths are 30 or 31 samples, consistent with the CPU-timed public model prediction of 30.5833 samples. These finite public-output correlations do not expose internal counters or accepted KEY clocks.

The public CPU timing adapter uses exact monitor instruction-cycle costs, integer 4/3 CPU/YM timing with retained fractional carry, page costs, and planned clear-busy polls. Its 2,447 scheduler checks and seven saved CPU timing cases pass. Legacy default and 37.5 timing paths retain byte-identical public outputs. Canonical model WR pulses do not establish electrical PCB setup/hold timing.

Three independently initialized marked AR12 targets and their three paired quiets have now been recorded. All six pass raw/input audits; all three RIGHT references qualify. The target records are bipolar and nonzero; the quiet records are zero. No reset, ROM/FPGA reload, additional wiring or repeated clock measurement was needed for these physical acquisitions. The measured 3.57–3.58 MHz clock and existing inverted SO/SH1/SH2 interface are sufficient.

## Comparison in progress

Three matching public-model baselines pass their full RIGHT-only probe. Before LEFT descriptor analysis, the complete phase catalog was frozen: three matching EVENTs × ten reference-derived idle seeds × 64 KEY residues = 1,920 candidates. Catalog SHA256: `493a5e967fe5cba311cb813d0dbd207274f50c84823d3acb17f2f40224bdc301`.

All eight declared marker epochs and five fixed windows remain admitted. Target onset, gain and phase are never fitted. The frozen observer accepts all three target descriptors and all three quiet descriptors. All 1,920 candidates have now executed on the FPGA; full RIGHT qualification and comparison are in progress; no model discrepancy, Rastan fix or new RTL change is claimed by this checkpoint. Retained-history and physical one-change controls remain outstanding.

## FPGA regression execution

The user requested FPGA execution for the complete regression and Verilator for small simulations. The earlier CPU sweep was stopped with 1,145 committed raw runs and 1,143 committed RIGHT probes. All 1,920 planned identities remain preserved; its incomplete catalogs are not admitted. No further CPU model sweep or continuation was launched.

The permanent runner under `modules/jt51/ver/chameleon96` uses four independent JT51 instances, each with 4,096 replay records and 16,384 stereo capture samples. The whole controller and all instances run from a real, globally routed 50 MHz divided clock. All-corner timing passes: worst setup +0.846 ns, hold +0.116 ns, all TNS zero, no unconstrained paths. Resource use is 8,191 ALMs, 444 M10Ks and four DSPs. Production HDL is unchanged. The earlier 100 MHz build failed timing and was never programmed; no 100 MHz optimization was pursued.

Small Verilator checks pass: 133 lane checks, 1,036 controller checks, the clock/reset wrapper check, and 40,960 exact real-DUT parity rows. Tape compilation reconstructs all 1,145 saved CPU journals and the saved baseline/reference journals exactly. After runtime loading, the board reports four lanes, 50 MHz and the complete expected source signature `ca3b8b552556ff2e10e7e3a653a2ac41803f16a391b936d8f9301a01ed412b85`. Sixteen physical FPGA qualification jobs match 229,392 saved PCM/status/clock rows exactly, including independent lanes, boundary seeds/KEY residues, full-resolution output and decimation. Captures are nonzero. Boot identity remains unchanged.

All three 640-job cohorts completed on the FPGA, preserving every original candidate ID. Every raw binary was downloaded, hash-checked against the board and decoded successfully: 31,457,280 stereo frames. On-board elapsed time including tape uploads was **211.2573 seconds**: execution/polling 24.715548 seconds, export 186.339034 seconds. Host download, decoding and subsequent reference/target analysis are outside these timings.

The first four-copy qualification batch took 0.481329 seconds including upload, versus 2.184685 seconds for each saved matching Verilator run: about 18 times faster than four sequential runs. The first 640-case FPGA cohort took 69.9955 seconds including upload. Its matching saved CPU cases total 2,949.1886 job-wall seconds; dividing by the earlier three-worker concurrency estimates 983.0629 seconds, about 14 times the FPGA cohort. This is a throughput estimate from existing concurrent runs, not a new controlled CPU benchmark. FPGA compilation is a one-time cost: the successful 50 MHz build took 10 minutes 59 seconds. The full reference/target analysis remains a separate host operation and is not included in these speedups.

The closed execution manifest is `fpga-corpus-v1/corpus-manifest.json`, SHA256 `df62b5e620b80fd197c9633001520cd8b3889342df7aec6ca943c9fb2cf99291`. The full raw audit passes all actual headers, source/clock, tape/job identities, boot, generations, decoder output and all original IDs. The first host RIGHT-qualification attempt was stopped for runtime overhead before complete admission; its partial outputs remain explicitly incomplete. Exact byte inventory finds 90 distinct RIGHT vectors across all 1,920 cases. The replacement execution adapter memoizes only the pure reference calculation for byte-identical inputs, with complete-vector collision guards and independent per-ID acquisition/source bindings; it retains every ID and phase candidate. Complete actual RIGHT coverage must still pass before target comparison. Hardware execution success alone is not a Rastan result.

## Archive

New OPEN case: `/gdrive/jotego/reverse/YM2151/2026-10-19-jt51-15-rastan-integration/`.

Completed calibration archive: `reference-calibration.tar.gz`, SHA256 `46ae2e273b07ec7c69baf438175c4a0af9d75a270d0ecef595f437176009f6d3`. All 408 data members plus its embedded manifest were reread; all source members were rechecked. Adjacent manifest and verification JSON record the result. Initial failed attempts are retained. This individual archive is immutable; the enclosing investigation remains open. Earlier sealed cases remain unchanged.

Task work: `/nobackup/tasks/jt51-15/round1-20261019-integration/`. See [reproduction and admission](plans/reproduce.md).

Stopped CPU evidence archive: `stopped-cpu-sweep.tar.gz`, SHA256 `9cd1ae8200ee7d53bf1bc9f445743654bdcba73ca2fad2255bf275107fd096d3`. All 8,121 members plus the embedded manifest were reread and sources rechecked. It is explicitly incomplete and not admitted.

Verified FPGA execution archive: `fpga-regression.tar.gz`, SHA256 `7d7ed09c31a94f402bddf21ee814f9ebebd7126ae8e03189610e6bce3f1a140f`. All 6,041 data members plus the embedded manifest were reread from both local and Drive copies, and all source members were rechecked. It includes all 1,920 raw binaries, CSVs and decoder proofs, exact source/tool/build closure and hardware qualification goldens. It excludes ongoing admission/comparison work.
