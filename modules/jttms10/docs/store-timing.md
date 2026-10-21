# Stores and hidden writes (#144)

The owner's subsequent ambiguity fallback is recorded in
[source-policy.md](source-policy.md). It keeps the simpler implementation
under explicit project interpretations and preserves every printed
alternative. Earlier unresolved-source counts below describe the stricter
source-only audit; the normal gate now distinguishes those choices from
any remaining published-target gaps. Source `54ab1116` resolves all previously
known MOVB targets with the [literal CD byte contract](movb-cd-timing.md). This is not an official TI erratum.

The primary source is TI's June 1988 SPVU001A
[TMS34010 User's Guide](https://bitsavers.trailing-edge.com/components/ti/TMS340xx/1988_TI_TMS34010_Users_Guide.pdf),
§13.1.1 pp.13-2/3, Fig.13-1 pp.13-4/5 and Table13-2 p.13-6.
Instruction entries are MOVE register-to-indirect p.12-127, postincrement
pp.12-128/129, predecrement pp.12-130/131 and MOVB register-to-indirect p.12-115.
These entries and the summary agree on the initial four forms. Extension-address
forms now have probes under the explicit source policy below; conflicting
conditions remain excluded from unqualified TI-count signoff.

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
| MOVE/MOVB offset | 3 | `3+(H)` | `3+H+6`, policy where sources conflict |
| MOVE absolute | 3 | `3+(H)` | `3+H+9`, policy where sources conflict |
| MOVB absolute, one physical word | 1 | `1+(3)` | 7, literal byte entry |
| MOVB absolute, two physical words | 3 | `3+(7)` | 13, literal byte entry |

For the generic field schedule, the first transfer starts after C-1 intrinsic states. The transfers are
ordered, uncached and IAQ-low. Each takes two machine states plus its requested
wait states. The native CD absolute-byte contract instead reserves an unrelated opcode
before its final whole RMW pair; the first pair of a straddled byte completes
before that opcode. For the generic CD field schedule, the opcode starts after the data traffic;
its read plus processing state supplies three states. Extension-address
forms additionally fetch each address word with CD; §5.4.7 supplies the
three-state increment per instruction word used by the explicit policy. Every
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
benches still require a fuller audit. Measured destinations are ordinary
memory; internal-I/O effects and immediate consumers of implicit peripheral
registers require separate event/dependency checks.

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
finish. Offset and absolute stores combine extension bus/operand capture and use
that same ALU for the effective address. The shared load/store counter gates
first/second address-word requests and preserves the remaining address lead
after an external response. Absolute stores encode their source in the low
register field and consume RD; offset stores consume RS. This distinction
is checked through both register files and shared SP.

The one occupied field engine holds subsequent data operations;
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
cycles have necessarily completed. First-pass cold-extension stores use a separate drain mode: RESULT still
captures the exact following decode, then the CPU is held while its accepted
write finishes. This prevents unrelated later cold-cache fills from contaminating
the trailing-write observation. CPU/sequencer/register holds remain asserted;
the bus keeps running. The post-boundary hold is observation only and never
changes the measured base interval or waives transfer timing. Cold RMW reads
compare initial memory; warm idempotent stores compare their prior-pass image.
The nine-field batch header contains
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

## Extension-address source policy and conflicts

`ver/timing/store_mode_cases.py` adds **1,054 programs**: 680 use counts
consistent with the applicable primary summary, 242 carry explicit
`inferred-conflict-resolution` status, and 132 extend the previous forms'
FE/wrap coverage. The four additional forms are MOVE/MOVB offset/absolute.
Reports preserve `source_values` for the summary, typical instruction entry
where applicable, and selected policy. Unit tests assert that conflicting
values stay visible. These inferences are not official TI errata and are
excluded from unqualified published-count compliance claims.

The policy uses intrinsic C=3, alignment H from Table13-2 and three added
states per instruction word with CD (§5.4.7 p.5-24). It gives `3+(H)` on a
hit and `3+H+3*I` with CD, where I=2 for offset and I=3 for absolute. MOVE
absolute's complete summary row agrees with this equation. MOVE offset's
B/C, D/E and G summary columns agree, while A and F conflict. MOVB's entries
have further inconsistent CPU/CD counts. The printed values include:

| Condition | Instruction entry | Table13-2 | Selected policy |
|---|---|---|---|
| MOVE offset, aligned 16 bits | `3+(1),7` p.12-132 | `3+(1),9` | `3+(1),10` |
| MOVE offset, aligned 32 bits | `3+(3),9` p.12-132 | `3+(3),12` | `3+(3),12` |
| MOVE offset, two partial words | Refers to summary | `3+(7),13` | `3+(7),16` |
| MOVE absolute, aligned 16 bits | `3+(1),7` p.12-134 | `3+(1),13` | `3+(1),13` |
| MOVE absolute, aligned 32 bits | `3+(3),9` p.12-134 | `3+(3),15` | `3+(3),15` |
| MOVB offset, one word | `3+(3),9` p.12-116, byte aligned | `3+(3),7` | `3+(3),12` |
| MOVB offset, two words | Refers to summary | `3+(7),13` | `3+(7),16` |
| MOVB absolute, one word | `1+(3),7` p.12-117, byte aligned | `1+(3),7` | `1+(3)` cached; literal CD7 |
| MOVB absolute, two words | Refers to summary | `3+(7),13` | `3+(7),13`, literal byte entry |

Single-word absolute MOVB needs particular care: its instruction entry and
summary **agree** on `1+(3),7`. Cached bytes at bit offsets 0..8 now use the
published one-state intrinsic duration. The synchronous instruction cache
supplies resident address operands alongside the opcode; missing operands
retain the nine-state subsegment-fill penalty. The field adapter still performs
the actual external read/modify/write. The native cache-disabled path now
uses the literal seven-state count; a straddled byte uses CD13. It queues one
complete final RMW after the unrelated next opcode, with exact contents,
cycle lengths and a bounded hidden drain checked independently. Instruction-
word dependencies have separate ordering checks and no unrelated-opcode
nominal duration assertion. No known CD target is waived.

The additional 192 cached cases cover A/B source registers 0/1/2/SP, opcode
positions 0/1/2/3/30/31 within a cache segment and bit offsets 0/1/8/9. Position 31
crosses a segment boundary; offset 9 checks the two-word fallback. All 347
absolute-byte probes pass the short original Verilator base run, with 18
wait/pause representatives also passing. The historical cached-byte DataStorm image passes
all 141,428 fixtures in each of base/W1-P7/W3; 23 focused cases per profile
match the original Verilator bench. All 164 published-target observations,
including their errors, also match: 137 pass and the 27 CD duration gaps fail.
The standard equivalence command refuses failing captures, so this latter
comparison is diagnostic evidence and does not turn failures into passes.
Source `54ab1116` now passes all 164 published targets each BASE/W1P7/W3, with 492
exact Verilator comparisons. See the [source-bound FPGA checkpoint](../ver/fpga/README.md).

An undated separate TI chapter copy at
[Whtech](https://www.whtech.com/ftp/datasheets%20and%20manuals/Datasheets%20-%20TI/TMS34010/TMS34010-13-Instruction%20Timings.pdf)
also disagrees with SPVU001A at MOVE offset. The scanned 1988 summary was
inspected: these are printed discrepancies, not OCR substitutions. Prefer
an authoritative later revision/erratum or hardware evidence if it resolves
these conflicts; retain the explicit distinctions until then. A passing
policy probe must not silently become a claim that both contradictory
published numbers have been satisfied.
The permanent `ver/timing/coverage.py` gate now fails on unresolved
source/policy differences as well as missing forms. Its JSON distinguishes
an agreed published-target gap from an unresolved choice between sources.
It compares the numeric alternatives independently of the status label;
relabeling a probe as summary-consistent cannot make a differing count pass.

The additional matrix covers both fields/FE/cache modes, width/alignment
boundaries, signed offset endpoints, aliases and full transport addresses.
It includes SP/address wrap and orthogonal FE checks for the earlier modes.
Thirty cold first/second-extension probes and two additional cold phase cases
check four IAQ-high fill reads and the nine-state miss penalty before posted
data traffic. Four CD extension forms join those cold cases in all six short
CEN profiles. Fifty dependent-load probes check hidden work after the new
forms. The sparse target accepts high writes only at initialized addresses.

**108 literal probes** use the hand-transcribed output words of TI's worked
examples on pp.12-116/117/133/134, including their actual addresses and signed
offset endpoints. A separate unit check compares the mathematical bit model
to those literals. The default runner remains offline and reads committed
constructors and expectations, not downloaded documents or development files.

The [extension baseline](../ver/timing/baseline-storeext-b52dbd5.json) captures
unchanged `b52dbd556` with the final observer: all **922 new-form probes fail
timing**, while 132 previous-form FE/wrap additions pass. Every A/B/SP/full-ST
and final-memory comparison passes. Twenty-four form/cache/cold/min-max-span
representatives and 22 verified historical HDL/YAML hashes are retained as
historical evidence only. Two new RTL mutations omit store address pacing
or lose post-fill intrinsic work; both must fail with correct registers/ST
and drained memory. The extension-store milestone has 23 positive controls and 28 rejection
checks: 26 timing/stimulus demonstrations and two event contracts.
Current suite totals, including subsequent control-flow checks, are in
[control-timing.md](control-timing.md).

Memory-to-memory moves, all other hidden-write instructions, consecutive
stores, wrap conditions beyond the present probes, replacement/prefetch,
interrupts/resumption and full
HOLD/peripheral contention remain in the issue's required scope. Existing
architectural and fabric tests remain active but do not by themselves prove
all those timing conditions. Final fitted area ≤3,500 ALMs, STA and NARC
simulation/MiSTer validation remain open.

```sh
python3 modules/jttms10/ver/timing/run.py --case store_ --simulator verilator
python3 modules/jttms10/ver/timing/run.py --case store_ --wait-states 1 --pause-clocks 7
python3 modules/jttms10/ver/timing/run.py --case dependency --simulator verilator
python3 modules/jttms10/ver/timing/run.py --case storemode_ --simulator verilator
python3 modules/jttms10/ver/timing/run.py --case storemode_ --wait-states 1 --pause-clocks 7
python3 modules/jttms10/ver/timing/mutations.py
```
