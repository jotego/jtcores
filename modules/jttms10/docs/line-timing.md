# LINE timing audit and regression baseline

The independent timing oracle is `ver/timing/line_oracle.py`. Its authority is
TI SPVU001A, June 1988, printed pp. 12-99–104, Tables 12-10 and 12-11.
The pinned guide SHA-256 is
`e5f9f50c609ce44deb9dbe4ac79c591e03ff2d0ee2d71d571d0d7f150753ed64`.
The general cache-disabled fetch rule is §5.4.7, p. 5-24, corroborated by
§13.1, p. 13-2. Counts are TI machine states, eight input clocks each.

Setup is four states. Replace processing has P=2 and transfer cost
`(3+P)*E + 5*q`, where E pixels pass the window and q fail it. W0 has q=0;
W2 stops at the first rejected pixel; W3 traverses all pixels. The guide's
literal Figure 12-11 example draws 23 pixels in W3: `4+5*23=119` states.
Cache disabled adds three states for this single-word instruction.

Table 12-11 visibly names SUBS in two columns (P=5 and P=6), and omits SUB.
The oracle preserves both SUBS alternatives and rejects these unresolved
operations. W1's printed terminal +5 and whether q includes the hit pixel
also remain unresolved. These cases are not silently assigned a golden.

`line_cases.py` independently computes geometry, decision/pointer/count
writebacks, memory and defined status for 626 bounded CPU probes. They cover
all five pixel sizes, both tie modes, eight octants, zero and boundary counts,
colors, incoming flags, W2 aborts, W3 clipping, hit/CD and the literal example.
Initial scope is replace/PPOP0, PMASK0 and transparency disabled. N/C/Z are
undefined and masked; V and every other defined status bit remain checked.
B13/B14 have unspecified final values. WVP is observed through the public
peripheral interrupt-pending output. All other architectural registers and
neighboring memory canaries are checked after independent initialization.

The physical word-target checks retain the existing Fig. 13-1 partial-word
read/modify/write and whole-word write contract. They check ordered addresses,
read/write values, IAQ, duration, nonoverlap and target response dispatch.
They do not establish the first pixel's exact phase, pixel issue cadence or
original LAD-pin equivalence. These event contracts require further audit.

Before LINE RTL changes, all 626 probes fail duration while preserving all
checked architecture, memory, WVP and bus events, in base, one-wait and
one-wait/seven-clock CEN-pause profiles (1,878 executions). Empty LINE observes
16 INCLK against 32; a single PS16 pixel observes 572 against 72. This failing
baseline is retained as permanent regressions, without an acceptance allowlist.
Source manifests and raw case logs are retained under the #144 task artifacts.
Eight oracle tests and ten fixture/checker tests anchor the primary examples,
source exclusions and detection of corrupted status, memory, WVP and bus events.

Reproduce with Verilator:

```sh
python3 -B modules/jttms10/ver/timing/test_line_oracle.py
python3 -B modules/jttms10/ver/timing/test_line_cases.py
python3 modules/jttms10/ver/timing/run.py --case line_ --report line.json
python3 modules/jttms10/ver/timing/run.py --case line_ --wait-states 1 --pause-clocks 7
```

These probes join the normal runner. Inventory is now 127/133 forms and
141,236 fixtures; presence of failing LINE probes is not timing compliance.
Six PIXBLT forms, other LINE processing/window/interrupt rules, broader ISA
conditions and known MOVB gaps remain open under #144. The frozen b7ac902c1
normal run excludes these newer probes and cannot validate their source.


## Current implementation work

The timed replace-only W0/W2/W3 path now runs a native four-state setup and
five-state pixel schedule. It overlaps the next pixel's RF reads, shared
ALU/DSP coordinate conversion and window test with the posted physical
transfer. The next pixel issues only after its budget expires; each
interrupt checkpoint also waits for the previous field to drain. B0, B2
and B10 commit before the checkpoint. Preparing a later clipped pixel does
not change V or WVP before that pixel issues. A wholly clipped or empty
line retains exact CEN-pause timing without introducing a bus-alignment
penalty for a transaction it never starts.

Each external low-LRDY extension freezes overlapped preparation and its
intrinsic budget for exactly one eight-clock state. The bus timer continues
independently. Its focused bench checks the extension span as well as
completion. Neither Linux latency nor a host-serviced memory request belongs
in this timing contract.

The existing scalar DSP computes Y times pitch and X times PSIZE; the shared
ALU combines these with OFFSET and updates packed coordinates. New graphics
controls capture formatted RF operands directly into the existing ALU and
write the previously selected RF destination while priming the next reads.
Aligned microcode branch targets omit four zero low bits, keeping the
expanded graphics ROM at 4,096 by 63 bits. No arithmetic unit or register
bank is added; final resource inference and timing closure still require
Quartus evidence.

All 626 cases pass targeted Verilator base, one-wait, one-wait/one-clock
pause and one-wait/seven-clock pause profiles. The single PS16 hit now
observes the required 72 INCLK. The timed IRQ bench interrupts after pixels
1, 2 and 3 with zero/one external wait state, nests ISR FILL under
MMTM/MMFM, resumes via RETI, and checks PC rewind, B0/B2/B10, physical
writes, memory and a 0x10000 COUNT checkpoint. These are bounded directed
checks, not a full timing audit of IRQ entry or all processing modes.

Three positive controls and three actual RTL mutations pass: shortening
setup, shortening the pixel budget and absorbing an external wait each
produce a timing failure with checked architecture/memory preserved.
The short-pixel probe uses PS16 with no external waits so its transfer
latency does not mask the intrinsic-budget regression.

Reproduce native negative controls and timed IRQ checks with:

```sh
python3 -B modules/jttms10/ver/timing/mutations.py --group line --report line-mutations.json
bash modules/jttms10/ver/sim.sh lineirq-timed
```

W1 and non-replace PPOP, masks and transparency retain the generic path.
The independent oracle/fixture goldens are unchanged. Full current-source
normal/clean/CI, wider signed/wrapping geometry, original bus-pin phase
and final fitted area/STA/NARC acceptance remain open. Long regression
matrices are moving to the autonomous DataStorm runner under #145; no FPGA
instruction-test equivalence is claimed before physical validation.
