# T80 language replay comparison

This companion test replays the sampled input columns of T80 timing and interrupt
suite traces against three implementations: native VHDL analyzed from the
checked-in T80 sources, the checked-in generated `T80s.v`, and a fresh GHDL
synthesis of the native VHDL. It compares every defined public T80s output after
both rising and falling master-clock edges. This is finite differential replay,
not a formal equivalence proof and not an independent Z80 correctness oracle.

From the repository root, after `source setprj.sh`, regenerate the suite traces and run:

```sh
modules/jtframe/ver/cpu/t80_equivalence/capture_suites.sh
modules/jtframe/ver/cpu/t80_equivalence/run.sh \
  --trace tasks/jtcores-150/artifacts/t80_timing-rising.csv
modules/jtframe/ver/cpu/t80_equivalence/run.sh \
  --trace tasks/jtcores-150/artifacts/t80_interrupts.csv
```

`capture_suites.sh` regenerates timing vectors through the suite's `init.go`,
then compiles each simunit testbench with the same Icarus sources and macros as
`simunit.sh` and invokes `vvp` with `+TRACE=<absolute-path>`. This direct call
is needed because simunit has no plusarg forwarding option. Use `--out DIR` to
write the two traces elsewhere. The capture run also executes each test's
normal PASS checks.

Each trace has the 19-column schema exported by the companion suites:
`cycle` (or `master_edge`), `RESET_n,CEN,WAIT_n,INT_n,NMI_n,BUSRQ_n,OUT0,DI`,
then `M1_n,MREQ_n,IORQ_n,RD_n,WR_n,RFSH_n,HALT_n,BUSAK_n,A,DOUT`.
Only columns `RESET_n` through `DI` are replayed. Existing outputs and cycle
numbers are retained for trace provenance; the replay produces its own outputs.
Four-state `DI` values (`X`/`Z`) are preserved as stimulus.
Rows represent inputs sampled immediately before a rising edge. The benches
apply each row at the preceding falling edge and sample outputs 1 ns after both
the falling and rising edges. Clock period is 10 ns. `CEN` pauses the T80 state
machine exactly as in the input trace.

Startup outputs are ignored through the first rising edge that samples
`RESET_n=0`. Afterward all controls are compared strictly. `A` bits are
compared during selected CPU-owned bus cycles; an individual bit is masked
only when its bus field is inactive (`MREQ_n=IORQ_n=1` or `BUSAK_n=0`) and at
least one language reports it as `X`, `U`, or `Z`. `DOUT` bits are compared
during writes (`WR_n=0`); individual bits are masked only while writes are
inactive and at least one language reports that bit as unknown. Known bits
remain compared on inactive buses, and the runner reports every masked bit
sample. Unknown values in active or otherwise unmasked outputs fail even when
both languages produce the same unknown.
Reset-separated cases may share one trace. The input trace's output fields are
not treated as expected behavior because the checked-in Verilog produced them.

`run.sh` writes normalized vectors, per-implementation output CSVs, a first
mismatch summary, hashes, tool versions, and the exact fresh synthesis command
under `tasks/jtcores-150/artifacts/t80-equivalence/` (ignored task artifacts).
Its `replay.json` records each trace's row span and sampled `CEN` count. Pass
one or more `--trace` arguments. With no traces, a seeded deterministic
stress trace is generated, including CEN gaps, WAIT, interrupts, bus requests,
OUT0 changes, and reset during execution. Optional `--seed` and `--cycles`
select its seed and length. Each run also inverts `M1_n` in a temporary copy
of the checked-in netlist and verifies that replay detects this negative
control. `--help` documents options.

Trace metadata records the SHA-256 of each source CSV. The comparator requires
exactly one falling and one rising sample for every input row, in order, and at
least one sample after startup masking. Additional capture controls verify that
matching empty, truncated, and reordered output streams fail comparison.

The VHDL wrapper defaults are `Mode=0`, `T2Write=1`, `IOWait=1`; the checked-in
Verilog is the generated specialization of those settings. GHDL synthesis is
also specialized with those generic defaults. The three sides share only the
public top-level interface and the same sampled input stream. There are no
formal tools in the current environment (`yosys`/`sby` were not available when
this assessment began).
