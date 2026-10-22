# StageB shift and LMO red baseline

Run with:

```sh
modules/jttms10/ver/restart/run-stageb.sh \
  --source-rev 4b0ae60113440b9011ed74216fab54cd46270955 \
  --out /nobackup/tasks/jtcores-149/artifacts/stageb-baseline-4b0ae-nop-qualified
```

The runner defaults to committed CPU source `4b0ae60113440b9011ed74216fab54cd46270955`; `--source-rev` selects a different archived revision. It does not compile the live worktree's dirty CPU files. It uses the Verilator dispatch-ROM generator in that revision and builds all generated files under the requested output path. A non-empty output path is rejected, so each run creates a fresh source snapshot. The case generator obtains unchanged `oracle.py` and `scalar_cases.py` bytes from frozen commit `9a17778b941dce89328316ee3e8f7f0a4bd14923` and records their SHA256 hashes, case IDs, exact commands, source manifests, ROM manifests and actual Verilator exit in `result.json`.

The 18 resident instructions cover SLL, SRA, SRL and RL at counts 0, 1 and 31; same-register SLL/SRA count/data aliases; the literal TI SLA example `CCCCCCCC << 3 = 66666660` with NCZV `0001`; and LMO for the top bit, bottom bit and zero. The cases exercise zero/count boundaries, sign propagation, carry/rotate edges, flag preservation and alias reads. The independent oracle supplies each architectural result and complete expected status. The system runs the setup and sequence to warm its actual cache, repeats setup to restore destructive destinations, and then uses a resident NOP lead-in to set the measured interval boundary before the second shift sequence. The bench pairs registered retirement with the instruction and PC sampled before the terminal edge, when the core advances IR and PC. The measured pass produces no external IAQ or external memory requests. Setup status is seeded through B10.

Timing expectations come from frozen `oracle.shift_states()` and
`INPUT_CLOCKS_PER_STATE`: SLL/SRA/SRL/RL and LMO are one TI machine state
(8 INCLK); SLA is three states (24 INCLK). The shift family pages are printed
pp. 12-234 through 12-246 of TI SPVU001A; LMO is p. 12-108; the clock rule is
§1.3.1.5, p. 1-7. The SLA result/flags also match the printed p. 12-239 example.
No expectation is derived from the current YAML or observed RTL timing.

On committed `4b0ae601`, architectural results and status pass for all 18
cases, but all 18 retire intervals miss TI timing. In case order, the measured
INCLK intervals are 6, 17, 77, 15, 17, 77, 15, 17, 77, 15, 17, 77, 17, 77,
21, 15, 79, and 15 (expected 8 except SLA's 24). The runner preserves
Verilator's actual nonzero exit status 1 as a red feasibility baseline. See
`run.log` and `stageb-cases.json` in the artifact directory for per-case values
and provenance. The earlier `stageb-baseline-4b0ae-final` artifact remains the
separate PUTST-to-first-case boundary run; its first interval included the
unoptimized preceding fetch and is superseded for timing evidence by the NOP
lead-in run. This short set does not qualify every shift encoding, flags truth
table, cache-disabled timing, or other instructions.
