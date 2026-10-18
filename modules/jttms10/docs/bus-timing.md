# Local-cycle timing and the target transport (#144)

The normal `jttms10_system` enables `BUS_TIMING=1` in its fabric. At
`CLKS_PER_STATE=8`, `jttms10_bus_timer.v` supplies the local-cycle timing
from TI's June 1988 SPVU001A. NARC's external `cyc_ack` is a response from
its memory bridge; that bridge can finish in a few INCLKs and does not
supply a two-state TMS34010 cycle. The CPU fabric retains its early response.

The primary sources are printed pp.11-8 (read cycle), 11-14 (on-chip I/O),
11-16 (wait states), 5-24 (instruction-fetch penalties), and Appendix A
p.A-21 (minimum cycle duration) in the
[TI guide](https://bitsavers.trailing-edge.com/components/ti/TMS340xx/1988_TI_TMS34010_Users_Guide.pdf).

## State and transport contract

| Event | INCLK offset from the logical cycle boundary |
|---|---:|
| First LRDY sampling point, end of Q1 in the second state | 10 |
| Further LRDY samples | 18, 26, 34, ... |
| General read data capture, middle of Q4 | 15 plus inserted wait clocks |
| Completion without waits | 16 |
| Completion with W wait states | `16 + 8*W` |

The abstract target ACK supplies both readiness and data. Readiness captured
by a Q1 sample permits completion six clocks later; a response after that
sample inserts a whole eight-clock state. This combined ready/data transport
does not represent a separate LRDY assertion followed later by LAD data.
An early target response is saved, and `cyc_req` drops after capture while
the logical cycle continues. The target ACK must return low before another
external request; a held request or ACK must not duplicate a transfer.

The bus-state grid advances independently of CPU CEN. Queued requests can
use the first state of the next cycle while the cache/arbiter handoff is
registered. Such allocation never crosses an occupied bus or HOLD interval.
`word_pending` carries the logical transaction across short cache/field
handoff gaps in the physical word request, and clears between unrelated
operations. The timed field/cache/HOLD regression checks a fresh RMW read
and write in consecutive two-state cycles through the real adapters.
For example, four cache-fill completions can occur at clocks 16, 32, 48
and 64 even though the second target dispatch follows the first completion
by three bridge clocks. That dispatch still has to supply readiness before
the appropriate Q1 sample. Newly arriving requests wait for a state boundary.

The traces preserve this distinction:

- `BUS_BEGIN` records the allocated TI state boundary; `BUS_ACCEPT` records
  the later bridge acceptance if allocation used a queued slot.
- `BUS_END` records actual timed completion, with held response data.
- `TARGET_BEGIN` and `TARGET_END` record actual external request/ACK clocks.

The checker derives expected boundaries from TI counts and the reset-relative
clock grid. It checks each transfer's kind, address, IAQ, data, order and
duration. It also checks actual target dispatch and ACK separately. No
original LAD/RAS/CAS/control pins are generated here, so these traces prove
the documented logical-cycle/transport contract, not original electrical
pin edges or independent LRDY/data timing.

## On-chip I/O

TI specifies a fixed two-state on-chip I/O cycle that ignores LRDY (p.11-14).
The timed arbiter occupies those states and obtains data directly from the
on-chip decoder. It issues no external memory transaction for kind 5/6.
NARC's bridge previously only copied that same I/O value on an I/O read;
the register write already commits inside the fabric on `word_ack`.

The model samples live on-chip read data in Q4 and holds it for completion,
rather than retaining the value at arbitration. The exact internal I/O
register latch edge is not documented by TI's external I/O diagram. This
Q4 latch is an explicit model policy consistent with the general read phase;
its internal-edge equivalence is excluded from timing signoff. The fixed
duration and independence from external ACK are normative and tested.

## Fetch and CEN behavior

A disabled-cache opcode read costs two bus states plus one processing state.
A four-word cache fill costs eight bus states plus one processing state
(§5.4.7 p.5-24). The cache identifies hit responses so the core adds that
processing state for external fetches, including misses, while a hit keeps
its published intrinsic count. Directed NOP intervals are 8 INCLK on a hit,
32 with CD, and 80 when the next opcode crosses into an absent subsegment.

The CPU-enable pause is a wrapper extension; TI has no CEN pin. A cached
instruction gains exactly the paused clocks. When an early pause shifts
the following external fetch away from its bus-state boundary, that fetch
also gains the required alignment clocks. The current seven-clock pause
therefore adds seven on a hit and eight before CD/miss traffic: seven paused
clocks and one alignment clock. Reports retain the actual paused count.
Bus and peripheral clocks continue. Pauses overlapping outstanding responses
need separate CPU-level tests; the present matrices pause during CPU work.

## Permanent verification and limits

```sh
python3 modules/jttms10/ver/bus_timing/check.py --report bus-timing.json
python3 modules/jttms10/ver/timing/run.py --case nop --simulator verilator
python3 modules/jttms10/ver/timing/run.py --case nop --wait-states 1 --pause-clocks 7
```

The independent bus oracle runs 699 scenarios: every first-state dispatch
phase with ready delays 0..40, both new and queued requests, on-chip I/O
with external ACK permanently low/high, delayed availability and held ACKs.
It checks completion counts, read-data retention, the I/O latch policy and
absence of duplicate target transactions. A timed-arbiter integration bench
also checks HOLD after allocation but before dispatch, cancellation of a
stale RMW write, rereading externally changed memory, the reserved write,
and a queued host I/O cycle taking exactly two states after the RMW pair.

The full CPU timing suite uses raw target readiness after `4 + 8*W` INCLK,
and independently checks the resulting `16 + 8*W` TI cycles. Two cold NOP
fixtures measure the first pass, with the current opcode at the end of a
resident subsegment and the following four words absent. The normal runner
also keeps 22 checker/model tests and RTL mutations that remove the bus
minimum or sample ready at cycle end. Both mutations must fail timing with
correct architectural results.
Another RTL mutation omits miss processing and must fail bus phase/grid
checks even if the total interval happens to match the published number.

The historical [fast-target baseline](../ver/timing/baseline-bus-e146386.json)
records the untimed fabric at `e14638639`: NOP hit/CD/next-subsegment-miss
took 8/20/35 INCLK instead of TI's 8/32/80, with correct registers/ST. It is
never read by the oracle. Earlier 16/24-clock target profiles supplied the
missing bus duration themselves; those partial results did not establish
timing against the actual fast NARC controller.

Standalone arbiter defaults to raw transport for existing low-level clients.
The legacy fabric/host protocol benches explicitly use `BUS_TIMING=0` to
retain their raw handshake assertions. They are functional checks, separate
from the always-timed bus oracle, timed-arbiter bench and full-system timing
suite. NARC and the complete area measurement enable timing by default.

Full CPU HOLD/IRQ entry and resumption, data-field timings, hidden writes,
graphics, cache replacement/prefetch interactions and other interference
conditions remain required under #144. Passing this bus contract is not full
ISA timing compliance; the standard runner still fails missing-form coverage.
