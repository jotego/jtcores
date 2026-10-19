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
Targeted development/clean verification is pending. Remaining ISA/conditions,
known MOVB targets,full clean/remote CI,final fitted area/board STA and NARC/
MiSTer acceptance remain open under #144.
