# Coordinate timing (issue #144, in progress)

CPW uses **1/4 machine states** and CVXYL **3/6** for a cache hit/cache
disabled. SPVU001A printed pp.12-57–60 and summary p.12-12 agree on
these counts; the June1991 SPVS002C data sheet p.11 gives minima1/3.
These scalar probes do not establish timing for pixel/array/LINE work.

## Independent rules and source discrepancies

CPW compares signed 16-bit coordinates against nonnegative ordered
WSTART (B5) and WEND (B6). Negative window limits have unpredictable
results (pp.12-57/58) and are excluded. The model independently sets
left/right/above/below bits5/6/7/8. Only V changes; N/C/Z and other ST
bits remain preserved. Sixteen literal TI point-code examples anchor it.

CVXYL preserves ST and uses OFFSET (B4), CONVDP and PSIZE. Programs set
CONVDP/PSIZE with real memory-mapped instructions before warming the
cache; B3 contains the corresponding destination pitch. No register or I/O
state is forced by the bench. The five low CONVDP bits are inverted to
obtain the Y shift (pp.4-12,6-15), so CONVDP20 means pitch0x800.
PSIZE is1/2/4/8/16. Y is signed16; X is nonnegative. Negative X is
excluded, and X=0 follows the explicitly described origin on p.4-12.
The model computes mathematical products, ORs their 32-bit values, then
adds OFFSET with 32-bit wrap. Addition must not replace that OR when
coordinate bits overlap the pitch.

Four scanned results on p.12-60 disagree with the repeated conversion
formula on pp.4-12 and12-59. For point0x00400030:

| PSIZE | CONVDP | OFFSET | Printed example | Formula |
| --- | --- | --- | --- | --- |
| 4 | 20 | 0 | 0x00020000 | 0x000200C0 |
| 4 | 20 | 0x00008000 | 0x00028000 | 0x000280C0 |
| 4 | 20 | 0x0F000000 | 0x0F020000 | 0x0F0200C0 |
| 1 | 21 | 0 | 0x00010000 | 0x00010030 |

The other five literal examples agree. Expected results follow the
formula, with both alternatives retained in source metadata. This is a
behavior discrepancy; the printed3/6 timing agrees. No official erratum
is claimed. Sixteen bank/cache probe instances expose these alternatives.

An online search also checked the archived1986 SPVU001 guide and another
1988 scan. They repeat the relevant discrepancies; neither is revisionB.
The1991 data sheet references SPVU001B, but a verified copy or pertinent
TI erratum has not been located. Sources include the
[1986 TI guide](https://www.transputer.net/mtw/rg-750/doc/tms34010/t34010ug.pdf),
[1988 TI guide](https://bitsavers.trailing-edge.com/components/ti/TMS340xx/1988_TI_TMS34010_Users_Guide.pdf)
and [alternate1988 scan](https://old.vgamuseum.info/images/stories/doc/profi/tms34010userguide_88.pdf).
The project owner directs us to choose the simpler implementation where
reliable clarification cannot be found. Keep the mathematical conversion
and existing source-backed schedules, record the interpretation, and retain
all printed alternatives. Agreed published-target gaps remain required
fixes. Such a project choice does not assert an official TI correction.

## Shared datapath and checks

CPW performs two packed subtractions through the existing shared ALU.
The first captures low-window code bits; the second combines upper-window
bits and writes the result/V. Source/WSTART synchronous reads are primed
at the opcode response edge, before IR commit; the port then selects WEND.
The bench checks data-at-ACK and the existing direct-branch settling rule.

CVXYL reuses the existing scalar DSP product twice for Y*pitch and
X*PSIZE, keeps OFFSET in B, combines products with OR and finishes through
the shared adder. No arithmetic unit, DSP, register storage or ROM width
is added. CPW receives one intrinsic state and CVXYL three.

The expansion adds **5,116 real programs**:5,108 standalone and eight
immediately following taken long-JR/JAcc targets. All initialized
A0..A3/B0..B6/SP and full ST are checked. Coverage includes signed
coordinate extrema, window edges, all32 pitches ×5 pixel sizes ×5 Y
patterns, overlapping OR bits, offset/address wrap, both banks, aliases
including implicit registers/shared SP, all initial NCZV patterns, every
ignored field width1..32/FE, and all four opcode positions. The eight
coupled programs check the branch, exact following coordinate interval,
full state, and independently bounded logical/raw instruction traffic.

The unchanged70acbfee2 CPU fails timing/bus checks in **all5,116** with
zero architectural/memory failures. The committed
[historical baseline](../ver/timing/baseline-coordinate-70acbfee.json)
contains73 representatives, both harness captures and22 verified old
HDL/YAML hashes per capture. It is never an oracle or allowlist.

The normal inventory has **45,186 programs per matrix**, three matrices,
two mid-DIV pauses and six66-case phase unions: **135,956 exact timing
programs** under the documented expectations. It covers96/133 forms;
37 remain missing. The independent models/checker have64 checks before
the subsequent project source-policy audit. Two new RTL mutations add an
unwanted CPW state or shorten CVXYL; they must fail timing with correct
registers/ST. This brings mutation controls/rejections to36/43, including
three separate event-contract rejections. The response-retention bench's
three controls/one mutation remain separate from the exact timing count.

Cached coordinate programs require zero external traffic. CD requires
one following-opcode read with IAQ high; each physical transfer has its
own waits. Logical allocation/duration/order, raw dispatch/readiness/ACK
and CEN hold/alignment checks stay active. Outstanding-response CEN,
CPU HOLD/IRQ/resumption, cold coordinate/target misses, peripheral/hidden-
write dependencies and broader graphics/cache rules remain open.

```sh
python3 modules/jttms10/ver/timing/run.py --simulator verilator --case coordinate_
python3 modules/jttms10/ver/timing/run.py --case coordinate_ --wait-states 1 --pause-clocks 6
python3 modules/jttms10/ver/timing/test_checker.py
python3 modules/jttms10/ver/timing/mutations.py
```

The matched map estimates3451ALMs/4931ALUTs/1653registers/538624RAMbits/
5DSPs/0MLAB, compared with3377/4793/1653/538624/5/0 at the XY stage.
Map estimates do not establish fitted area or timing closure. Final fitted
area≤3500ALMs, positive STA, NARC simulation and MiSTer gameplay remain
separate acceptance gates, alongside all remaining issue requirements.
