# PIXT register-to-linear replace timing

This milestone validates `PIXT Rs,*Rd` with **PPOP=replace,PMASK=0,T=0**.
TI SPVU001A pp.12-213/214 specifies two visible CPU states,three hidden
states for1/2/4/8-bit pixels and one hidden state for16-bit pixels. Cache
-disabled counts are8 and6 respectively. Legal linear pixels are aligned
to their1/2/4/8/16-bit size. The complete ST and all registers are preserved.
Register sources supply their low PSIZE bits,including the old pointer value
when Rs=Rd. FS/FE,window modes and array corner flags do not affect this form.

[Boolean PPOP1..15](pixel-boolean-timing.md) now has a separate timed subset.
Arithmetic PPOP,nonzero PMASK,transparency,SRT and the remaining
interference/cache/interrupt conditions still require timing implementation
and validation. They retain the existing functional graphics path. Probe
presence for this form does not validate those conditions; this is not full
PIXT or ISA timing signoff.

The selected path reuses the scalar posted-field machinery and shared ALU/
field engine. At dispatch,the existing family110 selects a one-step scalar
entry when replace/zero-mask/transparency-off applies. Its opcode mapping
is unchanged. One address state precedes the first physical transfer. The
CPU completes after two states while captured memory writes continue; cache
hits can run alongside them. A partial word needs an ordered read/write
pair; a full16-bit pixel needs one write. No arithmetic unit,register bank
or DSP is added. The guide gives totals and hidden work; the first-slot
allocation is the implementation's explicit transport contract.

The independent model walks individual bits and preserves every bit outside
the pixel. Let T be the physical transfer count (2 for a partial pixel,1 for
16-bit) and W the waits per transfer. Hidden time is2*T-1 states. Every
physical transfer charges its own waits. Cached CPU time stays two states;
CD also waits for the field and fetches the next opcode. After K cached
NOPs,a real following field load begins at `max(2+K,1+T*(2+W))` states.
The observer checks its exact completion,registers/flags,memory and ordered
reads. Correct final memory or a padded retire pulse cannot replace these
checks of overlapping CPU/bus work.

The2,824 fixtures cover all legal pixel lanes,both banks,all16 source and
pointer identities/shared SP,aliases,source patterns,all flags/IE,all ignored
FS1..32/FE settings in both fields,window/corner controls,high addresses,
opcode phases and70 real following loads with K0/1/2/3/7/10/20. Programs
initialize all31 GPRs distinctly through real instructions and compare all
of them,full ST and drained sparse memory. Cache/sparse-size guards enforce
the warm-loop measurement assumptions. All six unmasked replace numeric
examples on p.12-214 independently anchor the bit model.

Early CEN pauses1..7 have exact CPU/bus alignment requirements. A separate
posted observer in `ver/load_pause/posted.sv` checks a real memory response
during96 disabled CPU clocks,with CPU/sequencer/work/GPR holds and correct
memory/order/resume. A posted field acknowledges CPU acceptance immediately;
this event intentionally observes the later physical response. The original
normal timing bench is unchanged. Earlier probes paused before acceptance
or incorrectly required a logical ACK during the pause; they are excluded
from acceptance. Event coverage remains distinct from exact TI base counts.

Reproduce the targeted profiles from the repository root:

```sh
python3 modules/jttms10/ver/timing/run.py --case pixel_store_ --simulator verilator
python3 modules/jttms10/ver/timing/run.py --case pixel_store_ --simulator verilator --wait-states 1
python3 modules/jttms10/ver/timing/run.py --case pixel_store_ --simulator verilator --wait-states 1 --pause-clocks 7
```

All three profiles pass2,824 cases each,8,472 programs total. All165 models,
180 architecture programs,strict lint and the original38-request MSW-first
assertion pass. All522 representative Icarus stress case objects match
Verilator except batch-local case ID,with51 source/seven generated hashes
exact. This is not all2,824 Icarus cases. All102 short Icarus phase programs
and two fresh-process comparisons pass. Three new actual timing mutants
and three affected linear-read controls/rejections pass with correct full
architecture/following state/memory. Response events pass29 controls/one
mutant,including four posted-memory response probes. All103,786 preceding
fixture/program/golden contracts are unchanged. All2,824 historical probes
on unchangedeaa864ff2 fail timing/bus with correct state/memory;130
representatives and22 verified old HDL/YAML hashes are committed.

Matched NARC GSP quartus_map estimates3,817 ALMs,5,517 ALUTs,1,722 registers,
538,624 RAM bits,five DSPs and zero MLAB bits. A detached clean checkout of187edd8df repeats all three2,824-case profiles,
165 models and29 response controls/one mutant. All8,472 case objects,
51 timing-source/seven generated hashes and response objects match development
exactly. Clean scope is targeted,not a full standard runner. All36 synthesis
snapshot hashes/29 committed inputs,QSF path normalization,SDC and the same49
warning classifications verify. Original live-capture source_commit:null and
repo_commiteaa864ff2 are retained; content matches187edd8df. This is +19 ALMs/
+13 ALUTs versus the XY-read map,unchanged registers/RAM/DSPs; the combined
synthesis change does not isolate one cause. No current fitted-area or
board-STA acceptance is claimed.

A fresh120-form standard runner is running frozen187edd8df,alongside older
118/119 frozen runs. No completed120 invocation is claimed. Latest accepted
complete invocation is corrected117-form lists/289,568 exact programs. Inventory is106,610 cases,
120/133 forms,13 missing plus the condition exclusions above. The same
12,625 project choices/448 unresolved MOVB instances,including45 agreed
targets,remain without waivers. Full clean/CI,remaining ISA/conditions and
final fitted area/board STA/NARC simulation/MiSTer requirements remain open.
