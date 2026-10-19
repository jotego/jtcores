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

LINE XY conversion now selects the existing scalar DSP operands for signed
Y times pitch and unsigned X times PSIZE. The shared ALU ORs those products
and adds OFFSET; the existing packed ALU updates X/Y independently. The
microcode's aligned branch targets omit four constant-zero low bits, leaving
room for the arithmetic selectors in a 4,096-by-62-bit graphics ROM. There is
one shared scalar multiply expression and no additional register-file bank;
resource inference and final timing closure still require Quartus evidence.

The empty W0 path now retains the four setup states. All 20 count-zero cases
pass base, W1 and W1/P7; a deliberate one-state-short setup fails with correct
architecture, memory and WVP. Nonempty cases remain timing failures: the
single PS16 pixel improves from 572 to 168 INCLK against a target of 72.
All 626 base/stress cases retain the defined architectural and ordered bus
checks. This is an intermediate schedule, not LINE timing signoff.
