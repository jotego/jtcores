# Status push timing (#144, in progress)

TI SPVU001A p.12-228 specifies PUSHST as2+(3),8 machine states with a
word-aligned SP and2+(8),13 otherwise: CPU, hidden writes and CD total.
SP[3:0]=0 defines word alignment (§3.3.1 p.3-6). PUSHST stores full32-bit
ST at SP-32, updates shared SP and preserves every status bit. Original
field definitions do not affect the transfer. SPVS002C June1991 p.14
confirms the minimum two CPU states.

The p.12-228 numeric example has inconsistent address labels. Before
SP=0FF00020h/ST=C0000010h and after SP=0FF00000h agree with SP-32, but its
memory column labels0010h/C000h at0FF00010h/0FF00020h, one word above the
semantic addresses. The numeric-semantic probes use0010h at0FF00000h and
C000h at0FF00010h, following the explicit operation and SP update; they do
not claim to validate the conflicting printed address labels. This is the
simpler semantic implementation under the owner's fallback, not an official
TI correction or an additional agreed timing-target waiver.

PUSHST primes32 and shared SP into the existing ALU operands at decode.
Two microinstructions subtract32/store the old ST and consume the posted
32-bit write. Other CALL/TRAP/hardware-entry push32 helpers are unchanged.
The existing field engine captures the full status and handles word writes,
RMW, wrap, HOLD/restart and overlap with program-cache hits. The instruction
finishes after two CPU states while its write continues; later data work
waits behind the accepted field. No arithmetic unit, register bank or DSP
is added.

The transport's aligned field starts in state1: two writes finish in state5,
leaving three hidden states after CPU state2. An unaligned field starts in
state0: two RMW reads and three writes finish in state10, leaving eight
hidden states. Every physical transfer has the TI two-state minimum plus
its own waits. A CD opcode fetch follows the completed field, adding three
states. The independent oracle checks CPU counts, hidden completion and
remaining stalls, all word addresses/data/order/durations and separate raw
readiness windows. Original electrical pin phases remain outside this
transport contract.

The shared ALU computes the unaligned destination within the first state's
row phase. A qualified late slot retains that state only when CPU enable
history permits it. A prototype using the current state's enable alone
let an aligned write absorb an earlier one-clock CPU pause and begin one
state too early; all architectural results still matched and the seven-clock
profile passed. A new permission bit samples whether the intrinsic lead is
ready at the bus-state edge. The post tag can advertise the next eligible
clock before EA capture, but no field is accepted until mem_req supplies
the valid address. All six short profiles pass after the correction, and a
permanent mutation reproduces the one-clock failure. The earlier Icarus
matrix was stopped for that demonstrated source bug, with reason/status
retained; it is not acceptance evidence.

The1522 programs cover every stack alignment, NCZV crossed with IE,
every ignored field width/FE, opcode positions, high/wrapped addresses and
the numeric-semantic words. Wrapped input preserves the initial reset
vector; writing it after boot is allowed. The224 actual following loads
use A0 or the newly decremented shared SP after K=0/1/2/3/7/10/20 cached
NOPs. They check exact remaining hidden stalls, full A/B/SP/ST, memory and
logical/raw read traffic after the push. The checker parses following
implicit-register observations and refuses to classify a mutation as
timing-only when following SP or another initialized register is wrong.

Targeted corrected-source Verilator stress passes all1522 W=1/CEN=7
programs. The short profiles,128 models and four timing mutations pass;
the new mutants change CPU count, aligned/unaligned first-word eligibility
or the short-pause permission. Full Icarus comparison, clean-checkout and
standard-runner acceptance remain pending. The preceding prototype passes
180 architectural programs and13 functional IRQ/resume scenarios; final
corrected-source architecture/full-runner acceptance remains required.

All1522 historical programs fail timing/bus checks on the old public
f059cb000 HDL and microcode, with correct full main/following state and
drained memory. Ordinary cached72/168 INCLK becomes16; CD96/192 becomes
64/104. The baseline uses an isolated old production tree with the new
harness, preserving and verifying all22 old HDL/YAML inputs and old ROM.
Its78 committed representatives are evidence, never an oracle or allowlist.
All87,510 preceding fixtures, programs, goldens and boundaries are unchanged.

Matched corrected-source quartus_map estimates3,656 ALMs,5,180 ALUTs,
1,724 registers,538,624 RAM bits,five DSPs and zero MLAB bits: +13 ALMs,
+21 ALUTs and one permission register from RETI. Same158 virtual pins,
Quartus Lite20.1.1 Build720,5CSEBA6U23I7,20ns,seed1 and effort; the snapshot
matches the current RTL/YAML. This is a synthesis estimate; no PUSHST fit
or STA claim is made. The final ceiling remains≤3,500 fitted ALMs.

Probe presence becomes111/133 forms with89,032 cases, leaving22 missing.
The same10,771 source choices and448 unresolved MOVB instances remain,
including45 agreed published targets. CALL/TRAP/lists, graphics, complete
condition/cache/peripheral/HOLD/IRQ/resumption rules, known targets and
final area, full board STA, NARC simulation/MiSTer acceptance remain open.
Passing these probes does not establish full ISA timing compliance.
