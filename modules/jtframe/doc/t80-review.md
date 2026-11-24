# T80 fidelity assessment

This assessment covers the JTFRAME T80S wrapper and its native VHDL implementation for documented instruction timing, selected architectural effects, interrupt behavior, observable bus timing, and sampled VHDL/generated-Verilog equality. The production CPU RTL was not changed. The implementation baseline is `7981de9dc7a933c4fa971036296644cc70586a55` on branch `jtcores-150`.

No documented instruction T-state or interrupt-service mismatch was found in the tested scope, and native VHDL matched both generated-Verilog implementations on the finite replay traces. The public bus schedule intentionally differs from Zilog's half-cycle pin timing as described below. These results do not warrant a defect follow-up without an unintended mismatch; the documented coverage boundaries still apply.

The evidence has four distinct meanings:

| Claim | Evidence and limit |
|---|---|
| Documented instruction timing | A manifest-driven Verilog testbench checks public fetch-to-fetch enabled-clock intervals against Zilog's manual and checks selected state/effects. The listed outcomes passed; this is not exhaustive for all operand values. |
| T80S public bus timing | Pin samples and waveforms identify the wrapper's edge schedule. T80S deliberately shifts some pin phases from Zilog's half-cycle diagrams; it is not pin-cycle-identical to an original Z80. |
| Selected documented semantics | Directed programs check branch outcomes, stack and memory/I/O effects, ALU results/flags, interrupt vectors, IFF behavior, and returns. This is broad targeted coverage, not proof of all Z80 semantics. |
| VHDL/generated-Verilog language equality | Both implementations produced equal defined public outputs for the captured timing and interrupt input traces and seeded stress. This is finite differential evidence, not formal equivalence. |

## References and implementation provenance

The behavioral and timing oracle is Zilog, *Z80 CPU User Manual*, UM008011-0816 (2016), [official PDF](https://www.zilog.com/docs/z80/um0080.pdf). The timing manifest records the applicable printed page for each canonical encoding. The interrupt suite cites pp. 12–14 for acknowledge, BUSRQ, and HALT exit; pp. 17–19 for IFF/EI/NMI/RETN behavior; pp. 184–187 for IM0/1/2; p. 288 for RETI; and p. 311 for OTIR. The bus comparison below uses pp. 7–10, Figures 5–6. MAME is an independent implementation cross-check, not the normative oracle: source revision `e5a5a102889d6c62f12e39a4db3e950e4f5d6822` (2026-10-02).

`modules/jtframe/cfg/cpu/T80.yaml` selects `T80pa.vhd`, `T80s.vhd`, `T80_Reg.vhd`, `T80_MCode.vhd`, `T80_ALU.vhd`, and `T80.vhd` for native synthesis. The normal wrapper defaults are `Mode=0`, `T2Write=1`, and `IOWait=1`. Native VHDL was analyzed directly with GHDL, including `-fsynopsys -fexplicit`; the latter is needed by the installed GHDL because the source overloads arithmetic operators. The companion replay uses GHDL 4.1.0, Icarus Verilog 13.0, and Python 3.12.3.

The checked-in generated `T80s.v` was last changed in commit `37c88797f66416c0f1c9b4d7d455b4a5b9a95899`, the same commit that updated `T80.vhd` for EI followed by NMI. That commit history is provenance evidence; the generated file does not embed its generator version. Current source hashes and the checked-in/fresh netlist hashes are recorded in each replay run's `provenance.txt`. In the final B trace run, checked-in `T80s.v` SHA-256 is `765e1262ad7020bff0969446f97902c10f6f0918db64b45962d6f5c439e35b5a`; the fresh GHDL netlist SHA-256 is `865d705ebd83ec22abeb937a2454dd4279f8a539a26f535ae1e8d4de69e65a47`. Their text is not identical, while the sampled public outputs match. The fresh generation commands are recorded in the run artifact; in abbreviated form:

```sh
for f in T80_ALU.vhd T80_Reg.vhd T80_MCode.vhd T80.vhd T80s.vhd; do
  ghdl -a -fsynopsys -fexplicit "$JTFRAME/hdl/cpu/t80/$f"
done
ghdl --synth --out=verilog -fsynopsys -fexplicit T80s > fresh-T80s.v
```

Formal tools `yosys` and `sby` were not available in the assessment environment. No formal proof is claimed.

## Documented instruction timing and effects

The permanent timing test is `modules/jtframe/ver/cpu/t80_timing/`. It runs T80S with the JTFRAME synchronous `jtframe_ram`, clocked on the falling edge to settle DI before the CPU's rising-edge sample. Its independent manifest lists all 698 documented canonical encoding keys: 252 base, 248 CB, 58 ED, 39 DD, 39 FD, 31 DD-CB, and 31 FD-CB. Independent reconciliation found no missing documented key, no undocumented key labeled documented, and no unlabeled documented key. Aliases and undocumented supplemental encodings remain labeled separately.

The focused simunit passed, as did the aggregate `simunit-all.sh --only T80s` run across timing, interrupt, and sound tests. The timing suite executed 1,325 manifest vector rows (643 documented and 682 supplemental alias rows), checked 56 conditional branch outcomes, three DJNZ transitions, 13 base unconditional transfer cases and two indexed jumps (15 transfer forms total), and all eight repeating block opcodes. The branch checks cover both outcomes for JR's four supported conditions and JP, CALL, and RET's eight conditions. Directed checks inspect branch destinations, stack byte ordering, DJNZ's final B, block repeat termination/continuation, CPIR/CPDR equality exits with BC=1 and BC=2, BC/HL/DE changes, copied bytes, I/O counts/port/data, and the first bounded zero-count wrap/repeat iteration. Selected semantic cases cover all eight ALU operation classes, DAA, RLC, SRL, BIT, RLD/RRD, EX DE,HL, and indexed-memory read/write. Detailed per-encoding expectations and sources are in `modules/jtframe/ver/cpu/t80_timing/manifest.csv` (SHA-256 `335e558dd0fc3e300716673254f72692962b5c37bb67c83d870d01c04378ca79`).

The zero-count block tests stop after observing the first wrap and repeat; they do not execute all 65,536 iterations. The timing suite holds CEN enabled, WAIT inactive, and interrupts/bus request inactive. `OUT0=1` is not covered. These suites do not establish behavior for every operand value, every undocumented encoding, or every asynchronous input phase.

## Interrupt and synchronous bus coverage

The public-pin interrupt test is `modules/jtframe/ver/cpu/t80_interrupts/`. Its falling-edge synchronous RAM gives instruction data half a clock to settle without adding a wait state. The final run passed 53 reset-delimited cases, including:

Each reset starts the implementation's SP at `FFFFh`, and the stack checks use that T80 reset value. The original Z80 documentation does not define SP as reset to `FFFFh`; this suite does not claim that hardware reset behavior.

| Area | Verified cases |
|---|---|
| Interrupt modes | IM0 injected RST, non-RST `OUT (n),A`, and multibyte CALL; IM1; IM2 vector-table reads across `80FFh/8100h`; NMI. Stack PC, vectors, and acknowledge are checked. |
| IFF and return behavior | DI, EI delay, EI→DI, EI→EI, EI→HALT, EI→NMI, RETN restoration, RETI without implicit IFF enable, and `LD A,I`/`LD A,R` P/V outcomes. Nested NMI preserves IFF2 as specified by Zilog Table 1. |
| Boundary phases | INT and NMI at 14 deterministic offsets around `DD 21 nn nn`, plus EI deferral through an indexed instruction. The return PC is checked at the instruction boundary. |
| Repeating operation | INT pending during EI inhibition is deferred through the first OTIR iteration; already-enabled INT is accepted between OTIR iterations. Exactly one output before acknowledge and the OTIR return PC are checked. This does not cover every repeating block opcode. |
| External holds | One/two WAIT clocks extend the selected fetch interval by one/two enabled clocks. INT remains pending across CEN-low, WAIT-low, and BUSRQ/BUSAK holds. |

Service intervals are measured from the public M1 falling edge that starts acknowledge/service to the M1 falling edge that starts the vector or handler fetch, using enabled clocks and no WAIT in the interval:

| Service context | Measured interval |
|---|---:|
| IM0 injected RST or `OUT (n),A` | 13 enabled clocks |
| IM0 injected multibyte CALL | 19 enabled clocks |
| IM1 to `0038h` | 13 enabled clocks |
| IM2 to vector target | 19 enabled clocks |
| NMI service from the M1 edge immediately before `HALT_n` releases through the first `0066h` fetch | 11 enabled clocks |

These are end-to-end measurements for the specified programs, not universal standalone latencies. Zilog describes two automatic wait states for the special INT acknowledge M1 cycle; that documented addition is distinct from external WAIT. The early OTIR timing suspicion was traced to the bench's memory/oracle setup. Nested NMI was resolved against Zilog's IFF table and MAME: NMI clears IFF1 and leaves IFF2 unchanged, so RETN can restore IFF1. Neither is a confirmed DUT discrepancy.

The suite provides useful public-pin observations, but T80S is not pin-phase-identical to the manual diagrams. Comparing Zilog pp. 7–10, Figures 5–6, to the sampled T80S schedule shows these intentional half-clock phase changes:

| Signal/event | Original Zilog diagram | T80S public schedule | Difference |
|---|---|---|---|
| Opcode fetch MREQ/RD relative to M1 | Asserted half a clock after M1 | Asserted one full enabled clock after the M1 edge | T80S is 0.5 clock later. |
| WAIT sample | Sampled at falling T2/Tw | Sampled on a rising edge while pre-edge internal TState=2 (the corresponding rising T3) | T80S's sample point is 0.5 clock later in the cycle. |
| Write pulse, default `T2Write=1` | WR spans falling T2 to falling T3 | WR spans rising T2 to rising T3 | T80S is 0.5 clock earlier. |

These shifts follow the synchronous T80S wrapper and its note that inputs must be synchronous and outputs may glitch. The bench confirms the sampled wrapper behavior; it does not establish physical setup/hold margins, analog propagation, or board-level tri-state behavior. C does not test every INT/NMI phase crossed with every WAIT/CEN/BUSRQ state, every prefix form, or every block-repeat instruction.

## Native VHDL and Verilog replay

The reusable companion runner and capture command are documented in `modules/jtframe/ver/cpu/t80_equivalence/README.md`. It takes the 19-column rising-edge traces from B and C, replays the sampled inputs through native VHDL, checked-in generated Verilog, and a fresh GHDL Verilog synthesis, and records outputs 1 ns after both falling and rising edges. The traces' existing output columns are provenance only; the comparison oracle is the three implementations driven from the same input rows. Four-state DI values are preserved.

| Input trace | Cases | Input rows | CEN-high edges | Startup row skipped | Compared cycles | Samples per pair (fall + rise) | Masked undefined DOUT bit-samples per pair | Masked address bits |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Timing suite | 1,325 manifest vectors plus directed cases (trace contains all simulator activity) | 155,643 | 155,643 | 1 | 155,642 | 311,284 | 704 | 0 |
| Interrupt suite | 53 reset-delimited cases | 2,654 | 2,649 | 1 | 2,653 | 5,306 | 27,944 | 0 |
| **Total (sum of separate trace runs)** | — | **158,297** | **158,292** | **2** | **158,295** | **316,590** | **28,648** | **0** |

The total sums two independent replay invocations, each of which skips that trace's first reset-startup row. Concatenating both traces into one invocation also passes, but it masks only the first row of the combined stream; the second trace begins from state established by the first trace, so its unreset internal outputs can have different unknown-mask counts.

The mask is per output bit, not per sample: only undefined `A` bits while the address bus is inactive (`MREQ_n=IORQ_n=1` or `BUSAK_n=0`) and undefined `DOUT` bits while `WR_n=1` are ignored. Known bits are still compared on inactive buses. All controls are strict, and unknowns on active address/write-data fields fail even if both implementations show the same unknown. No address bits needed masking in either final suite trace.

All three pairings passed on both traces: native VHDL vs checked-in Verilog, fresh GHDL Verilog vs checked-in Verilog, and native VHDL vs fresh GHDL Verilog. The temporary M1_n inversion negative control was detected at the first post-startup falling sample. Capture controls also rejected matching empty, truncated, and reordered output streams, preventing vacuous common-mode passes. The replay is finite sample-based differential evidence; it neither proves equivalence over all states and inputs nor validates the CPU against Zilog semantics by itself.

The final timing trace SHA-256 is `de7e683eb32f524afa745adae5df3e037f167d7ab7e39e14f0015d4a79ed5979`; the final interrupt trace SHA-256 is `4df65e68c3f1ba0c509b938ef8ae260fd51d63eeaf19bfa3174fc55c55e4b1d2`. Interrupt case-index SHA-256 is `4e7650efead3c775980dd3c6ee199879908272314ed47075da69e9420a797f29`. Replay metadata, outputs, comparison JSON, hashes, tool versions, generated netlist, and negative-control records are under `tasks/jtcores-150/artifacts/t80-equivalence/`; the full input traces and their sidecars remain under `tasks/jtcores-150/artifacts/`.

A separate 2,000-input-row deterministic stress run with seed 150 also passed all three pairs (1,999 compared cycles and 3,998 rise/fall samples per pair after one reset startup row). It exercises CEN gaps, WAIT extensions, INT/NMI, BUSRQ, OUT0 changes, and a reset during execution; its artifact run is `tasks/jtcores-150/artifacts/t80-equivalence/run-20261022T072651Z-297926`.

## Reproduction

From the repository root:

```sh
source setprj.sh
simunit-all.sh --only T80s
modules/jtframe/ver/cpu/t80_equivalence/capture_suites.sh
modules/jtframe/ver/cpu/t80_equivalence/run.sh \
  --trace tasks/jtcores-150/artifacts/t80_timing-rising.csv
modules/jtframe/ver/cpu/t80_equivalence/run.sh \
  --trace tasks/jtcores-150/artifacts/t80_interrupts.csv
```

The capture command recreates both source traces (and regenerates the timing vectors); the replay command creates a new timestamped run folder below `tasks/jtcores-150/artifacts/t80-equivalence/`. The original timing and interrupt suites are Verilog simunit tests; native VHDL comparison is a documented companion command because simunit does not run GHDL VHDL benches. No production HDL was changed, so no unrelated arcade-core build is required.
