# Stores and hidden writes (#144)

The primary source is TI's June 1988 SPVU001A
[TMS34010 User's Guide](https://bitsavers.trailing-edge.com/components/ti/TMS340xx/1988_TI_TMS34010_Users_Guide.pdf),
§13.1.1 pp.13-2/3, Fig.13-1 pp.13-4/5 and Table13-2 p.13-6.
Instruction entries are MOVE register-to-indirect p.12-127, postincrement
pp.12-128/129, predecrement pp.12-130/131 and MOVB register-to-indirect p.12-115.
These entries and the summary agree on the counts covered here.

Hidden states are trailing writes which overlap later CPU execution. They
are charged to a following instruction only when it needs the bus before
those writes finish. Consequently a one-state cached store must let cached
instructions execute while its physical write is still outstanding. A correct
memory value or a padded final duration cannot establish this contract.

## Independent expectations

`ver/timing/store_cases.py` inserts source bits individually into an independent
memory image, preserving every other bit. A partially covered physical word
requires a read followed by a write; a whole word requires only its write.
Let `T` be this number of physical transfers and `H = 2*T-1` the hidden
states. Table13-2 gives H=1/3/5/7/9 for its different alignment classes.
MOVB forces eight bits and ignores FS/FE. Stores preserve the complete ST.

| Form | Visible CPU states C | Cached timing | Cache-disabled timing |
|---|---:|---:|---:|
| MOVE register to indirect | 1 | `1+(H)` | `1+H+3` |
| MOVE register to postincrement | 1 | `1+(H)` | `1+H+3` |
| MOVE register to predecrement | 2 | `2+(H)` | `2+H+3` |
| MOVB register to indirect | 1 | `1+(H)` | `1+H+3` |

The first transfer starts after C-1 intrinsic states. The transfers are
ordered, uncached and IAQ-low. Each takes two machine states plus its requested
wait states. With CD, the following opcode fetch starts after the data traffic;
its read plus processing state supplies the additional three states. Every
physical transfer, including that fetch, incurs its own external waits.
With a warm cache, data waits extend the outstanding write, rather than the
visible store interval. The tests check both lifetimes independently.

A following load after K cached NOPs must wait only for the unoverlapped
write work (§13.1.1). Its first data transfer begins at
`max(C+K, C-1+T*(2+W))`, where W is the requested wait states per transfer.
The load then incurs its own ordered reads and final CPU state. The probes
use zero extension and the established load oracle; they assert the exact
following-load boundary, resulting registers/full ST and physical bus events.
They cover K=0,1,2,3,7,10,20, both residual stalls and completely hidden writes.

CEN remains a wrapper extension. The early pause prevents first submission,
holds CPU/sequencer/work state, and adds exactly its paused clocks to a cached
store. The bus begins on its resumed state boundary, which may require an
alignment clock. Subsequent data-dependent work observes that bus grid and
remaining write time. The unpaused TI counts remain mandatory. ACK while
paused, HOLD, interrupt and contention combinations beyond the existing
benches still require a fuller audit.

## Implementation and observer

The synchronous register RAM primes both source and store pointer from the
fetched opcode. Plain/postincrement stores submit the original pointer/data
in the first state, and retain them while a pointer helper changes the register.
Predecrement uses the shared ALU, then samples the source after the update;
if Rs=Rd it writes the updated pointer, as p.12-130 explicitly requires.
No flags are changed by pointer arithmetic.

The field engine already captures address, aligned data, span and word index.
It now owns the outstanding data operation independently of the CPU request.
An accepted posted store can acknowledge the CPU before its physical writes
finish. The one occupied field engine holds subsequent data operations;
program-cache hits can proceed in parallel. Cache misses and CD fetches wait
behind that data owner. IAQ/pixel/SRT metadata stays with its accepted operation.
The logical `word_pending` indication persists across physical-request gaps
and after CPU release. Existing RMW locks and HOLD rereads remain required.

Data transfers bypass the program cache while retaining its former registered
response latency. A response-forwarding gap prevents the raw word port from
accepting the old request again during that register stage. The existing raw
word regression caught this issue even though the complete arbiter's duplicate
filter hid it; it remains active in the normal runner.

The complete system bench emits RESULT at the first following decode, then
continues observing the warm program through a fixed sequence of cached NOPs.
It records trailing bus transfers and snapshots every sparse memory word after
drain. The dependent-load fixtures also record FOLLOW at the decode after the
load. CD stores snapshot after their following opcode fetch, when their data
cycles have necessarily completed. The nine-field batch header contains
observation selections and stimulus, never expected timing or results. Reads,
writes, data/address/IAQ/order, logical duration, raw readiness, CPU state and
preserved memory are checked independently in Python. A structural assertion
rejects loss of `word_pending` while a released field still has physical work.

## Fixtures, historical failures and limits

The initial 3,344 fixtures cover all widths 1..32, all 16 offsets for plain
MOVE, offsets 0/1/7/15 for post/preincrement, both fields/cache modes, ignored
FE, rotating sparse/dense data, file B, shared SP and pointer/source aliases.
MOVB checks all offsets and four ignored FS/FE definitions. Seventy additional
fixtures place a dependent load after different amounts of cached CPU work.
Each store compares every initialized A0..A3, B0..B3, SP, full ST and drained
memory. Each dependent load additionally compares A0..A3/full ST and its exact
completion boundary. This is 3,414 new programs per normal matrix.

The committed [baseline](../ver/timing/baseline-store-309c4a6.json) records the
first 3,344 fixtures on unchanged `309c4a68c`: every timing check fails while
registers, full ST and drained memory pass. An aligned 16-bit store takes
40 INCLK on a hit instead of eight; a byte crossing two words takes 88 instead
of eight. Sixteen form/cache/span representatives and verified historical
HDL/YAML hashes are retained. The 70 later dependency probes are outside that
original capture. Historical observations never become goldens or allowlists.

Two new RTL timing mutations remove posting or prevent cached lookup during
a write. Both must fail with correct registers/ST and final memory. A further
mutation drops the pending-field indication and must fail its event assertion;
it is classified separately from timing-only failures. Existing mutations for
incorrectly caching data, first-cycle allocation, sign work, external waits,
FS1, bus phases and sequencer hold remain active with the new transport.

Offset/absolute store counts have unresolved conflicts within SPVU001A.
For example Table13-2 gives aligned MOVE offset `3+(1),9`, while its p.12-132
entry gives `3+(1),7`; absolute MOVE is `3+(1),13` in the summary and
`3+(1),7` on p.12-134. MOVB offset is `3+(3),7` in the summary but `3+(3),9`
on p.12-116, and aligned absolute MOVB prints `1+(3),7` despite its three-word
encoding. An undated separate TI chapter copy at
[Whtech](https://www.whtech.com/ftp/datasheets%20and%20manuals/Datasheets%20-%20TI/TMS34010/TMS34010-13-Instruction%20Timings.pdf)
also disagrees at MOVE offset. The 1988 scanned summary was inspected; these
are printed discrepancies, not OCR substitutions. Those forms remain outside
this store oracle pending a source-backed resolution. Do not silently impose
a convenient equation or classify them as compliant.

Memory-to-memory moves, all other hidden-write instructions, consecutive
stores, address wrap, replacement/prefetch, interrupts/resumption and full
HOLD/peripheral contention remain in the issue's required scope. Existing
architectural and fabric tests remain active but do not by themselves prove
all those timing conditions. Final fitted area ≤3,500 ALMs, STA and NARC
simulation/MiSTer validation remain open.

```sh
python3 modules/jttms10/ver/timing/run.py --case store_ --simulator verilator
python3 modules/jttms10/ver/timing/run.py --case store_ --wait-states 1 --pause-clocks 7
python3 modules/jttms10/ver/timing/run.py --case dependency --simulator verilator
python3 modules/jttms10/ver/timing/mutations.py
```
