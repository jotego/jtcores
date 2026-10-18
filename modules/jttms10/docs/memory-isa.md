# Memory move ISA plan

The bit-addressed MOVE matrix has 18 forms; MOVB has nine. The primary source
is the 1988 TI *TMS34010 User's Guide* (SPVU001A), summary pp. 12-14–15 and
operand-format tables pp. 12-21–22. The mature decoder in
`modules/tms34010/rtl/core/tms34010_decode.sv` supplies cross-checked masks.
All addresses below are **bit addresses**. A 16-bit extension advances PC by
16 bits. `R=ir[4]` selects A/B, `S=ir[8:5]`, and `D=ir[3:0]`. Except for
register-to-register MOVE, both encoded registers use file R. `F=ir[9]`
selects FS0/FE0 or FS1/FE1; encoded FS=0 means **32 bits**. A memory store
uses the low FS bits of its source register. A memory load places the field in
the low bits of Rd, extends it according to FE, sets N/Z from the extended
result, clears V, and leaves C unchanged. Memory-to-memory forms copy the raw
FS bits and leave all flags unchanged. MOVB forces size 8, always sign-extends
loads, and has no auto-increment/decrement forms (guide pp. 12-21–22).

| Form | `(ir & mask) == value` | Extra words | Guide |
| --- | --- | ---: | --- |
| MOVE Rs,Rd | `FC00:4C00` | 0 | 12-126 |
| MOVE Rs,*Rd / *Rs,Rd / *Rs,*Rd | `FC00:8000 / 8400 / 8800` | 0 | 12-127 / 135 / 137 |
| MOVE Rs,*Rd+ / *Rs+,Rd / *Rs+,*Rd+ | `FC00:9000 / 9400 / 9800` | 0 | 12-128–129 / 139 / 141–142 |
| MOVE Rs,-*Rd / -*Rs,Rd / -*Rs,-*Rd | `FC00:A000 / A400 / A800` | 0 | 12-130 / 143 / 145–146 |
| MOVE Rs,*Rd(off) / *Rs(off),Rd / *Rs(SOff),*Rd(DOff) | `FC00:B000 / B400 / B800` | 1 / 1 / 2 | 12-132 / 147 / 151–152 |
| MOVE *Rs(off),*Rd+ / @SAddr,*Rd+ | `FC00:D000 / FDE0:D400` | 1 / 2 | 12-149 / 155 |
| MOVE Rs,@DAddr / @SAddr,Rd | `FDE0:0580 / 05A0` | 2 | 12-134 / 153 |
| MOVE @SAddr,@DAddr | `FDFF:05C0` | 4 | 12-157–158 |
| MOVB Rs,*Rd / *Rs,Rd / *Rs,*Rd | `FE00:8C00 / 8E00 / 9C00` | 0 | 12-115 / 118 / 119 |
| MOVB Rs,*Rd(off) / *Rs(off),Rd / *Rs(SOff),*Rd(DOff) | `FE00:AC00 / AE00 / BC00` | 1 / 1 / 2 | 12-116 / 120 / 121–122 |
| MOVB Rs,@DAddr / @SAddr,Rd / @SAddr,@DAddr | `FFE0:05E0 / 07E0 / FFFF:0340` | 2 / 2 / 4 | 12-117 / 123 / 124–125 |
| MMTM Rp,list / MMFM Rp,list | `FFE0:0980 / 09A0` | 1 mask | 12-111–112 / 109–110 |

The `mask:value` notation is hexadecimal. More specific fixed-word and
absolute matches must take priority over broad family matches. MOVE Rs,Rd
uses the full 32-bit register, independent of F. Its `M=ir[9]` is the sole
cross-file MOVE control: with M=0 both registers use R; with M=1 the source
uses R and the destination uses the other file (p. 12-126).

Address micro-operations can share four templates: register→field, field→
register, field→field, and register→register. For indirect forms, store uses
Rs data and Rd pointer; load uses Rs pointer and Rd destination; field→field
uses both pointers. Plain forms do not write pointers. Postincrement accesses
the old pointer, then adds FS; predecrement subtracts FS before access. Signed
offsets are **bit** offsets, independently sign-extended from their 16-bit
words; offset forms otherwise leave their base pointers unchanged. The
`*Rs(off),*Rd+` and `@SAddr,*Rd+` forms update only Rd. Every absolute
address consists of low 16 bits then high 16 bits. Two-offset forms fetch
source offset first, destination offset second; two-absolute forms fetch
source low/high before destination low/high. Keep the source field in a
temporary across the second architectural field transaction. No FE extension
is applied to a memory-to-memory temporary.

Pointer alias order needs explicit microcode decisions. For load postincrement
or predecrement with Rs=Rd, the loaded data wins over the pointer update
(guide pp. 12-139, 12-143). For `MOVE *Rs+,*Rd+` with Rs=Rd, the source
field is read at the original pointer and the destination field is written at
the incremented pointer (p. 12-141). Both listed pointer updates execute, so
the final alias value increments twice. This interpretation is independently
corroborated by MAME's `MOVE_NI_NI` at revision
`e5a5a102889d6c62f12e39a4db3e950e4f5d6822`; its source update precedes the
write, and its destination update follows the write even when both register
pointers alias. The old RTL suppresses that second update.
For `MOVE -*Rs,-*Rd` with Rs=Rd, p. 12-145 explicitly specifies a final
register value decremented by **twice** the field size. The old CPU incorrectly
suppresses the second writeback, although its destination address is doubly
decremented. The new microcode writes back both decrements. Its dedicated
YAML cases record the specified results and the old CPU's different results
separately; passing reference comparison must not hide these discrepancies.
A postincrement store samples its data before pointer writeback. A
predecrement store updates the pointer before sampling its source (p.12-130
execution order, corroborated by MAME `MOVE_R_DN`): when Rs=Rd, it stores the
decremented pointer value. The old CPU incorrectly stores the original value;
a separate primary/reference checkpoint pair records that difference too.
A15/B15 share SP physically, so alias comparisons must use physical register
identity as well as the encoded file bit.

MMTM and MMFM use a 16-bit residual-list register and a 4-bit scan
index, looping over one 32-bit field transaction per selected register. For
MMTM, mask bit **15-N** names register N: scan the highest set mask bit
first (lowest register number), decrement Rp by 32 before each write, and
leave Rp at the final written address. Only N changes, to `~original_Rp[31]`
(the specified zero and `0x80000000` exceptions are included by that rule).
For MMFM, mask bit **N** names register N: scan the highest set bit first
(highest register number), read at Rp, then increment Rp by 32 even after
the last read. Flags do not change. The guide says including Rp in its own
list is unpredictable (pp. 12-109, 12-111); do not design tests that require
a deterministic result for that case. The two list encodings are asymmetric,
as confirmed by the TI assembler examples in the old core's coverage ledger.
See [register-lists.md](register-lists.md) for the implemented microcode,
empty-list behavior, tests, and the fourth documented reference difference.

## Field adapter integration audit

`jttms10_field` meets the basic §4.1 regular-field shape: ascending aligned
16-bit word requests, one to three words, direct full-word writes, and a
read/merge/write pair for each partial word. It expects one pulse of
`word_ack` per accepted word and permits `word_req` to remain high while the
next word's payload changes after acknowledgement. Its architectural `ack`
is held until `req` falls, so a caller using a one-clock completion pulse
needs a request/response bridge that lowers `req` before the next command.
Normalize an architectural FS encoding of zero to size **32** before this
adapter; raw size zero returns without a bus cycle.

`word_lock` reserves each partial-word read→write pair. The new arbiter's
`word_restart` cancels an unaccepted partial write when HOLD is accepted
after its read; the adapter then rereads before merging. The integrated
field/fabric bench checks this with an external owner changing unrelated
memory bits during HOLD. Graphics microcode and `jttms10_pixel` compute plane
masks, transparency and pixel operations before issuing tagged field requests.
The adapter itself handles field alignment and partial-word preservation.

The field adapter now uses a shared DSP alignment product with fixed
capture latency instead of serial shifts. The [indirect-load timing report](load-timing.md)
records MOVE/MOVB read timings, per-word waits, sign-extension distinctions,
ordered uncached data traffic and the first-cycle allocation contract.
Other addressing modes, writes/hidden writes and graphics still require
independent timing tests. The unit bench retains field values, whole-memory
write-preservation, stalls and HOLD restart checks; functional bus/peripheral
benches are separate from timing signoff. Current fitted area/STA and NARC
simulation/MiSTer validation remain final #144 gates.
