# Timing restart — issue #149

[#144](http://gitea.jotego.es/jotego/jtcores/issues/144) is closed **unsolved**.
Its tested instruction examples did not establish complete condition timing,
and its implementation exceeded the area and constrained speed limits.
[#149](http://gitea.jotego.es/jotego/jtcores/issues/149) starts again from the
accepted #141 CPU, with the verification and DataStorm transport considered
separately.

## Status

The starting HDL and YAML are exactly the accepted #141 implementation
`a0d3612799adaa1df556aac8b5f6f2b27ae33b5b`, through its closing documentation
checkpoint `740709abbf72cb8af0f5e5e7668753979f5fd28f`. That implementation
passed the recorded functional suites, NARC simulation and MiSTer gameplay.
It explicitly did not establish instruction-cycle accuracy. No new #149
instruction form is yet qualified as fully timing compliant.

| Matched four-fit mean | #141 baseline | Stopped #144 |
| --- | ---: | ---: |
| ALMs | 2,752 | 5,129 |
| Reported Fmax | 56.415 MHz | 47.2075 MHz |
| Registers | 1,523 | 1,669 |
| M10Ks / DSPs | 69 / 0 | 71 / 5 |

The final acceptance limits remain **3,500 ALMs** at the complete NARC CPU
boundary and positive constrained **20 ns / 50 MHz** timing. The #141 figures
are the starting measurements; no new #149 fit is claimed.

## Findings and design rule

Astra's independent audit and Sol's review find that most added combinational
logic is in the main CPU's scheduling and operand selection, while the shared
ALU's atom count is almost unchanged. The four stopped-source worst slow-corner
paths run from IR into MD. Compiler atom counts locate growth; they do not
predict removable fitted ALMs.

**Instruction sequencing, delays and timing adjustments belong in YAML
microcode.** Do not add instruction-duration counters, opcode-specific timing
schedulers or parallel execution paths in RTL. RTL changes must implement a
justified shared resource or generic sequencer/protocol capability. Preserve
synchronous control ROMs and register RAM, one ALU and shared scratch storage.

The existing two-clock ROM prime/execute cadence and synchronous RF latency
must be included in the microcode schedule. One TI state is eight INCLK edges;
NARC supplies the CPU with its 48 MHz clock. Cache/RF responses and physical bus
events must be measured independently of retirement pulses.

## First decisions

1. Prove a real resident-cache NOP/ADD/MOVE/MOVK stream with eight input clocks
   between instruction boundaries, using explicit YAML microsteps and a bounded,
   side-effect-free cached-word lookahead. No speculative external miss traffic.
2. Check dependent registers, both files/SP aliases, pauses and invalidation.
   Run short Verilator diagnostics and measure the fitted complete CPU before
   migrating more instructions. An initial planning budget is 3,000 mean ALMs;
   exceeding it requires another architecture decision.
3. Immediately prove maximum-count shifts/LMO, unaligned fields and posted
   writes. The original serial operations cannot meet all published short
   instruction counts just by changing delays. Any shared hardware replacement
   needs its own measured area/STA comparison and microcoded schedule.
4. Prove representative graphics and interrupted/resumed work before broad
   condition expansion. Preserve all original functionality and the final
   CI/NARC/MiSTer acceptance gates.

Long supported matrices run on DataStorm through its dedicated operator.
Short diagnostics use Verilator. Use `/opt/quartus_free` and retain stable
HPS/test infrastructure for incremental compilation. The old loaded #144 image
and its passing scope do not qualify the new CPU.

Every milestone reports demonstrated timing scope, remaining conditions,
original/previous/current area and speed, structural cost and next decision
before detailed implementation notes. Passing examples and fully compliant
instruction forms are distinct counts.
