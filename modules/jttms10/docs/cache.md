# Instruction-cache helper

`jttms10_cache` is a physical 16-bit word client/server inserted
between the CPU's word interface and the memory fabric. Addresses are **bit**
addresses, with bits 3:0 zero for a physical word. It has no dependency on the
old TMS34010 RTL. `jttms10_word` connects it between the field adapter and
the peripheral fabric; `jttms10_system` supplies the cache controls.

The cache contains 128 words in a synchronous 32×64 data array, implemented
as four parallel 32×16 lane RAMs: four 32-word
segments, each with eight four-word subsegments. `tag[slot]` holds address
bits 31:9, `present[slot][subsegment]` records filled subsegments, and
`lru[0:3]` lists segment slots from most to least recently used. Reset and
CF restore the numerical LRU order 0,1,2,3 and clear all present bits. The
data array needs no reset because no word can hit without a present bit.
Misses fetch the four words of a subsegment in ascending address order, even
when the requested word is in its middle. Downstream `m_req` and its payload
stay asserted until each `m_ack`; upstream `c_ack` is a single pulse for a
held request. A following request must drop `c_req` or change its complete
payload tuple. `c_restart` passes the fabric's HOLD/RMW restart indication
through, including between a bypassed partial read and write. On a restart,
the cache also cancels any captured but unaccepted bypass write, suppresses
`m_req` on that edge, and clears its request deduplication state. The field
adapter can then reread the external word before merging the partial write.

The CPU must supply `c_program` for **every** PC-directed word access:
opcodes, immediates, displacements, and absolute-address extension words.
`c_iaq` is a separate bus-status input; it must not be used as the cacheability
test because the current CPU distinguishes opcode IAQ from PC extension reads.
All data/vector/stack accesses set `c_program=0`. Writes and pixel-tagged
accesses bypass the cache regardless of `c_program`. Bypasses preserve
address, write data, IAQ, pixel tag, and lock. A cache fill marks all four
physical reads as instruction acquisitions (`m_iaq=1`), matching the old core's
bus behavior; the guide names IAQ as instruction acquisition status but does
not specify the per-word pin value during a four-word fill. Hits generate no
external memory request.

Each logical row holds one four-word subsegment. A fill writes one 16-bit
lane; a hit reads all four banks through their synchronous read ports. Separate
banks give each RAM a complete word write and preserve Quartus inference.
Opcode hits also expose the following two resident words to the CPU. If they cross
a subsegment boundary, the next row is read during the existing ACK-to-decode
interval, including segment boundaries and 32-bit address wrap. This lookup
does not initiate an external fill or alter replacement order. A separate
first-word-valid signal permits consumption of a resident low address when
the high address word is missing. CD, CF, restart and a new request revoke
this metadata; a paused CPU retains the captured pair.

The CPU uses this path for cached register-to-absolute MOVB when the complete
byte fits one physical word (bit offsets 0..8). It consumes the address with
the opcode and posts the ordinary field-adapter read/modify/write. Bytes
crossing a word boundary retain the general extension path. See
[store timing](store-timing.md) for the independent duration targets.
The fitted DataStorm implementation infers four 32-by-16-bit `altsyncram`
banks (2,048 data bits), rather than a register mux. Variable partial writes
and fixed-slice writes into one wide array failed the Quartus inference probe;
complete-word writes to separate synchronous banks preserved RAM inference.
The appliance uses three more M10Ks than its preceding narrow-cache image.

`cache_disable` connects to CONTROL.CD. While CD=1, each requested word goes
directly to memory, and cached contents and replacement order are preserved.
`cache_flush` connects to HSTCTLH.CF. While CF=1, present bits and LRU remain
at reset state. With CD=0, each instruction request still reads all four words
of its subsegment, returns the requested word, and discards all four. With
CD=1, the single-word bypass wins. A mode change during an active fill poisons
that fill so it cannot install a partly collected subsegment. The CPU-visible
register owners must provide these two live level signals; there is no flush
request/ack transaction.

The CPU's `mem_program` marks opcode and PC extension reads. The word
wrapper routes aligned 16-bit program reads directly to the cache, avoiding
the field adapter's alignment and response states. It returns cache ACK/data
to the core, whose response latch captures ACK even while CEN is paused.
Data, vectors, stacks and pixel fields continue through the field adapter.
The wrapper captures qualifiers with those logical field requests, supplies
CONTROL[15] as CD, and takes CF from HSTCTLH[14]. The integrated system bench
executes a loop and observes the first four-word fill followed by cache hits.
Host-indirect CONTROL writes exercise CD bypass and preservation, while
direct HSTCTL writes exercise held CF refills and recovery. Its stack and I/O
transactions continue to bypass the cache. The word-bus stack smoke test
explicitly disables the cache to retain its separate physical-order checks.

The cache deliberately does not snoop data writes. Self-modifying code can
leave a stale resident instruction until a flush or replacement, as on the
TMS34010. The cache must sit on the CPU side of the fabric so screen refresh,
DRAM refresh, host transactions, and HOLD arbitration continue at the fabric.

Primary reference: *TMS34010 User's Guide*, §5.4.1–5.4.6 (printed pp. 5-20
through 5-23) for organization, PC-only qualification, fill and LRU behavior,
reset, self-modifying code, CF, and CD; §11.4 (printed p. 11-5) names IAQ as
the instruction acquisition bus status bit. The §5.4.5 paragraph saying
“While CD=1” while discussing four-word discarded fills is inconsistent with
the explicit CF=1/CD=0 versus CD=1/CF=0 distinction in §5.4.6; this helper
follows the latter.

Standalone verification:

```sh
bash modules/jttms10/ver/sim.sh cache
verilator --lint-only -Wall --top-module jttms10_cache \
    modules/jttms10/hdl/jttms10_cache.v
```

The bench checks fill order, PC-extension hits, subsegment and segment misses,
replacement LRU, waits and stable held payload, stale self-modifying reads,
CD preservation, held CF behavior, IAQ/pixel/data bypass, one acknowledgment
per held request, reset during a stalled fill, resident operand pairs across
subsegment/segment/wrap boundaries, partial validity without an external fill,
and immediate metadata revocation on CD/CF/restart. Integrated cache and
system fits are recorded in [the area measurements](../ver/area/README.md).

The direct program path removes unnecessary field-processing clocks. The
cache now asserts its hit ACK while the synchronous RAM output is valid in
HIT, rather than adding another response clock. Its fill/bypass response
still uses a registered ACK. The CPU captures the hit even when CEN is paused.
The initial NOP/ADD/MOVK/multiply timing probes pass with cache hit/off;
missing instruction forms and cache-miss/overlap tests remain explicit gaps
in the [timing coverage ledger](timing.md).

An isolated Quartus Prime 20.1.1 Analysis & Synthesis map of source SHA-256
`e1318b798308c6737f4c079b6b7b73b4a280bfa368b80975217f9a4ffce09cdf`
used Cyclone V `5CSEBA6U23I7`, 20 ns clock, and virtual pins. It inferred
one simple dual-port 128×16 `ALTSYNCRAM` (2,048 block-memory bits, zero MLAB
bits), 230 registers, zero DSP blocks, and an estimated 303 ALMs. This is a
**map-only standalone cache** figure, not a fitted or integrated area count.
The immutable QSF, source, report, and manifest are in
`/tmp/jttms10-141-area/cache-map-v2`.

`ver/cachefield/test.sv` separately instantiates the real field adapter,
cache, and arbiter. It holds a stale partial write in the cache, grants HOLD,
changes unrelated external memory bits, and checks the physical cycle trace
is read, HOLD, reread, sole write with a fresh merged value:

```sh
iverilog -g2005 -s test -o /tmp/jttms10-cachefield-test \
    modules/jttms10/ver/cachefield/test.sv \
    modules/jttms10/hdl/jttms10_field.v \
    modules/jttms10/hdl/jttms10_cache.v \
    modules/jttms10/hdl/jttms10_bus.v
vvp /tmp/jttms10-cachefield-test
```
