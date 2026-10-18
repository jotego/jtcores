# Indirect data-load timing (#144)

The independent oracle uses TI's June 1988 SPVU001A, Table 13-1 on printed
p.13-5 and instruction entries pp.12-118 and 12-135/136 in the
[primary guide](https://bitsavers.trailing-edge.com/components/ti/TMS340xx/1988_TI_TMS34010_Users_Guide.pdf).
These probes cover `MOVE *Rs,Rd,F` and `MOVB *Rs,Rd`. Other memory modes
retain separate, unvalidated timing requirements.

Let `W = ceil(((address & 15) + field_size)/16)` be the physical words read.
The published counts are:

| Load | Cache hit | Cache disabled |
|---|---:|---:|
| MOVE, zero extension | `1+2*W` | `4+2*W` |
| MOVE, sign extension with FS < 32 | `2+2*W` | `5+2*W` |
| MOVE, FS=32, either FE | `1+2*W` | `4+2*W` |
| MOVB, always sign extended, FS=8 | `1+2*W` | `4+2*W` |

Table 13-1 note 1 adds a state for MOVE sign extension. The 32-bit example
on p.12-136 marks FE irrelevant; no extension is performed at full width.
MOVB's mandatory sign extension is already included in its own 3/6-state
entry on p.12-118 and is not charged again. The fixtures independently
check these distinctions, including FS=32 with both FE values.

Data reads bypass the instruction cache and have IAQ low (§11.5 p.11-24).
They read aligned ascending words beginning at the field's word base.
Each physical transfer adds its own requested external waits. The warm
instruction-cache case still reads all data externally; CD additionally
reads the following opcode with IAQ high. No hidden write states occur in
these loads (p.13-5). The oracle checks physical word count, address, data,
IAQ, ordering, logical two-state duration and actual raw target readiness.

The logical pipeline allocates the data cycles at the start of the
instruction, followed by the remaining CPU state(s). Registered address,
field, cache and arbiter handoffs occupy the first state's row phase; the
raw response must still meet the Q1 sample. `word_early` qualifies that slot
for these two indirect-load forms. A reset-relative phase counter prevents
an early CEN pause from backdating the data cycle before its resumed state
boundary. The normal runner checks pauses 1..6 separately, in addition to
the full seven-clock profile. These are exposed logical-cycle/transport
contracts; original LAD/control pins and internal silicon microinstructions
are not generated.

The register RAM primes the next source from the fetched opcode before
IR commits. The indirect-load request can then start in its first state.
The field adapter uses one shared 48×17 DSP product with a one-hot factor
for write alignment and final read alignment. It combines the incoming last
word with the buffered words before capturing the aligned result. A combined
read/extend microinstruction and the following ALU writeback finish within
the published CPU work budget. The scheduler preserves that work after the
last read response, so external waits cannot consume the extra sign-extension
state. The existing RMW masks, locks and HOLD reread rules remain checked.

`ver/timing/load_cases.py` adds **4,424 fixtures**: all 32 widths and 16
bit offsets, both fields/FE and cache modes, register aliases, zero/dense/
alternating/mixed data, initial carry preservation, seventeen TI example vectors
(including both FE settings for the printed full-width case) with both carry/cache settings, and full 32-bit transport-address
cases. The mathematical extractor reads individual input bits rather than
copying the DSP alignment algorithm. Each probe compares full ST and A0..A3.
Sparse initial memory words are simulator stimulus; expected results and
counts stay exclusively in Python and never enter the simulator manifest.

The historical [baseline](../ver/timing/baseline-load-22e6010.json) records
all 4,352 original matrix cases on unchanged `22e601063`: every timing check
failed while architectural values passed. A zero-extended aligned 16-bit
load took 43/72 INCLK rather than 24/48. Sixteen representative byte/field,
word-span, FE and cache combinations retain verified RTL/YAML hashes. Later
literal/high-address fixtures are not included in that original capture.
The baseline is evidence, never an oracle or allowlist.

Five new actual RTL mutations must fail with correct final registers/ST:
late first-cycle allocation, consuming sign work during a wait, charging FE
at FS=32, absorbing a sub-state CEN pause, and caching data reads. Checker
unit tests independently anchor the TI bit/flag examples and state counts,
per-word wait addition, uncached data traffic and IAQ/order.

```sh
python3 modules/jttms10/ver/timing/run.py --case load_ --simulator verilator
python3 modules/jttms10/ver/timing/run.py --case load_ --wait-states 1 --pause-clocks 7
python3 modules/jttms10/ver/timing/run.py --case load_move_f0_w32_o15_s1_off --wait-states 1 --pause-clocks 1
```

B-file/shared-SP timing, full CPU HOLD/interrupt/response-during-CEN cases,
other addressing modes, writes/hidden writes, graphics, contention and cache
replacement/prefetch still require their own timing/event audits. Final
fitted area/STA/NARC validation is also pending under #144. Passing these
loads does not establish complete memory or ISA timing compliance.
