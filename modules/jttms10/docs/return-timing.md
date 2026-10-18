# Subroutine return timing (#144, in progress)

RETS follows TI SPVU001A p.12-232: 7/10 machine states with a word-aligned
stack and 9/12 otherwise (cache hit/CD). Section3.3.1 p.3-6 defines word
alignment by SP[3:0]=0. It reads a full32-bit PC, clears its four low bits,
then updates SP by32+16*N without changing ST. FS0/FS1/FE do not affect the
read. The summary p.12-17 and SPVS002C June1991 p.14 support the timing.

The entry says N ranges0..32, but the instruction has five argument bits.
Its default is explicitly0, and literal examples use0,1,2,16,31 with the
stated arithmetic. The implementation keeps all five-bit values0..31 and
default0, which is the simpler existing interpretation under the owner's
fallback. No distinct encoding for32 is invented or claimed as validated;
this prose/encoding discrepancy is not an official TI correction.

RETS shares POPST's SP source priming, early full-width field read and
retained response. Three CPU states remain after the final response,
versus POPST's four. Existing microcode adjusts SP and transfers the saved
PC; no microcode, arithmetic unit, storage bank or DSP is added. The word
wrapper retains first-slot eligibility. Fetch priming takes precedence over
the completed stack instruction so the next instruction can read A2/B2.

The independent fixtures derive counts, full PC/SP/ST, individual source
words and following-load results from the specification and bit model.
They check every logical/raw source transfer's address/data/IAQ, order,
duration and readiness window. Stack words must be consecutive on the
machine-state grid inside the measured instruction; no undocumented first
microinstruction read edge is invented. CD's next opcode read is checked
against the printed duration. Original electrical bus-pin phases remain
outside this transport contract.

The1488 programs cover all32 arguments and all16 SP low-bit positions,
both cache modes, initial flags, ignored field definitions, discarded PC
bits, high and wrapped addresses, all opcode positions and ten literal
programs. A real target opcode executes after every return; the program
then loops through A12 to reinitialize and warm the measured path. Sparse
high target words use initialized memory. Wrapped-stack vectors preserve
the initial reset vector, constraining those particular saved PC bits.

Forty-eight cached targets execute a real A2-to-A1 or B2-to-B1 load with
width1/16/32, FE0/1 and stack/source alignment boundaries. Full following
state, timing, logical/raw transfers and read-only memory are checked.
Four separate-process probes also cover target-opcode monitoring in that
runner mode; their observations must match batching apart from case IDs.

All1488 historical programs preserve architectural, following-state and
read-only memory results on the preceding public3840d02f4 HDL/YAML.
Its768 cached cases fail timing;720 CD cases pass. Typical cached50/66
INCLK becomes56/72; CD80/96 already matched. The committed baseline keeps
180 representatives and the old source/ROM provenance. It is historical
evidence, never a timing oracle or expected-failure allowlist.

Actual RTL mutations shorten post-response work or remove first-slot
eligibility. Both must fail timing with correct main/following state and
memory. Separate aligned/unaligned response-pause controls retain all
state while a96-clock CPU pause overlaps the read, capture its response,
and resume without duplicate transfers. These bounded event checks do not
replace the independent exact unpaused timing requirements.

Targeted validation passes117 checker/model tests,180 architectural
programs, strict lint,1488 W=1/CEN=7 Verilator probes and six short Icarus
pause profiles of18 cases each (108 programs). Both new timing mutants
and all seven response-event controls/one duplicate-read mutant pass.
Four separate-process case objects match their batch results after removing
only the local case identifier. All84,610 preceding fixtures, encoded
programs, goldens and boundaries remain unchanged. All1488 stressed case objects and source/generated-ROM hashes match Icarus
and Verilator exactly. A detached clean checkout repeats117 models, all1488
stressed programs and the seven response controls/one mutant with exact
case/event observations and provenance. This is targeted clean validation,
not a complete standard runner. All43 physical timing input hashes match
public implementation commit dc661d409; its full Git tree matches isolated
025fcc284. The fresh full109-form standard runner completes260,012 exact programs:
three86,098-case matrices, two DIV pauses and six286-case phase unions.
All117 models,180 architecture,699 bus scenarios,55 mutation controls and
63 rejection checks pass, along with the separate response7/1 and EMU8/1
event benches. Exit1 is solely the24-missing/448-unresolved gate. All43
source hashes and all seven generated hashes match this stage exactly.
Clean scope remains targeted; no full clean standard-runner result is
claimed. Later implementation stages require their own full validation.

Matched NARC GSP quartus_map estimates3,570 ALMs,5,082 ALUTs,1,722
registers,538,624 block-memory bits,five DSPs and zero MLAB bits: -50 ALMs
and -41 ALUTs relative to POPST, unchanged registers/RAM/DSPs. Same158
virtual pins, Quartus Lite20.1.1 Build720,5CSEBA6U23I7,20ns,seed1 and
effort. The isolated fit completes at3,649 ALMs,1,722 registers,68 RAM
blocks and five DSPs. This exceeds the3,500 fitted-ALM limit by149; the
area gate fails. Four-corner internal STA at20ns has minimum setup+1.567ns
and hold+0.163ns. External virtual I/O is unconstrained, so this is not
full NARC board timing closure. The source snapshot matches dc661d409;
remaining implementation changes must be fitted and analyzed again.

Full standard-runner/clean-checkout, fitted area/STA and NARC/MiSTer
acceptance remain pending. RETI/IRQ/graphics resumption, calls/traps/lists,
remaining graphics/conditions, cache/peripheral/HOLD and known MOVB targets
remain open. The source gate keeps448 unresolved MOVB instances, including
45 agreed published-target gaps; no new timing-source waiver is added.
