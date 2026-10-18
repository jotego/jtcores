# Architecture and development evidence

## Required end state

Issue 141 requires a new `modules/jttms10` CPU using JTFRAME YAML microcode,
no more than 25% of the old TMS34010 CPU's logic resources, validation against
the old implementation and TI documentation, and a working NARC replacement
in simulation and on MiSTer. A passing subset of instructions or a small
unfinished synthesized CPU does not prove the area requirement.

## Datapath

- A/B registers occupy the lower half of mirrored 64-by-32 synchronous RAMs,
  providing two read ports and one write port. A15 and B15 map to physical
  register 15. Upper words 32–52 are independent whole-word graphics
  scratch; upper-bank addresses do not have the architectural SP alias.
  General registers have no architectural reset value and are not reset;
  this permits block RAM inference.
- One 32-bit ALU supplies arithmetic and logic. A single 33-bit adder is
  shared by addition, subtraction, negation, and absolute value. Shifts are
  one bit per operation; wide variable shifters and parallel dividers are
  excluded from the area-oriented datapath.
- PC is a bit address. Instruction words increment it by 16. Extension words
  are fetched low word first. Branch/jump destinations are word aligned. Relative PC updates select
  one delta before a shared adder; direct PC writes retain priority.
- Status resets to `00000010`. Microcode selects which of N/C/Z/V to update;
  logical operations change Z only, register moves and MOVI update N/Z and
  clear V, and MOVK leaves status unchanged. Subtraction C denotes borrow.

## Sequencer

The scalar ROM has 256 dispatch slots with 16 microsteps each, rather than
one slot per 16-bit opcode. A synchronous 2,048-by-8 dispatch ROM selects the
common family for each IR[15:5] group; sparse exceptions decode the remaining
low bits. Register/file, constant, and condition fields remain in IR. Named
YAML chunks are dispatch slots, and generated `_SEQA` constants define their
addresses.

Graphics instructions run in a second, 4,096-by-64-bit synchronous ROM
generated from `ucode/gfx.yaml` and its `gfx_line.yaml` include. It has 256
named 16-step entries, a 12-bit microaddress and two CALL return levels.
The scalar controller holds its `GFXRUN` word while the graphics sequencer
issues RF addresses, ALU operations, field transactions and pixel/flag
actions. The larger block-ROM image trades memory for simpler instruction
control; a final fitted area result is pending.

`latch_ucode: true` uses JTFRAME's existing synchronous-ROM contract. An
inactive microcycle reads ROM; the following active microcycle executes it.
The controller holds its address and controls through a memory wait. An
acknowledgement received while the external clock enable is low is captured
once and consumed when execution resumes. Requests are disabled between
execution and ROM priming to prevent duplicate transactions.

The generator groups tokens by underscore suffix, so `add_alu` selects an
ALU field, but the standalone PC increment control is `pcinc`. Naming it
`inc_pc` would merge it with the `md_pc`/`reg_pc`/`rel_pc` selector. The
scalar JSR/RET mechanism has two return levels for one-bit shifts,
reset-vector loading, and stack transfers. The graphics ROM has its own
two-level CALL/RET for conversion, window and pixel helpers. Scalar CALL
targets and RETI's saved status use TMP, which scalar helpers preserve.

The initial immediate-arithmetic families use the compiler's `ops.ctl`
substitution: ADDI, SUBI, and CMPI share word/long operand-fetch sequences,
while YAML selects inversion, arithmetic, and writeback. SUBI/CMPI extension
words contain the one's complement of the source-level immediate.

The execution interface describes bit-addressed fields up to 32 bits.
`jttms10_word` connects it to the physical 16-bit word sequencer and latches
IAQ through all words of a transaction. Its smoke test checks request drain,
waiting memory, partial-word locks, and acknowledgement while CPU execution
is disabled. The separate `jttms10_fabric` integrates I/O/video/refresh and
word-cycle arbitration; its field-adapter bench checks waits, cross-register
I/O, and HOLD restart. `jttms10_system` combines these with host, interrupts,
video/refresh, cache and graphics. NARC can select it with `JTNARC_UCODE`
for bring-up. Reserved ranges execute architectural TRAP 30; `fault` stops
encodings outside the implemented families.

## Validation sources

- TI, *TMS34010 User's Guide*, 1988, SPVU001A, instruction pages in chapter
  12 and encoding summary in appendix A. A scanned primary-source copy is
  available from [Bitsavers](https://bitsavers.trailing-edge.com/components/ti/TMS340xx/1988_TI_TMS34010_Users_Guide.pdf).
- The user's `/gdrive/jotego/arcade/components/tms34010.pdf` is a scanned
  60-page device data sheet; use it for electrical/interface checks and the
  User's Guide for detailed instruction semantics.
- The existing `modules/tms34010` implementation is read-only reference
  material, including its instruction, graphics, and cycle-accuracy ledgers.

The YAML programs exercise varying 1–3-clock memory response delays
and check that requests stay stable until acknowledgement. These results
prove only the states asserted by the tests. The complete-instruction `acae6f9c2` HDMI build reaches attract mode and
active gameplay on MiSTer, with movement/fire input and positive setup/hold
slack. That build predates the generic graphics ROM and legacy-RTL removal.
The exact final-source area fit, NARC simulation, audio and hardware
validation remain pending; see [area measurements](../ver/area/README.md).

`ver/reference.py` runs the same architectural checkpoints on the unchanged
existing CPU at `29bcb384ec3dba892ea54db2ee92b38ae395d575`, in its functional
mode. It excludes the external enable-pause test. It checks the asserted register/status/PC values, not all register
state or silicon timing. Separate ALU and field-sequencer benches cover
arithmetic boundaries and every offset 0–15/width 1–32 combination.

## Field-memory instruction sequencing

`ucode/memory.yaml` implements the MOVE/MOVB memory addressing matrix.
Register-to-field stores preserve flags. Postincrement stores sample source
data before the update; predecrement stores sample it afterward, so aliasing
uses the decremented pointer as data. Field-to-register loads extend according
to FS/FE (MOVB always sign extends 8 bits), update N/Z, clear V, and preserve
C. Zero field-size encodings become 32 before memory access. GETST/PUTST
expose both field definitions to programs.

One effective-address register and one scratch address support offset and
absolute memory-to-memory transfers. The raw source field remains in MD
while the destination is selected. These copies preserve status. Pointer
updates are ordinary shared-ALU microsteps: source updates precede destination
reads, so the same-register postincrement copy uses the incremented
destination address. Both pointer updates execute even when the register
aliases. The corresponding predecrement alias also decrements twice, as TI
explicitly requires on p. 12-145. A load whose source pointer
is also its destination writes the loaded data last.

The YAML test memory independently reads/writes individual bits. The same
initial physical words and per-retirement field assertions are also run on
the old CPU's memory model. These checks include neighboring bits, rather
than only testing the just-written field. See [memory-isa.md](memory-isa.md)
for instruction encodings, primary references, alias rules, and MMTM/MMFM
sequencing. The pinned old CPU suppresses the second pointer update in
both same-register memory-copy forms and samples a predecrement store's
source too early when it aliases the pointer. Explicit alternate reference
checks record those known differences; primary new-CPU assertions follow the
specified sequencing.

## Stack and unary instructions

`ucode/control.yaml` implements PUSHST/POPST, three CALL forms, RETS,
TRAP, and RETI with shared push/pop helpers. Stack accesses force a 32-bit
field independently of FS/FE. The synchronous register port selects the
shared SP throughout these instructions, and CALL through SP captures its
original target before push predecrement. TRAP zero reloads the reset vector
without touching the stack. Tests check unaligned stacks and adjacent bits,
return-address alignment and extension order, RETS argument disposal,
TRAP 1/31 vectors, status restoration, and trap-zero behavior.

ABS, NEG, NEGB, NOT, and immediate logical instructions use existing shared
ALU operations. ABS computes its flags from `0 - Rd`, then stores the absolute
value; in particular, a positive nonzero input sets N. It preserves C.
ANDI's encoded extension is complemented, while ANDNI names the same opcode
with a direct extension. Logical operations update only Z. Tests also cover
ADDC/SUBB with both input carry/borrow values.

The stack helper issues two 16-bit predecrements, high half first, to preserve
TI's physical push order independently of the field adapter's ascending
word order. IRQ/NMI/HLT/EMU boundaries and array PBX continuation, including cached
binary source chunks, have focused tests. LINE also has ordinary PC-rewind
continuation tests;
see [interrupts.md](interrupts.md) and [stack-isa.md](stack-isa.md).

## Iterative shift loop

Constant and register-count SLA/SLL/SRA/SRL/RL share a one-bit ALU helper.
The controller skips its JSR when the captured five-bit count is zero and
repeats the helper's return until the last bit. C and sticky SLA overflow are
held separately until final writeback, preserving the other instructions'
flag masks. No general-purpose register is modified during the loop.
All ten encoding forms have YAML/reference coverage; see [shifts.md](shifts.md).
The loop's additional clocks require integrated timing and performance work.

## Register-list scan

MMTM/MMFM scan a 16-bit mask through one dynamic register-RAM read address.
The other read port retains Rp; one write port updates either Rp or a loaded
list register. MMTM saves ascending register numbers with a reversed mask;
MMFM restores descending register numbers with a direct mask. Both use
ordinary shared-ALU steps and forced 32-bit fields. The empty-mask test
asserts an exact bus-request count to exclude the old CPU's unintended data
transfer. See [register-lists.md](register-lists.md).

## Opcode recognition audit

`python3 modules/jttms10/ver/decoder/check.py` enumerates all 65,536 opcode
words against the unchanged pinned old decoder. It requires every defined
reference encoding to have a microcode entry and compares reserved-range
classification for every word. This is a recognition check; the architectural
programs and dedicated bus/interrupt tests establish the behavior they assert.
LINE and both of its decision-tie encodings are included.


## Graphics datapath and restart image

`jttms10_gfx.v` is a control kernel for the graphics ROM, not a separate
instruction datapath. Each microstep selects two synchronous register-RAM
read addresses and, when needed, one write address. The current word's read
addresses prime the ports for the next executed word; microcode therefore
places an address-prime step before a consuming ALU step. Address codes 60–63
select the architectural IR Rs/Rd and their following registers dynamically.
Whole-word RF scratch 32–52 holds row bases, current pointers, counters,
window bounds, conversion intermediates and LINE deltas. All of these are
written during instruction setup or loops, so they need no private graphics
flip-flop bank or reset image.

RF values feed the existing A/B operands in full-word, signed/unsigned
half-word, shifted-half, or swapped-half formats. The one shared ALU then
writes A/B, RF scratch, MD, EA, TMP or IR as directed by YAML. Pixel
arithmetic is the explicit exception: `jttms10_pixel` presents operands to
that ALU during PROCESS. MD captures bus reads and holds the processed pixel
through waiting writes. A separate graphics field unit, wide barrel shifter,
multiplier or per-instruction FSM is not synthesized. XY conversion, signed window
comparisons, FILL/PIXBLT row and direction loops, binary 32-pixel chunks and
LINE's independent XY-half updates are microcode sequences.

Array microcode issues a `CHECK` only after a completed destination word or
row and publication of the architectural restart image. B0/B2 hold next
pointers; B10–B14 hold the original opcode, remaining dimensions, source-bit
cache and row context. An ISR can save these B registers with MMTM/MMFM,
perform nested graphics, restore them and RETI. RETI restores IR from B10 and
runs the named rebase entry without refetching the array opcode. LINE instead
publishes B0/B2/B10, stacks its opcode PC with PBX clear, and restarts by
refetching. The bus/PBX benches compare the remaining physical write stream
with an uninterrupted run, including clipped and reverse-direction cases.

The dispatch ROM samples the returned opcode while the fetch response is
held. A response-capture clock precedes combined fetch/dispatch, so the
synchronous family lookup completes before IR/PC commit without a separate
decode microinstruction. `hdl/tms10_dispatch.hex` is a deterministic synthesis
asset; the module QIP supplies its Quartus search path. Simulation initializes
the same table from `decode_family`, and the exhaustive audit compares all
65,536 final entries with the pre-ROM controller as well as the pinned
reference classification. After a microcode layout/decode change, run
`ver/decoder/generate.py hdl/jttms10_ctrl.v ver/build` after generating headers
and copy the resulting image to `hdl/tms10_dispatch.hex`. `ver/build.sh`
rejects a stale checked-in table. Area snapshots copy/hash the generator,
bench and image and regenerate from the copied controller/YAML.

Window and corner calculations use successive shared-ALU comparisons
and RF scratch rather than private endpoint, width or offset registers.
The full 32-bit RF words preserve LINE COUNT and W1 maximum-extent
arithmetic. Scalar memory loads, SEXT/ZEXT and multiply source capture still
share one field-extension input/sign/mask network. Pixel PROCESS consumes
raw destination data from MD and replaces its low half with the processed
pixel; the write data stays stable through memory waits. Binary expansion
caches each 32-bit bitmap chunk in RF scratch and qualifies expanded COLOR
at the destination PMASK lane before PPOP. Architectural, generated-array,
LINE and PBX interrupt tests cover these lifetimes. Final area and timing
must be measured on this cleaned source.

The field adapter consumes the low word of its write window and advances
one physical address per acknowledgement. A six-bit remaining span and the
first-word offset generate masks by bit thresholds, replacing the 48-bit
shifted mask. The aligned read window itself supplies response data, held
until the next request. Field setup/response clocks and HOLD reread behavior
are unchanged. The complete offset/width sweep, cache/field HOLD bench and
full architectural/peripheral suite cover this storage change.
