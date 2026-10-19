# PIXT register-to-linear Boolean timing

This subset covers PPOP1..15, PMASK=0, T=0 and legal aligned1/2/4/8/16-bit
pixels for `PIXT Rs,*Rd`. TI SPVU001A Table7-1 p.7-15 defines the Boolean
operations; pp.12-213/214 specifies four visible CPU states and preserves
all status/register bits. Hidden writes take three states for partial-word
pixels and one for16-bit pixels; CD counts are10 and8 respectively. PPOP0
replace has its separately tested two-state path. Arithmetic, plane masks,
transparency, SRT, bus interference/HOLD/IRQ/resumption and broader cache
conditions remain unvalidated. Probe presence does not prove those cases.

The native microprogram reads the destination, processes it through the
existing pixel truth-table network and posts the result. Existing MD/EA,
field engine and memory-copy handoff machinery are reused. No ALU, register
bank or DSP is added. Dispatch retains the original opcode family110 and
selects scalar entry150 only for this subset. The microprogram family owns
the native mode through retirement. It consumes the destination read before
posting and gives the field request a separating clock, so an old read ACK
cannot acknowledge a new write. Accepted-read slot metadata survives that
handoff, avoiding an extra bus state.

The independent oracle spells out all16 TI Boolean expressions, separately
from the RTL truth encoding. It preserves bits outside the target pixel and
checks literal XOR/AND examples on p.12-214. Every probe compares all31 GPRs,
full ST and sparse memory. The explicit transport contract allocates the
initial read at state1 and the first posted transfer at state3. Every
physical transfer takes two states plus W waits. On a hit the read charges
its waits to the CPU's four states; posted trailing waits remain hidden.
CD adds hidden work, the next opcode fetch and every physical wait. With
T posted transfers, an actual following load after K NOPs starts at
`max(4+W+K,3+W+T*(2+W))` states. All request/ACK/IAQ/address/data/order checks
remain active. First-slot allocation is a project transport contract; TI
supplies the instruction/hidden totals.

The prefill program deliberately skips PIXT, runs the following tail, restores
any following-load destination and status, then branches to a NOP immediately
before PIXT. JA operands or the tail warm the opcode's four-word subsegment.
Tag-capacity guards cover the route. The measured operation executes for the
first time against the original memory image. This avoids treating XOR,
complement or another non-idempotent operation as an idempotent warm-up.
No register or cache state is forced from the testbench.

The6,264 fixtures cover all15 non-replace operations and legal pixel lanes,
source/destination bit patterns, both banks/shared SP, all16 source/pointer
identities and aliases, ignored FS/FE/window/corner settings, flags/IE,
high addresses, opcode phases,210 real following loads and four literal
XOR/AND hit/CD examples. Source identity and other condition axes use a
rotating PPOP representative; they are not all cross-products. All106,610
preceding fixture/program/golden contracts remain unchanged. Historical
154 representative old-core probes on187edd8df fail timing/bus with correct
architecture and memory, with all22 old HDL/YAML hashes verified. They are
retained as evidence, never oracle input or an expected-failure allowlist.

The response event bench checks a real destination-read response during96
CPU-disabled clocks. CPU/sequencer/work/register holds, retained data, ordered
read/post traffic and final memory remain asserted. Post traffic resumes at
the first available bus boundary after enable returns; read waits can overlap
this CPU-only pause. This contract is distinct from TI's unpaused counts.
The normal suite separately checks exact base, wait-only and early-pause
counts. Three actual timing mutants lengthen the CPU tail, delay the first
read or lose the inherited write slot; correct architecture cannot waive the
failure. The separating-clock prototype failure and the later one-state slot
failure are excluded, not accepted results.

Reproduce from the repository root:

```sh
python3 modules/jttms10/ver/timing/run.py --case pixel_boolean_ --simulator verilator
python3 modules/jttms10/ver/timing/run.py --case pixel_boolean_ --simulator verilator --wait-states 1
python3 modules/jttms10/ver/timing/run.py --case pixel_boolean_ --simulator verilator --wait-states 1 --pause-clocks 7
python3 modules/jttms10/ver/load_pause/check.py --case pixel_boolean_
python3 modules/jttms10/ver/timing/mutations.py
```

The new cases, mutation controls, response cases and word-phase probes are
part of the standard repository runner. Full ISA/condition acceptance, full
clean/remote CI, final fitted area/board STA and NARC/MiSTer checks remain
open under#144. The complete CPU still uses five DSP blocks.

Verified targeted results: all18,792 programs in three profiles repeat exactly
in a detached clean checkout,alongside173 models and33/1 response events.
Every case object,52 source/seven generated hashes and response result match.
All586 representative Icarus stress cases match Verilator except batch-local
ID,with102 short phase programs and two fresh processes. The first complete
586-case capture had wrapper143/no final child status and is excluded from
completed invocations; its detached rerun returns0 and reproduces every case
object. Three new/eight affected timing mutation controls/rejections,
180 architecture programs,strict lint and the original38-request MSW-first
assertion pass. All32,700 checks of preceding pixel paths also pass.
Matched map is3,868 ALMs,5,585 ALUTs,1,722 registers and five DSPs;36 snapshot/
29 committed physical inputs verify. No new fit/STA is claimed. Clean scope
remains targeted; the full normal runner is still running frozen5a74e596e.
