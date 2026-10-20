# Cache-disabled byte-store instruction dependencies

Run `python3 modules/jttms10/ver/store_dependency/check.py` from the checkout.
The normal `modules/jttms10/ver/run.sh` also runs this short Verilator check.
Use `--report result.json --traces traces/` to retain observations, and
`--rtl-dir /path/to/hdl` to test a candidate CPU independently of its oracle.

The 16 independent programs use absolute and indirect-to-indirect MOVB,
offsets 0/8/9/15, and destinations in the following or preceding instruction
word. Five wait/CEN profiles give 80 executions. Every case runs on its first
pass with CD set, drains accepted physical work without executing a CPU tail,
and checks all initialized registers, full ST, sparse memory and next opcode.
The bitwise Python insertion oracle preserves bits outside the byte.

The checker requires exactly the expected operand, source, RMW and instruction
transactions; read data, write payloads and IAQ; physical cycle durations and
target dispatch bounds; contiguous read/write pairs; word insertion order;
and the modifying write before a dependent opcode fetch. A final correct memory
image cannot hide an instruction fetched before its modifying write. Duplicate
opcode reads fail, even if they return the same value.

TI SPVU001A §§5.4.6 (printed 5-24), 6.2 (6-4), 11.3 (11-4) and the MOVB
entries (12-117/119) supply these architectural/bus rules. This test checks
cache-disabled operation. It makes no promise about cached self-modifying code,
which §5.4.4 warns can be unpredictable. It does not assign a new TI duration
to the dependency cases: published nominal duration targets remain mandatory
in the separate timing suite. The FPGA transport is not part of the oracle.
Writable instruction-word transport is not yet qualified on the FPGA; these
new dependency cases currently run only in Verilator.

The timing bench accepts a retirement pulse from the last enabled edge at the
first paused edge, then clears that allowance. PC, ST, GPR and working-state
hold assertions remain active, and a new pulse during a pause still fails.
