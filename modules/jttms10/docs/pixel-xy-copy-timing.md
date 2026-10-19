# XY-to-XY pixel-copy replace timing

This subset covers `PIXT *Rs.XY,*Rd.XY` with PPOP=replace, PMASK=0, T=0,
W=0 and aligned1/2/4/8/16-bit pixels. TI SPVU001A pp.12-224..226 gives
seven CPU states plus three hidden states for1/2/4/8-bit pixels or one for16,
and13/11 states with CD. W0 preserves every ST bit. Both coordinate registers
remain unchanged. CONVSP and CONVDP convert the source and destination
independently using the same OFFSET. The source is read before modifying the
destination, including shared words and register aliases.

The native scalar entry154, selected from original opcode family108, reuses
the existing CVXYL DSP products, A/B/MD/TMP/EA, shared ALU and field engine.
The first conversion leaves source EA; the second leaves destination A.
The existing RETI phase bit selects the second coordinate/pitch. The source
read captures its pixel in MD, then selects the saved destination EA and
posts the write. No DSP, register bank or arithmetic unit is added. Other
processing/window/mask/transparency/SRT paths retain the graphics engine;
their timing remains unvalidated.

The independent oracle uses TI's coordinate formula and bit extraction/
insertion. Its project transport contract allocates source read at state3
and destination post at state6, after one source transfer and CPU processing.
Each external transfer takes2+W states. Partial pixels post an ordered
read/modify/write pair;16-bit pixels post one write. Cached CPU work ends at
7+source-waits, independently of trailing posted transfers. CD waits for the
post and following opcode. Following loads after K NOPs start at the later
of CPU7+K+source-waits and destination-post completion. Logical/raw address,
data,IAQ,request/ACK,order and duration checks remain active. TI supplies
CPU/hidden totals; the first-slot allocation is a project integration contract.

The8,878 fixtures cover every legal source/destination lane pair in separate
and shared words,both banks,all register identities/aliases including implied
OFFSET/SP,all32 source and destination pitch encodings with signed-Y bounds,
flags/IE,ignored fields/corners,source/destination patterns,offset wrap,
opcode phases,70 real following loads and all five literal replace examples
on p.12-226 in both cache modes. CONVSP deliberately differs from CONVDP in
the general cases. Negative X is excluded; extreme/overlapping terms check
the conversion formula/transport rather than an in-range screen meaning.
All31 GPRs,full ST and sparse memory remain checked. Skip-prefill measures
the first copy, preserving original source memory in overlapping cases.
Following loads use a separate linear pointer.

All129,492 preceding fixture/program/golden contracts remain unchanged.
The committed42-probe historical baseline on17c625f0d fails timing/bus with
correct architecture/memory;22 old HDL/YAML hashes verify. This is historical
evidence,never an oracle or expected-failure list. Three actual timing
mutants lengthen post-read CPU work,delay the source slot or delay posting.
An additional post-credit mutation had no effect and is excluded. Four
response controls capture a source response during96 CPU-disabled clocks
and check held CPU state,ordered bus and correct resume. Such bounded CEN
events are separate from exact TI base timing.

The first prototype passed simulations but failed Quartus elaboration because
EA was assigned in two clocked blocks. The corrected path assigns EA only in
its existing datapath block; original prototype captures are excluded from
accepted implementation validation. A separate initial snapshot-generation
attempt failed Go path-alias tests before the local jtframe binary had been
built; it did not reach Quartus. Both failures are retained.

Reproduce from the repository root:

```sh
python3 modules/jttms10/ver/timing/run.py --case pixel_xy_copy_ --simulator verilator
python3 modules/jttms10/ver/timing/run.py --case pixel_xy_copy_ --simulator verilator --wait-states 1
python3 modules/jttms10/ver/timing/run.py --case pixel_xy_copy_ --simulator verilator --wait-states 1 --pause-clocks 7
python3 modules/jttms10/ver/load_pause/check.py --case pixel_xy_copy_
python3 modules/jttms10/ver/timing/mutations.py
```

Fixtures,phase probes,events and mutants are included in the normal runner.

## Corrected-source validation on the second computer

The Verilator5.039 helper refactor in53e352578 exposed an independent Icarus
time-zero mask problem. Its timing captures are intermediate evidence.
Correctionb6bb7e6ed uses a continuous mask decode and passes174,689 existing
pixel-unit cases plus strict lint. On that corrected source, a detached clean
checkout passes all26,634 XY-copy timing programs across the three profiles.
All56 timing-source hashes match the committed source; all seven generated
hashes and complete case objects match the corresponding intermediate
timing captures. A separate corrected-source8,878-case stressed run also
matches the clean stressed run exactly. No assertion or timing target was
relaxed. The clean tail also passes 206 checker models, 49 response controls/
one rejection and 180 architecture programs; the clean supervisor exits zero.
The corrected 632-case Icarus comparison matches every Verilator case object
except simulator-local case IDs. Six W=1 pause profiles (P=1..6) pass 198 cases;
two fresh-process W=1/P=7 cases match the stressed batch. All 56 source/seven
generated hashes verify. Eight affected pixel mutation groups pass 24 positive
controls and reject 24 actual timing mutations with all defined state and
memory correct. Only the intended top-level or word-adapter RTL file differs
in each mutant; generated inputs remain identical.

The corrected-source full standard runner is frozen at4f3b7d9ac, whose
HDL/timing inputs equalb6bb7e6ed. It has passed180 architecture programs,
the existing unit/system benches,206 checker tests,699 bus scenarios,
49 response controls/one rejection and8 EMU controls/one rejection. It is
still running; no completed124-form normal-runner result is claimed.

The matched b6bb7e6ed NARC-boundary synthesis snapshot reports3848 estimated
ALMs,5644 ALUTs,1722 registers,538624 RAM bits,five DSPs and zero MLAB bits,
with158 virtual pins,20ns clock,seed1 and the same Quartus20.1.1 settings.
All36 snapshot hashes,normalized QSF,SDC and49 warning classifications verify.
This is synthesis only. Its original manifest's old_module_commit field
incorrectly resolves the parent checkout because the reference submodule is
uninitialized; that field is not reference-revision evidence. The actual
gitlink is29bcb384ec3d. Metadata fixec3be7b9d records the pin separately and
null for the absent checkout. A new snapshot has identical36 source/generated
hashes,QSF and SDC. Original captures remain unchanged, with the correction
recorded separately.

[Download synthesis sources,reports and verification](http://gitea.jotego.es/attachments/bde299b2-06f1-4274-895e-7fa5325ae8e1)
SHA256:320456cad9de3bed9a9f69e5d9b8308f5b99c1c07f80679fb22bb595483860b2.

Remaining ISA/conditions,known MOVB targets,full clean/remote CI,final fitted
area/board STA and NARC/MiSTer acceptance remain open under #144.
