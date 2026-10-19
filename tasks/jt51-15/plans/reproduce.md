# Reproduction and admission

Use runner JT51 `dca9207097cd2fed458755c39c424e52c5763ef0`, whose production HDL remains identical to `fe6cad32067277418483c0694a781ff9ef78fb8b`. Extract the verified calibration archive into a fresh directory, preserving its paths; do not edit sealed cases or reuse a mutable monitor state as authorization to run hardware. The archive contains the exact public frontend source/build commands, literal calibration programs, raw CAP/PCM, observers, synthetic checks, readiness snapshots and failed/successful attempts.

## FPGA execution

Run the full comparison corpus on Chameleon96, using the permanent runner in `ver/chameleon96`. Use Verilator for its small directed/controller/parity checks. Source the project root `setprj.sh` before building. `board/build.sh NEW_BUILD_DIRECTORY` creates an independently identified bitstream; require positive post-fit timing and no unconstrained paths before loading. The qualified source signature is `ca3b8b552556ff2e10e7e3a653a2ac41803f16a391b936d8f9301a01ed412b85`, at 50 MHz. Preserve the HPS/USB baseline and use the runtime loader's configfs path method.

The tape compiler converts the literal INIT and each matching EVENT to immutable public bus actions. Each lane uses `idle_clocks=64*d` and `event_shift=(KEY_residue-(512+idle_clocks+first_event_KEY_offset)) mod64`, exactly reconstructing the saved frontend schedule. Upload/read back each tape, execute all 640 matching jobs per EVENT, and retain all 1,920 IDs. No CPU-model fallback, subset admission or LEFT-based selection is allowed. The old stopped CPU directories are historical evidence only.

Results bind source/run/lane/generation, actual logical clocks, status, tape completion and sample mode. Export native mode0 with 16,384 frames and stride1, then use the qualified Go decoder. Pin both binary and decoded output hashes against the actual board files. Boot identity must remain constant. Before admitting a new image, require the 16-job equivalence suite against saved nonzero Verilator output.

The FPGA admission adapter checks the complete immutable manifest, every raw header and RIGHT/clock/status sample, decoder full-output binding, all three successful 640-job batch proofs, and actual RIGHT phase coverage for every rep/KEY coordinate. The initial process-per-file qualification attempt was stopped for runtime overhead and remains unadmitted. The replacement wrapper may memoize the unchanged pure RIGHT calculation only after digest grouping and exact complete-vector equality; every ID still receives full acquisition/source/clock/status checks and its complete reference phase set. It must never cache or select LEFT descriptors. The full target comparison uses a separate explicit ROOT analysis binding after admission. Neither hardware success nor a partially completed observer run admits a residual claim. The 4,096-record replay capacity does not accommodate the full retained-history prefix; that needs a separately validated extension.

## Timing method

The reference is C2/ch0, RIGHT only, KC3A/KF0, MUL8, DT0, KS0, AR31, D1R0, D1L0, D2R8, RR15. Its fixed public envelope-step pattern has period 3072 native samples and offsets 384 × {1,3,5,6,7}. This period covers the configured attack target's rate-pattern periods. It must not be silently reused for the separate release fixture, which requires a 6144-sample alias treatment.

The frozen reference observer is `reference-grid-v1/observe.py`, SHA256 `862f58df3faa4086c82d7344eb6b2a8b23990fce5b26e448e6ba529cda2d18db`; freeze SHA256 `a478bec7ec3c7f8cd2cf38eb63e5b26fe690ebaeb01ed2758501bda0de63f715`. It scans all 3072 phases and retains every eligible candidate, including both marker return-edge possibilities. It rejects insufficient plateau/step support rather than choosing a least-residual phase. Target admission uses RIGHT only.

The public frontend freeze is `frontend-cpu-v1/source-freeze-2.json`, SHA256 `2a5c4207bd09d0fdf4802789cf3154d875c9faf7bf3a6347d0f3970775b04d8b`. `reference-seed-proof-v1` establishes the own-model relation between whole-frame idle and observed reference phase. Candidate seeds are the complete set

`D = {(m - p + delta - epsilon) mod 3072}`,

where m and p retain all model/physical marker-edge phases, delta spans −3…3 and epsilon spans {0,1}. Each distinct d uses `--idle-before-init 64*d` and all 64 `--keyon-phase` residues. Each physical repetition uses its own matching EVENT baseline. Do not substitute the calibration's r517 baseline for the original attack baselines or narrow seeds using LEFT.

## Target observer

The original marked attack method freeze is `artifacts/marked-attack-programs-v1/method-freeze.json`, SHA256 `bf6320d377a8baaf0b81e4f3907bf8e38120b6d560c9255924c34178df72588a`. The target observer is `target-observer-v1/observe.py`, SHA256 `1a21ea896032f15cbd4023c40e7a4ece434bdf324b9120e25af780e8a988d544`; freeze SHA256 `be30c00970e9001bdd35d6e698f02e33804c4874645bffe6a831a7c0460f0937`.

Retain epochs b−4 through b+3 and fixed windows [128,384), [384,640), [640,1152), [1152,2176), [2176,4224). Integer count, extrema, sum, sum of squares and sign/zero populations are descriptive. Only the predeclared sum-of-squares windows may flag a discrepancy: all three physical repetition intervals must lie beyond the same side of every interval in the complete admitted model union. Overlap, gaps or mixed directions remain inconclusive. Exact catalog identity coverage is mandatory. No target-onset alignment, interpolation, amplitude normalization or best-phase selection is allowed.

The reference observer's 82 synthetic checks and eight input guards, and target observer's 24 synthetic checks and eight literal audits, pass. Completed original attack descriptor generation exits zero for all six records. Full model render/RIGHT qualification and final comparison must complete before any residual conclusion. Failed/ineligible candidates must remain visible; they cannot be silently omitted.

A future retained-history comparison must preserve the same EVENT and controlled background. Adding `--idle-before-init` after a retained active history changes the state age and is not an admissible substitute for unknown initial counter phase. Retained-history timing/host-gap uncertainty needs a separate prospective plan before acquisition or modeling.
