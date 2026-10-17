# PIXT and DRAV instruction contract

The 1988 TI *TMS34010 User's Guide* defines DRAV on printed pp. 12-67–69,
PIXT on pp. 12-213–225, and the common pixel pipeline in §§7.3 and 7.7
(pp. 7-10–16). The bit-addressed opcodes all use source bits 8:5,
register-file bit 4 (`0=A`, `1=B`), and destination bits 3:0.

| Instruction | Base opcode | Source and destination |
| --- | --- | --- |
| PIXT Rs,*Rd.XY | `F000` | Register pixel to XY memory |
| PIXT *Rs.XY,Rd | `F200` | XY memory pixel to register |
| PIXT *Rs.XY,*Rd.XY | `F400` | XY memory to XY memory |
| DRAV Rs,Rd | `F600` | Draw B9 COLOR1 at Rd.XY, then Rd += Rs by signed XY halves |
| PIXT Rs,*Rd | `F800` | Register pixel to linear memory |
| PIXT *Rs,Rd | `FA00` | Linear memory pixel to register |
| PIXT *Rs,*Rd | `FC00` | Linear memory to linear memory |

PSIZE is 1, 2, 4, 8, or 16 bits. Pixel addresses are multiples of PSIZE and
pixels do not cross 16-bit physical word boundaries (guide §4.2); byte and
subbyte pixels can still occupy higher lanes of a word. Read forms right
justify the extracted pixel, clear its upper register bits, and apply PMASK
to memory-source data. PPOP and transparency do not apply to those reads.
Only V is architecturally defined after a read; N/C/Z are unspecified.

Store and memory-to-memory forms select PPOP from CONTROL[14:10], transparency
from CONTROL[5], and window mode from CONTROL[7:6]. PPOP codes 0–15 are
Boolean; 16–21 are unsigned arithmetic for PSIZE 4, 8, or 16. Codes 22–31,
and arithmetic for PSIZE 1 or 2, are reserved. For each destination pixel,
memory-source and memory-destination data are masked by their respective
PMASK lanes before PPOP; register-source low PSIZE bits bypass source PMASK.
Destination PMASK is then applied to the PPOP result. A zero *masked result*
suppresses the write when transparency is enabled. Protected destination bits
and every neighboring pixel remain unchanged. See [pixel.md](pixel.md) for
the complete PPOP truth table and arithmetic reference equations.

All six PIXT forms and DRAV run in the graphics control ROM. Its YAML words
prime register reads and sequence XY conversion, window decisions, source
and destination memory cycles, pixel processing and flag/writeback masks
through the shared ALU and field adapter.

XY source conversion uses CONVSP, XY destination conversion uses CONVDP;
both add B4 OFFSET. The signed Y and positive X halves are converted as in
CVXYL. Linear PIXT ignores CONTROL.W. XY store and XY-to-XY PIXT use B5/B6
inclusive WSTART/WEND and the same window meanings as DRAV:

| W | In-window result | Out-of-window result |
| --- | --- | --- |
| 0 | Draw; V unchanged | Draw; V unchanged |
| 1 | No draw; V=0, set WVP | No draw; V=1 |
| 2 | Draw; V=0 | No draw; V=1, set WVP |
| 3 | Draw; V=0 | No draw; V=1 |

For DRAV, Rd advances by Rs as two independent 16-bit additions even when
the window inhibits the draw. The pixel source is B9 COLOR1 selected for the
destination lane. TI calls negative WSTART/WEND coordinates unpredictable;
tests use nonnegative window corners. The scalar programs exercise memory
preservation, register aliases, control options, and V/WVP separately from
the exhaustive combinational helper test in `ver/pixel/test.sv`.

The reproducible scalar PPOP cross-check creates two independent operand
programs for every defined code 0–21 with seed 34010. Its Python equations
come from the TI truth table and arithmetic definitions, while the testbench
compares the resulting whole memory word to catch neighboring-pixel damage:

```sh
python3 modules/jttms10/ver/pixel/programs.py --seed 34010 --samples 2 \
  --out /tmp/jttms10-pixel-programs.yaml
python3 modules/jttms10/ver/run.py --vectors /tmp/jttms10-pixel-programs.yaml
python3 modules/jttms10/ver/reference.py --vectors /tmp/jttms10-pixel-programs.yaml
```
