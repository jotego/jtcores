# XY arithmetic timing (issue #144, partial)

`ver/timing/xy_cases.py` adds **4,156 programs** for ADDXY, SUBXY and CMPXY.
The total inventory is **40,070 cases**, with probes for **94/133 forms**;
39 forms still lack probes. Presence does not establish condition/bus/IRQ
coverage, and unresolved timing sources separately block acceptance.

| Form | Selected hit/CD states | Primary source |
|---|---:|---|
| ADDXY | 1/4 | SPVU001A p.12-41; SPVS002C June1991 p.11 minimum1 |
| SUBXY | 1/4 | SPVU001A p.12-252; SPVS002C p.11 minimum1 |
| CMPXY | 3/6 | SPVU001A summary p.12-12; SPVS002C p.11 minimum3 |

The scanned CMPXY instruction entry on **p.12-56 prints 1/4**, conflicting
with the summary's **3/6** and the newer device data sheet's minimum **3**.
The oracle follows the summary/data sheet, retains all three numeric
alternatives in `source_values`, and labels the choice explicitly. No
published erratum is claimed. Its 1,376 affected probe instances remain
source-acceptance blockers; the total unresolved inventory is 3,620.
The data sheet specifies a minimum, not a paired CD value. Here CD6 is
also printed in the guide summary, rather than inferred solely from a
minimum plus a generic fetch penalty.

The historical [9edda841e baseline](../ver/timing/baseline-xy-9edda841.json)
fails timing in **all 4,156 programs**, with zero register/full-ST failures.
An ADDXY cached/CD example takes 12/40 INCLK versus the published 8/32;
CMPXY takes 10/40 against the selected 24/48. Ninety-four path/bank/SP/
literal representatives and 22 verified old HDL/YAML hashes are retained
as evidence. Baselines are never loaded as timing goldens or allowlists.

## Independent arithmetic and conditions

The model performs two mathematical modulo-65536 operations, rather than
reproducing the RTL adder arrangement. X carry/borrow never propagates to
Y. Full destination and every initialized A0..A3/B0..B3/shared-SP value are
checked, together with full ST and physical bus events.

The unusual flags matter:

- ADDXY: N reports X=0, Z reports Y=0, V is X's sign and C is Y's sign.
- SUBXY: N/Z report equality. V/C report signed source-greater-than-
  destination comparisons for X/Y, including overflow of the difference.
- CMPXY: the destination is preserved; N/Z report equality and V/C are
  the signs of the wrapped X/Y differences. Its entry explicitly states
  that overflow detection is absent. It does not substitute SUBXY's
  signed comparison for the printed result-sign rule.

Thirty-four hand-transcribed TI result/flag examples (16 ADDXY, nine
SUBXY and nine CMPXY) anchor the model and are run in both banks/cache
modes. Boundaries include zero, signed extrema, all ones, cross-sign
subtraction, low-half carry/borrow and every carry-bit position. Additional
programs cover all initial NCZV patterns, IE preservation, aliases, both
register banks and shared SP as source/destination/both. Every width1..32
and FE0/1 is exercised in both ignored field definitions, retaining their
bits in full ST. All four opcode word positions are covered.

## Shared implementation and permanent checks

The existing arithmetic adder gains one spacer bit between its two halves.
Ordinary 32-bit operations propagate carry through it; packed XY addition
absorbs X carry, while packed subtraction independently injects Y's +1.
This remains one shared adder, without a second arithmetic unit or DSP.
Both halves finish together, replacing the old serial X/Y microsteps.
The final microinstruction writes ADDXY/SUBXY directly from the result
and updates their flags; CMPXY updates only flags. The scheduler enforces
CMPXY's selected three-state intrinsic budget.

The ALU unit bench retains its ordinary boundaries and adds 512 independent
packed-half add/sub comparisons. Checker/model tests compare the literal
vectors, carry/borrow isolation, cross-sign SUBXY/CMPXY flag distinction
and the unresolved-source gate. Two RTL mutations give ADDXY an extra
state or shorten CMPXY to one; both must fail timing with correct state.

Twelve new phase probes add both banks/cache modes for every form to the
normal short-CEN union. The runner contains three 40,070-case matrices,
two mid-DIV pauses and six 58-case phase unions: **120,560 exact timing
programs**, under the documented expectations/policies. The separate
response-retention event bench is not included in that count.

Cached XY programs require no external traffic; CD requires the following
opcode read with IAQ high. Independent checks retain logical allocation,
state grid, two-state duration, per-transfer waits and actual raw-target
readiness/ACK. CPU CEN is a wrapper extension: an early pause adds exactly
its length on a hit, with the documented bus alignment for CD. Original
LAD/control electrical pins, outstanding-response pauses and interrupt
acceptance are not established by these scalar probes.

```sh
python3 modules/jttms10/ver/timing/run.py --simulator verilator --case xy_
python3 modules/jttms10/ver/timing/run.py --case xy_ --wait-states 1 --pause-clocks 7
python3 modules/jttms10/ver/timing/test_checker.py
python3 modules/jttms10/ver/timing/mutations.py
```

CPW/CVXYL and the other graphics, memory-to-memory, stack/call/list and
remaining ISA/condition timing rules remain required. Broader cache,
HOLD/IRQ/resumption, peripheral/hidden-write dependencies and source
resolution also remain open. Final fitted area ≤3,500 ALMs, positive STA,
NARC simulation and MiSTer gameplay are separate acceptance gates.
