# Restart #149 short scalar timing fixture

`sim.sh` builds a Verilator executable for the real `jttms10_system` and runs
the independent warm-cache stream in `test.sv`. It sources the project
environment and generates ROM/build files in the output directory, which must
remain outside `ver/build` so the ordinary module runner cannot collide with
it. Pass an explicit output path when keeping a source-qualified result:

```sh
modules/jttms10/ver/restart/sim.sh \
  /nobackup/tasks/jtcores-149/artifacts/restart-tests/current
```

The fixture releases the real host HLT, executes the setup and stream through
the system's synchronous cache, dispatch ROM, control ROM, RF RAM and shared
ALU, then compares consecutive scalar retirement edges against the
TI-derived one-state/eight-INCLK requirement. It counts physical IAQ and memory
transactions separately from cache hits and counts actual RF RAM write edges.
The directed stream includes MOVK, dependent ADD, same-file and cross-file
MOVE, and NOP across adjacent four-word cache groups. It checks the final A0,
A1, B2, and status values as well as exactly-once RF writes. The separate trap
fixture exercises the A15 stack alias while checking TRAP30/RETI stack values.
A redirect marks an interval boundary; branch timing is evaluated independently
from straight-line retirement spacing.

The runner records the source revision, before/after SHA256 manifests for HDL,
YAML, bench, and generated ROM inputs, exact build/run commands, and the actual
CLI result in `result.json`.

TI SPVU001A section 1.3.1.5 and Appendix A define eight INCLK per state;
Table 12-1 and the NOP/MOVK/ADD/MOVE entries specify the one-state cached
conditions used here. Expected timing is independent of the YAML schedule.

The initial #141 run is an expected failure, not a passing baseline. Its saved
`source-revision.txt`, `rtl-working-tree.txt`, and `run.log` are in the task
artifact directory. This first fixture establishes the integrated cache-hit
timing failure. The fixture includes the CEN pause matrix described below and
the directed interrupt/invalidation checks described next. It does not cover
the full flag-condition truth table or a general register-alias sweep.

`run-reserved.sh OUT` runs `test-reserved.sv`, which places reserved opcode
`0200` directly behind a scheduled MOVK in resident code. It checks that the
slot is accepted, TRAP30 reads vector `fffffc20`, the expected PC and ST are
stacked, and RETI restores SP and execution. The same bench supports separate
`run-held-hlt.sh`, `run-flush-slot.sh`, `run-nmi-slot.sh`, and
`run-irq-slot.sh` runs. They check that held HLT, CF invalidation, pending NMI,
or enabled INTIN IRQ cancels the pending slot and that fallback fetch handles
the reserved opcode after resume/return. The CF test issues CF directly while
the slot is pending. A transient HLT pulse before the terminal boundary leaves
the slot consumable.

The timing fixture also runs a 16-case CEN matrix after its architectural
checks: one- and seven-clock pauses at each of eight physical positions. PC,
IR, ST, microaddress, RF writes, IAQ, and external-cycle counts are checked
while paused.

`run-vectors.py --case NAME --out OUT` adapts selected unchanged programs from
`ver/tests.yaml` to Verilator. It generates a temporary copy of the existing
direct-core bench with the new scalar-cache ports tied off. The original bench,
YAML, and expectations remain unchanged. The default case checks reserved
opcode TRAP30 through the direct-core fallback path. The module dispatch-ROM
generator also uses Verilator; its output is checked byte-for-byte against the
checked-in dispatch image.

Selected legacy vector checks cover the direct-core fallback path, not
cache-slot execution.
