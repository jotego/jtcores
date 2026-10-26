# Isolated YM2151 discrepancy corrections

The corrections are published in [JT51 31c64cf19c8cdc669aa7f4b6b7d8a196f50cae3d](http://gitea.jotego.es/jotego/jt51/commit/31c64cf19c8cdc669aa7f4b6b7d8a196f50cae3d). The baseline is JT51 985a573dcfc1ff135553a39f7eae21d18ba57cbe; the PCB remains off. [Design and limits](plans/implementation.md) describe the coordinated seven-requirement correction and the separate maximum-off noise requirement established during #16.

Original measurements remain sealed in `/gdrive/jotego/reverse/YM2151/2026-10-18-diet-go-go-jtcores-143/` and `/gdrive/jotego/reverse/YM2151/2026-10-18-rastan-history-jt51-13/`. New analysis and regression artifacts belong to the separate isolated-corrections case; old measurements and qualification bounds are unchanged.

The executable regression sources are `modules/jt51/ver/silicon`. Tests use public writes/status and quantized outputs, with nonzero positives and exact-zero controls. Existing PM regression is run unchanged; its PASS is bounded by its existing test stimulus, not a new exhaustive PM conformance claim. No matching simunit marker currently exists.

Rastan is last, following the isolated corrections and [subsystem dispositions](../jt51-16/plans/offline-dispositions.md). The replacement trace remains distinct from the lost original trace. Resolving these isolated defects does not establish Rastan sound conformance.

## Validation

The final public suite passes246/246 checks. The unchanged baseline fails120/246; baseline failures reproduce the intended gaps. Candidate tests retain all original guards, low-bit positives, null controls and bounded timing claims. The final HDL is independently reviewed against Yamaha documentation and the physical requirements.

The independent archived recheck completed39 stereo replays (36 matching archived geometry, three explicitly partial), 11 exact unchanged-PCM comparisons, 13 envelope durations inside their original physical bands, and eight selfcontained physical timer-status comparisons. RR15 remains resolution limited. [Detailed results and retained applicability errors](../jt51-16/plans/candidate-recheck-results.md) distinguish unsupported comparisons from results.

The existing PM script reports PASS. `simunit-all.sh --only jt51` completes with no matching markers. Shared lint completed25 cores and skipped12, with61 blocked:59 missing dependency manifests/RTL inputs plus two missing `rest.bin` inputs. Eighteen actual JT51 consumers completed lint without Verilator errors/warnings: blkout, contra, cps1, dd, dd2, fround, grad3, mx5k, outrun, riders, s16, s16b, sf, shouse, tmnt, twin16, vigil, wwfss. Eleven other consumers remain blocked by missing inputs and narc is skipped. Existing protected user changes were preserved.

Installed Verilator5.018 rejects JTFRAME's `--quiet-stats`; the first whole-tree run is retained as failed. A task-local wrapper removes only that presentation flag and invokes the same executable. No RTL check or warning class is disabled. The compatible run's61 input blockers prevent claiming whole-tree clean lint.

The quick Contra MiSTer CRT build completed with actual exit0: zero errors,398 full-compilation warnings,28%ALMs and11%RAM blocks. The bitstream is left at `release/mister/jtcontra.rbf`. This is compilation validation with `JTFRAME_NOSTA`, not a full timing signoff or PCB run.

New immutable case: `/gdrive/jotego/reverse/YM2151/2026-10-18-jt51-isolated-corrections/`. All418 analysis members and all11 final case files were verified. Analysis archive SHA256 `16207130458468e09d353b0bca1d06624c93cc59ea2da61fc7c5a09451d8c5f8`; final `SHA256SUMS` SHA256 `bf48c5aa19509c09fafe67b0e9442d8cc543ec412dd560dc0b933a93e9338c17`. The case also contains candidate HDL/test sources and build proof/bitstream. [Private-source reproduction instructions](plans/reproduce.md) explain the Gitea fetch required while `.gitmodules` retains GitHub. No fresh CI checkout is claimed tested.
