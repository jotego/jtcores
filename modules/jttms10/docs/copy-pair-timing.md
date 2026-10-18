# Two-address copy timing (#144, in progress)

MOVE/MOVB `*Rs(SOffset),*Rd(DOffset)` and `@SAddress,@DAddress` use the
shared field engine and existing EA/TMP storage. TI SPVU001A printed
pp.12-121/122,12-124/125,12-151/152,12-157/158 describe these four forms;
Tables13-3/4 pp.13-6/7 give alignment classes and printed alternatives.
They add 13,714 permanent programs. The inventory now has probes for
106/133 instruction forms; eleven stack/call/list/EMU and sixteen graphics
forms remain missing. Probe presence is not full condition or timing signoff.

The independent equation adds two/four intrinsic operand states to plain
memory copies, retains their hidden-write count H, and charges three
additional CD states per instruction word (§5.4.7). With N=2/4 operands,
CPU=plain-copy CPU+N and CD=CPU+H+3*(1+N). An aligned 16-bit MOVE is
`5+(1),15` for offsets and `7+(1),23` for absolutes; aligned 32-bit cases
are `7+(3),19` and `9+(3),27`. FE adds no state. MOVB always uses eight bits
regardless of FS/FE; its single-word B/B cases use `5+(3),17` and `7+(3),25`.

The printed sources disagree. Preserve these literal alternatives:

| Form/condition | Table13-4 CPU/CD | Typical entry CPU/CD | Project CPU/CD |
| --- | --- | --- | --- |
| Offset MOVE, aligned 32 bits | 7/16 | 7/19 | 7/19 |
| Absolute MOVE, aligned 16 bits | 7/23 | 7/12 | 7/23 |
| Absolute MOVE, aligned 32 bits | 9/24 | 9/27 | 9/27 |
| Offset MOVB, byte-aligned B/B | 5/7 | 5/9 | 5/17 |
| Absolute MOVB, byte-aligned B/B | 7/7 | 7/25 | 7/25 |

Other summary differences affect alignment indices7/8/9/12 and byte
index5's CPU count. The owner directs the easier implementation where no
reliable source conclusion exists. The project keeps the common shared
schedule, while each fixture retains the summary and applicable entry
numbers. These 4,331 additional exact source-choice instances bring the
inventory to 10,475 choices and the same 448 unresolved previous MOVB
instances, including 45 agreed published-target gaps. The strict audit
retains all 10,923 discrepancies. No TI erratum is claimed, and these choices
do not waive either the absolute-register MOVB 1/7 target or the plain
byte-copy CD7 target.

The shared ALU calculates each signed offset independently. Absolute
address words combine through existing operand capture. EA/TMP exchange
source and destination once; the complete source is read before any write.
The posted destination uses TMP directly, preserving the captured source
EA until the read completes. Neither form updates a pointer or ST. Aliased
registers use the same original base with their independent signed offsets.
Absolute forms encode no source/destination register or bank; field MOVE
still encodes F, and absolute MOVB's opcode is exactly0340h.

A three-bit count tracks the remaining operands; the existing issue counter
widens by one bit for four intrinsic states. Cache hits can supply operands
without the external processing delay. Each cache-miss request is gated at
its own operand's intrinsic slot, including a cached prefix. CD operands
retain their per-response processing schedule. The existing `mem_fast`
metadata permits those external slots; the word wrapper keeps these operands
on its ordinary cache path. They do not bypass cache lookup. Scalar/field
DSP resources and the cache RAM/ports remain shared.

The oracle asserts operand reads, source reads, destination RMW/writes and
following fetches separately. With W external waits, CD operands start at
state1 and then every4+W states. Data starts at N+N*(3+W); a warm hit starts
at N. The posted write starts at CPU-1 plus prefix and source-read waits.
Every actual transfer adds its own waits, while trailing writes overlap
cached work. Both logical two-state cycles and raw target readiness windows
retain address/data/IAQ/order checks.

Cold programs cover every missing operand position. A four-word fill adds
nine states and four waits. An absolute instruction starting in subsegment
slot3 consumes all four words of the next subsegment as operands: its next
opcode needs a second fill. That fill waits behind the posted writes.
This case therefore takes CPU+H+18 states plus waits on source reads,
destination transfers and eight fill reads. The second fill's first read
starts exactly after the final write; four NOP words and IAQ-high are
asserted. It is not treated as a single-fill instruction. Other cold cases
retain CPU+9 and charge waits on source plus four fill words.

Coverage includes every width1..32 and alignment index, both fields/FE/cache
modes/banks, every byte source/destination offset, ignored FS/FE definitions,
A/B/shared-SP aliases, signed endpoint operands, overlap, wrap and flags.
There are 96 cold cases, 32 additional warm phase probes and 240 actual
following loads at K=0/1/3/7/20 NOPs. Every initialized A0..A3/B0..B3/SP,
full ST and sparse memory word remains checked. Separate bit models compute
warm-up and measured images; cold cases use the initial image and freeze
the CPU only after the measured result while accepted writes drain.

The 154 literal programs use thirteen absolute field output triples
(p.12-158), sixteen absolute byte output pairs (p.12-125), and the offset
byte endpoint examples (p.12-122), including their actual signed operands
and base addresses in both banks. The final p.12-158 mnemonic's F0 conflicts
with its FS1=32 column; that vector selects the defined field, keeps the
source note, and does not validate the conflicting F0 label. The separate
width matrix covers both F values. Field offset examples are mathematical
model cases, not claimed as additional hand-transcribed literal vectors.

Directed testing exposed a real scheduling bug: a cached prefix before a
second/third missing absolute operand inherited the later-CD-word gate,
adding two/one extra states with correct data. A dynamic first-miss threshold
now follows the current operand's index. The permanent mutation restores
that error. Another control rejects early external operand requests; a third
rejects slow operand capture. Their architectural/memory checks stay active.

On unchanged public `4b34f984e`, all 13,714 programs fail timing/bus checks
with zero register/ST, following-state or drained-memory failures. The
captured `fef24b8be` has the same complete Git tree; all 22 historical
HDL/YAML hashes verify against the public parent. The committed baseline
retains 325 representatives. It is historical evidence, never an oracle or
expected-failure allowlist. All 69,794 previous fixture/program/golden
hashes remain unchanged.

All 104 checker/model tests, strict lint, all 13,714 new W=1/CEN=7 programs,
566 representative W=1/CEN=6 Icarus/Verilator exact case/provenance matches
and six 44-case short Icarus pause profiles pass (264 cases). The matched
map estimates 3,603 ALMs, 5,114 ALUTs, 1,722 registers, 538,624 block-memory
bits, five DSPs and zero MLAB bits: +64 ALMs/+103 ALUTs/+four registers from
source-extension copies, with unchanged RAM/DSPs. This is synthesis area,
not fitted-area or STA acceptance. The snapshot uses the same complete
NARC GSP/158 virtual pins, device, 20 ns clock, seed1 and effort. Full normal
runner, mutation and clean-checkout validation are in progress. Full ISA/conditions, cache/peripheral interactions, HOLD/IRQ and
graphics resumption, known MOVB targets and final fitted area≤3,500 ALMs,
positive STA, NARC simulation and MiSTer gameplay remain required.
