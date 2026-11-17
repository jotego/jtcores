# 68000 read/write DTACK timing

This simunit runs the real fx68k with the production `jtframe_68kdtack_cen`.
All eight combinations of `WAIT1`, `wait2`, and `wait3` execute matching
`MOVE.W (A0),D0` and `MOVE.W D0,(A0)` loops, with ready memory and with a
16-master-clock response delay. Both combinational chip selects and chip selects
registered one master clock after the data strobes are tested. A separate TAS
loop runs in each configuration, and unmapped accesses exercise automatic
acknowledgement with `bus_cs=0`.

Each MOVE instruction takes 8 CPU clocks; `BRA.S` takes 10. Four external
transfers occur per loop, including the discarded branch prefetch. The test
checks that transfer count, the exact CPU phase count and ready-memory master-clock duration,
the S2-to-S7 duration of each data transfer, actual data writes, and the value
consumed by the CPU. Read and write totals must be exactly equal. The late
response cases must really withhold phases. The ledger is checked after each
master-clock update and across the measured interval. Ready loops must balance
held and replayed events without growing debt. The repeated 16-clock response
can exceed recovery bandwidth with some wait settings; those stress cases must
still have identical read/write elapsed times and exact CPU phase counts.
Finally, offering traffic stops and all remaining debt must drain
before the test can pass.
Memory latency starts at address setup, the same deadline for both directions.
DTACK must never precede that deadline, including while registered decode is
pending. The helper's strobe guard must clear between both halves of TAS.

The default divider is 1/3 (16 MHz from 48 MHz), where some CPU half-phases
are only one master clock apart. `JTFRAME_DTACK_DEN` can select 4 (12 MHz) or
2 (24 MHz). Dividers 3 and 4 must preserve exact wall-clock read/write symmetry and repay
every withheld phase after traffic stops. Divider 2 emits a nominal phase every master
clock, so no spare recovery slots exist: it checks exact executed CPU phases,
data and forward progress, but cannot require physical memory latency to be
repaid or equal wall-clock throughput. Ready writes may briefly be held while
the registered decode settles; those physical holds are included in the debt.

The existing read timing is preserved:

| WAIT1 | wait2 | wait3 | Added CPU waits per transfer | MOVE/BRA clocks | TAS/BRA clocks |
|---|---|---|---|---|---|
| 0 | 0 | 0 | 0 | 18 | 24 |
| 0 | 1 | 0 | 0 | 18 | 24 |
| 0 | 0 | 1 | 1 | 22 | 29 |
| 0 | 1 | 1 | 1 | 22 | 29 |
| 1 | 0 | 0 | 1 | 22 | 29 |
| 1 | 1 | 0 | 1 | 22 | 29 |
| 1 | 0 | 1 | 2 | 26 | 34 |
| 1 | 1 | 1 | 2 | 26 | 34 |

`wait2` is an earlier qualification stage, not an additional whole CPU wait
with the current fx68k sampling. Both high has the same timing as `wait3` alone;
the regression asserts that equality directly. The table is a description of
the retained timing, not a change to the meaning of those inputs.

TAS checks exact instruction phases, a strobe gap with AS held low, one read
and one accepted write per iteration, the modified upper byte, the unchanged
lower byte, and the following CPU readback. The production CPS1
[SDRAM and BRAM TAS test](../../../../../cores/cps1/ver/tas_dtack/README.md)
separately covers real memory requesters and both byte lanes.

A final synthetic transfer checks raw `BGACKn` with the legacy `bus_ack` input
held low: CPU phases continue, DTACK clears, and outstanding recovery debt
stays frozen until the bus is returned.

Run from the repository root after sourcing `setprj.sh`:

```bash
simunit.sh --run modules/jtframe/ver/cpu/68kdtack_rw
simunit.sh --run modules/jtframe/ver/cpu/68kdtack_rw --macros JTFRAME_DTACK_DEN=4
simunit.sh --run modules/jtframe/ver/cpu/68kdtack_rw --macros JTFRAME_DTACK_DEN=2
```

`init.go` generates the same Icarus-compatible fx68k enum spelling used by the
CPS2 DTACK test and copies its microcode. Cleanup removes those generated files.
