# Reproduction and admission

Use production JT51 `fe6cad32067277418483c0694a781ff9ef78fb8b`. Extract the verified calibration archive into a fresh directory, preserving its paths; do not edit sealed cases or reuse a mutable monitor state as authorization to run hardware. The archive contains the exact public frontend source/build commands, literal calibration programs, raw CAP/PCM, observers, synthetic checks, readiness snapshots and failed/successful attempts.

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
