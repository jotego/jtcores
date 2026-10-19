# PIXT XY memory to register timing

SPVU001A pp.12-222/223 specifies `PIXT *Rs.XY,Rd` at **6/9 machine
states**, for a cache hit/cache disabled. It applies the source pitch
CONVSP, PSIZE and shared OFFSET(B4), then transfers a plane-masked,
right-justified, zero-extended pixel into Rd. Rs/Rd use one register file;
shared SP and aliases with implied registers are tested. Window checking,
pixel processing and transparency are ignored. The linear-read rules for
legal aligned1/2/4/8/16-bit pixels and NCZ/V project behavior carry over;
see [pixel-read-timing.md](pixel-read-timing.md).

The conversion follows pp.4-12/13 and6-15: multiply signed16-bit Y by
`2**(31-(CONVSP&31))`, OR its32-bit result with unsigned X times PSIZE,
then add OFFSET with32-bit wrap. The oracle uses independent mathematical
products and the physical bit-plane model. CONVDP is deliberately different
from CONVSP in every fixture, so accidentally using destination pitch is
observable. Tests use nonnegative X; negative X is excluded. Page4-14's
screen-row extent discussion is retained: overlap/extreme-coordinate probes
check the explicit arithmetic formula and resulting transport address, not
a claim that those coordinates identify an in-range screen pixel.

All ten numeric examples on p.12-223 address20500h and agree with memory
CF3Fh and the stated source/size/mask results. The example setup labels B3
as DPTCH and its note names A1 as the source, while the instruction syntax
uses A0 and the implied-operands table specifies B1/SPTCH and CONVSP. The
fixtures follow the opcode, explicit source-pitch rule and agreeing numeric
addresses. These label inconsistencies are not silently treated as TI errata.

The implementation reuses CVXYL's two products through the existing scalar
DSP, OFFSET storage in B, OR stage and shared ALU addition. It stores the
computed EA, then shares the scalar pixel-read path. No multiplier, DSP,
register bank or arithmetic unit is added. The selected transport allocation
is three conversion states, a two-state data read and one completion state.
The guide states the total, not an internal first-read microinstruction edge;
the bus checker additionally enforces the chosen state allocation, IAQ,
addresses/data, logical durations, raw readiness and ordering. Original
electrical pin timing is outside this interface contract.

One data read charges its own waits; CD also fetches the next opcode.
A cold next subsegment adds nine states and four ordered IAQ-high reads.
Early CEN pauses keep exact pause/alignment accounting. Separate response
probes pause96 clocks after issue, check CPU/sequencer/work/GPR holds,
capture during the pause and verify correct resume. Their bounded event
contract is separate from the exact unpaused TI instruction counts.

The3,917 fixtures cover all legal sizes/lanes and physical plane-mask bits,
all32 pitch encodings, signed Y boundaries, ignored field/PPOP/window/
transparency settings, flags/IE, high/wrapped offsets, opcode phases,
A/B/shared-SP/implied-OFFSET aliases, all printed numeric examples, cold
next fills and20 immediate real following loads. All31 initialized GPRs,
full ST and read-only sparse memory remain checked. Compact initialization
and guards preserve the four-segment warm-cache and sparse-memory claims.

Reproduce the exact profiles from the repository root:

```sh
python3 modules/jttms10/ver/timing/run.py --case pixel_xy_read_ --simulator verilator
python3 modules/jttms10/ver/timing/run.py --case pixel_xy_read_ --simulator verilator --wait-states 1
python3 modules/jttms10/ver/timing/run.py --case pixel_xy_read_ --simulator verilator --wait-states 1 --pause-clocks 7
```

All three profiles pass3,917 programs each,11,751 total. All158 models,
180 architectural programs,strict lint,the original38-request MSW-first
assertion and response25/1 pass. Two new actual timing mutants and the
three affected linear-read controls/rejections pass, retaining correct
full architecture/following state/memory. The99,869 preceding fixture/
program/golden contracts are unchanged. All3,917 historical programs on
unchanged2d260be9f fail timing/bus checks with correct state/memory;85
representatives and22 verified old HDL/YAML hashes are committed. Typical
cached XY read changes454 to48 INCLK. Historical captures are not goldens
or allowlists.

Short-phase, cross-simulator, clean-checkout and current synthesis validation
remain in progress; no completed119-form normal runner is claimed. The
inventory becomes103,786 cases and119/133 forms,14 missing. The12,625
project choices and448 unresolved MOVB instances including45 agreed targets
remain, without waivers. Pixel stores/copies, LINE/FILL/PIXBLT, broader
cache/peripheral/HOLD/IRQ/resumption and full clean/CI/final fitted area,
board STA/NARC simulation/MiSTer acceptance remain open. Probe presence
is not full timing compliance.
