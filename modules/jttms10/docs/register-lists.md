# Register-list transfers

TI's 1988 *TMS34010 User's Guide*, printed pages 12-109–110 (MMFM) and
12-111–112 (MMTM), defines these two-word instructions. MMTM is `0980` plus
file/pointer; MMFM is `09A0` plus file/pointer. The second word is a register
mask. Both use the selected A or B file and force 32-bit transfers, ignoring
FS/FE. Register 15 remains the shared SP.

MMTM consumes mask bit 15 as R0, then scans toward bit 0/R15. Each selected
register predecrements Rp by 32 and stores its 32-bit contents LSW first. MMFM
consumes bit 15 as R15, then scans toward bit 0/R0; each selected register
loads from Rp and increments Rp by 32. Thus the masks for saving and restoring
the same register set differ. TI explicitly calls inclusion of Rp in the list
unpredictable; tests exclude that case.

The microcode retains a 16-bit shifting mask, a four-bit register index, and
a five-bit scan count. The existing synchronous source-read port selects one
list register at a time; the second port retains Rp. Every selected transfer
uses the existing shared ALU and field bus. A named `MULTINEXT` microcode
entry handles skipped mask bits without hard-coded microstep offsets.

MMFM preserves all status bits. MMTM changes only N to the complement of the
original pointer's sign. TI's prose describes this as the sign of `0 - Rp`,
but its explicit exceptions require N=1 at Rp=0 and N=0 at Rp=`80000000`;
those cases are tested directly.

An empty list selects no transfers, so Rp and memory remain unchanged.
The primary suite checks the exact reset/instruction-fetch request count to
prove that no data request occurs. The pinned old CPU instead performs one
predecrement/write for MMTM and one read/postincrement for MMFM, with an
unintended A0 overwrite in the tested empty-list sequence. That case has
separate `reference_checks` and a `reference_divergence` explanation; it is
not reported as an architectural match. The per-register TI execution rules
do not exclude mask zero, and MAME's conditional MMTM loop independently
leaves the pointer unchanged for that mask.

Four durable programs cover empty lists and N exceptions, asymmetric sparse
A-file save/restore masks, B-file restore order, B-file save through shared
SP as the pointer, bit-unaligned accesses, neighboring bits, field-size
independence, and exact data-request counts. Instruction timing is still
unverified.
