# PIXT linear memory to register timing

TI's June1988 TMS34010 User's Guide SPVU001A pp.12-218/219 specifies
`PIXT *Rs,Rd`: a pixel-aligned linear memory source, right justification,
zero extension to32 bits and plane masking. The stated counts are **4/7
machine states**, for a cache hit/cache disabled. Section4.2.1 p.4-6 and
§7.3 restrict PSIZE to1/2/4/8/16 and require pixel alignment. Consequently a
legal pixel fits in one16-bit physical word. The entry's implied-operands
list also prints6; that contradicts the register definition and graphics
chapter. Six-bit pixels and unaligned linear sources are excluded, with
fixture/model guards. They are not silently assigned a timing contract.

Window checking, pixel processing and transparency cannot be applied to
this instruction. Tests vary all22 PPOP values, all window modes and
transparency without changing the selected result/count. FS/FE fields are
also ignored. PMASK suppresses physical planes before right justification;
its bit positions follow the original memory word, not the shifted result.
All11 numeric examples on p.12-219 anchor the independent bit model.

The entry calls N/C/Z undefined. The implementation preserves these bits,
and the regression compares that project behavior in addition to defined
state. V follows whether the masked pixel is nonzero, preserving the
existing graphics path's rule. The prose says "pixel is1"/"pixel is0"
without explaining a multibit nonzero value. Under the owner's simpler
implementation direction, nonzero is retained explicitly; this is not a
verified TI clarification or an official erratum.

The scalar read uses the existing field engine, register file, pixel-mask
network and ALU. It tags only its data field as a pixel transaction. The
chosen first data allocation is one machine state after decode, followed
by a two-state physical read and one state of CPU completion. This is the
implementation's allocation consistent with the published total; the guide
does not expose a scalar PIXT microinstruction edge. The transport checker
still requires correct IAQ/address/data, logical duration, raw readiness,
state grid and ordered transfers. Original electrical bus pins are outside
this interface's contract.

Each physical transfer adds its own external waits. A hit incurs one data
read; CD also fetches the next opcode. A cold next subsegment adds the
nine-state miss penalty and four ordered IAQ-high reads. Data always uses
IAQ low, including a source pointing into the already-cached instruction.
Early CEN pauses1..7 retain alignment and exact pause accounting. A separate
response-retention bench pauses after issue, captures the response during
96 disabled CPU clocks and verifies held state, bus order and resume; that
bounded wrapper event is distinct from exact TI base counts.

Permanent fixtures initialize all31 GPRs distinctly and compare them, full
ST and sparse read-only memory. They cover every legal size/lane, physical
plane masks, A/B/shared-SP identities and aliases, flags/IE, ignored fields,
source values/high addresses, opcode offsets, literal examples, cache modes
and immediate real following A/B field loads. Compact initialization keeps
the measured warm loop within four cache segments; guards enforce that
claim and the sparse-memory limit. Expected values or counts never enter
the simulator manifest.

Reproduce the targeted profiles from the repository root:

```sh
python3 modules/jttms10/ver/timing/run.py --case pixel_read_ --simulator verilator
python3 modules/jttms10/ver/timing/run.py --case pixel_read_ --simulator verilator --wait-states 1
python3 modules/jttms10/ver/timing/run.py --case pixel_read_ --simulator verilator --wait-states 1 --pause-clocks 7
```

The normal runner automatically includes these fixtures, their `_phase_`
subset in all six short-pause profiles, checker/model anchors and actual
RTL mutations. A mutation must fail timing with correct full architectural
and following state/memory. An ineffective initial-budget mutation and an
insensitive one-clock bus-credit profile are excluded from rejection claims.

Only this linear read form is covered here. XY reads, pixel stores/copies,
LINE/FILL/PIXBLT timing, broader cache/peripheral/HOLD/IRQ/resumption
conditions, remaining MOVB targets and final area/STA/NARC/MiSTer acceptance
remain open under issue144. Probe presence does not establish full timing
compliance. Validation results will be recorded after all active profiles
finish; partial or failed prototypes are excluded from acceptance.
