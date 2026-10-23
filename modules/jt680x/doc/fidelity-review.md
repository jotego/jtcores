# JT680x CPU fidelity assessment

This report records a finite, directed assessment of the five active CPU
profiles selected by JTFRAME. It compares measured behavior with independent
device documentation. A passing simunit means its inventory, fixtures, and
observer ran as designed; it does not imply that every measurement matches the
manual. No production RTL, YAML timing declaration, or shared generated HDL was
changed for this assessment.

## Scope and reproducibility

The active configurations are `jt6801.yaml` (MC6801/MC6803 execution),
`jt6301.yaml` (HD6301 execution, selected through HD63701V/Y wrappers),
`jt6805.yaml` (MC6805/68705 execution), `jt65c02.yaml` (the implemented CMOS
65C02 opcode set), and `jtdeco222.yaml` (the DECO222 opcode/data adaptation on
the 65C02 core). README references to MC6800/MC6802/HD63705 do not select
separate configurations here. For the HD profile, the V0 sheet supplies
instruction timing and the Y0 sheet supplies IRQ2/CMI vectors; that does not
establish identical behavior for every member of either family.

Run the permanent aggregate suite from a fresh checkout:

```sh
bash modules/jtframe/ver/cpu/run_jt680x_timing_assessment.sh
```

It sources `setprj.sh`, runs all five independent simunits, checks the MC6801
and HD6301 result/timing/vector/strict-mode negative controls, then runs the
MC6805 inventory/timing/result/vector negative controls. To also print and return the known
strict HMOS timing failure, use:

```sh
bash modules/jtframe/ver/cpu/run_jt680x_timing_assessment.sh --strict-hmos
```

The strict mode exits nonzero because the MC6805/68705 implementation differs
from the selected HMOS timing oracle. That is a fidelity result, not a failure
of the default test harness. The profile-specific instructions are in the
[MC6801](../../jtframe/ver/cpu/jt6801_timing/README.md),
[HD6301](../../jtframe/ver/cpu/jt6301_timing/README.md),
[MC6805](../../jtframe/ver/cpu/jt6805_timing/README.md),
[65C02](../../jtframe/ver/cpu/jt65c02_timing/README.md), and
[DECO222](../../jtframe/ver/cpu/jtdeco222_timing/README.md) suite READMEs.
The existing `cores/slap/ver/mcu` simunit is a supplementary functional
integration gate; it passed in the
independent review, but it is not an instruction-timing oracle.

The strict WDC comparison is:

```sh
bash modules/jtframe/ver/cpu/run_jt680x_timing_assessment.sh --strict-wdc
```

It returns nonzero while the 65C02 has its 149 WDC-relative observations
(145 timing observations and four stacked-status compatibility observations).
A default 65C02 run passes only if that exact reviewed set is reproduced.

The final default five-suite run is preserved at
`tasks/jtcores-151/artifacts/aggregate-final2.log` (SHA-256
`f94281ea338de99eeb3c0f2515f0663335bab942b99f71ccdc9353ee52cf1c92`). The
separate strict-HMOS run reports 215/237 timing deviations across 185
encodings in `tasks/jtcores-151/artifacts/6805-strict-hmos-final.log`; strict
WDC reports 149 findings in `tasks/jtcores-151/artifacts/65c02-strict-final.log`.
The A-profile reproduction log and source/evidence hashes are listed in
`tasks/jtcores-151/artifacts/6801-6301-SHA256SUMS`.

Each suite generates microcode includes inside its own simulation directory
and uses synchronous JTFRAME RAM where memory timing matters. No suite edits
the shared generated HDL. All measured designs use Verilog and microcode; an
original VHDL replay is neither present nor needed as a substitute for the
independent device-manual oracles. Tests are finite directed cases, not formal
equivalence or proof over all initial states, operands, pin histories, and
bus schedules.

## Results by profile

| Profile and expectation | Executed scope | Measured result and important limits |
|---|---|---|
| MC6801/MC6803; Motorola MC6801 reference | All 220 documented opcode bytes; 745 timing assertions and 1,256 runtime dispatches; 218 generic directed cases (a separate counter from unique opcode-byte coverage); 256 relative-branch cases across all N/Z/V/C pre-states; reset, vectors, effects, stack-wrap, CEN pause and interrupt priority | WAI has a 9E no-interrupt hold; directed IRQ/NMI wake cases verify the single pre-stacked frame including exact PC/X/A/B bytes and CCR (`$E6` IRQ, `$F6` NMI), RTI restoration of distinct A/B/X and all CCR flags before the mainline overwrites A, masked IRQ behavior while I=1, and stable state/bus during WAI and service CEN pauses. Its CC_RMUX value is loaded into ALU operand 0 before `md_ld`, fixing the stale-ALU stacked CCR. The pre-edge interrupt-entry U=`C70` to pre-edge first-handler-opcode U=`860` interval measures 48 CEN edges (12 E), matching the MC6801 manual. ICF/OCF/TOF/IRQ vectors and priority are covered; simultaneous eligible IRQ+NMI at an unmasked NI boundary selects NMI. A one-CEN NMI pulse is recognized while I=1 and the interrupt return resumes through CLI; the fixture does not claim storage of the pulse until CLI. |
| HD6301 family; V0 timing, Y0 vector additions | All 230 V0 opcode bytes; 766 timing assertions and 1,314 runtime dispatches; 233 generic directed cases (a separate counter from unique opcode-byte coverage); 256 branch cases; arithmetic, memory, bit operations, DAA/MUL/XGDX/SLP, vectors, stack-wrap and CEN pause | WAI has a 9E no-interrupt hold and directed IRQ/NMI wake with a single pre-stacked frame including exact PC/X/A/B bytes and CCR (`$E6` IRQ, `$F6` NMI), RTI restoration of distinct A/B/X and all CCR flags before the mainline overwrites A, masked IRQ behavior while I=1, and stable state/bus during WAI and service CEN pauses. Its CC_RMUX value is loaded into ALU operand 0 before `md_ld`, fixing the stale-ALU stacked CCR. SLP advances PC once, holds PC/SP without an interrupt, vectors on IRQ/NMI and resumes after RTI, and releases on a masked IRQ without vectoring or stacking. PULA/PULB/PULX/DAA/XGDX/MUL throughput landmarks match their special table counts. The observed public bus schedule omits documented `$FFFF` restart-LSB reads, and MUL's next-opcode prefetch occurs at the end of its sequence; this is a documented Table 13 schedule difference outside the supported wrapper contract. Required checks remain throughput cycle counts and architectural register/memory effects. The SLP sleep interval is not assigned a cycle result because its observed wait/exit sequence does not expose the manual's timing boundary. The pre-edge interrupt-entry U=`C70` to pre-edge first-handler-opcode U=`860` interval measures 48 CEN edges (12 E), matching the HD63701Y0 figure; IRQ/ICF/OCF/TOF/SCI/CMI/IRQ2 selections are exercised, and simultaneous eligible IRQ+NMI selects NMI. A one-CEN NMI pulse recognized while I=1 returns through CLI; no retention-until-CLI claim is made. |
| MC6805/68705; HMOS 11-bit P3 timing target | 207 HMOS forms; 237 instruction intervals including alternate branch outcomes; 169 explicit effect assertions plus three focused address probes; all conditional and bit-branch taken/not-taken destinations | 22 cases match both HMOS and CMOS columns; 215 cases match CMOS and differ from HMOS, across 185 encodings. No case matches neither; observer/fixture failures are zero. Independent P3 checks find 8 stacked-PC-high-byte differences, 3 stacked-CCR differences, one legal stack-wrap difference, and one missing latched masked-IRQ request. IRQ/TIRQ service is 44 CEN edges (11 E) each and simultaneous priority is correct. Three added non-timing effects confirm IX1 carry, IX2 high-offset reads, and public `$0800` aliasing to physical `$0000`, using distinct poison bytes. Exact deployed part is not proven for all wrapper users; P3 stack claims are not generalized to P5. |
| Implemented CMOS 65C02 compared with WDC W65C02S | All 210 local opcodes compared against 212 named WDC instructions; 393 measured paths and two status/control fixtures capturing four status observations, including decimal, indexed crossings, branch/bit-branch outcomes, IRQ/NMI/reset and CEN cases | 149 ordered WDC-relative observations are retained (145 timing observations plus IRQ B, NMI B, stacked IRQ D, and RTI-restored D). There are zero unexpected semantic/bus failures. Strict WDC mode fails on those observations. This is a named comparison profile, not an exact vendor declaration for the RTL; WAI `$CB` and STP `$DB` are absent. |
| DECO222 local profile | 512 opcode-remap comparisons and 19 runtime cases, including decrypted IRQ/NMI handler paths | The local opcode permutation, opcode/data separation, public bus behavior, extra NOP forms, and encrypted IRQ/NMI paths pass. No original DECO silicon manual or exact vendor part is identified, so extra-NOP timing is checked against local YAML, not claimed as a silicon timing pass. |

The 65C02's 149 observations are measured comparison rows, not 149 proven
independent defects. Likewise, B's 215 timing rows include multiple outcomes
for some encodings. The per-suite reports and CSV manifests retain the
case-level expected and observed values.

## Sources and observer rules

**MC6801/MC6803.** Motorola, [*MC6801 Reference Manual*](https://bitsavers.org/components/motorola/6801/MC6801RM_AD2_MC6801_Reference_Manual_May84.pdf), second edition,
MC6801RM(AD2): opcode map Appendix B, p. B-1; timing summary Appendix H,
p. H-1; WAI description; interrupt vector and priority sections. Original scan
SHA-256 `1b4a5b321664fb73e7a8b1e3ea042512ed673dc133dbc2b3a81fd5196622f075`.

**HD6301.** Hitachi, *HD63701V0/HD637A01V0/HD637B01V0*: Tables 8–11, printed
pp. 652–655; opcode map Table 12, p. 656; special-operation Table 13,
printed pp. 657–662; sleep description, p. 662. The sheet says V0 is pin-compatible
with HD6301V1. HD63701Y0 vector/priority additions use Tables 3–4, printed
p. 731. Original scan hashes are respectively
`0b0897de8ca02170445ccfead800aaddbc6a042dcf5a765485920e91483713b2` and
`439b278ca51a47cb5985d91ed39b3a26fe027f0293a387cdb34e939b4e198698`.

The MC6801/HD6301 ordinary observer uses the microcode entry-to-`ni` interval,
calibrated against NOP, immediate LDAA, and relative branch landmarks. Four
enabled CEN edges correspond to one E cycle. Their interrupt-service
diagnostic spans pre-edge interrupt-entry `U=C70` to pre-edge first-handler-
opcode `U=860/!stack_busy`; both
profiles produce 48 raw enabled edges, matching their manuals' 12 E service
interval. MC6801 source is §5.3,
printed pp. 5-13–5-14/Fig. 5-12. Hitachi's HD63701Y0 source is Fig. 52,
printed p. 787 (PDF p. 70); the HD63701V0 sheet independently shows 12 service
slots in Fig. 10, printed p. 637 (PDF p. 8). The HD special operations use
equal-phase landmarks from the manual's Table 13 because its pipeline note
warns that ordinary fetch-to-fetch accounting is exceptional for PULL, DAA,
MUL, and XGDX. The observed public schedule omits the documented `$FFFF`
restart-LSB reads for PULA, PULB, PULX, DAA, XGDX, and MUL; MUL's next-opcode
prefetch occurs at the end of its sequence. This is a documented bus-schedule
difference outside the supported wrapper contract. The required checks are
throughput cycle counts and architectural register/memory effects, not
reproduction of the annotated filler-read or prefetch sequence.

**MC6805/68705.** Motorola, [*M6805 User's Manual*](https://bitsavers.org/components/motorola/6805/6805_Users_Manual_2ed_1983.pdf), second edition (1983),
instruction-specific timing chapter, cycle tables, Appendix F, and Appendix
G2; original scan SHA-256
`f80b78c56a84a4097de597d272828e81322d5b045a3b7aed224daecb7d81f801`. The
11-bit P3 target is supported by the exact MC68705P3 sheet, including its
printed p. 3-572 (PDF p. 5) stack figure and description; SHA-256
`df1625d1419ce38be5c35b276699c5428beec90d5b3ab84f2439fe7df05950b2`. P3
sets the physical stack prefix to `$60`–`$7F`, stacked CCR high bits to ones,
and unused stacked PC high bits to ones. Those are P3-specific architectural
expectations.

The independently transcribed timing inventory has 209 documented encodings:
207 HMOS and two CMOS-only STOP/WAIT extensions. Appendix F conflicts with
instruction-specific entries for B7, BC, CC, CE, CF, DC, EC, and FC. The
assessment preserves those conflicts and follows instruction-specific entries
(and G2 where that form is present); for example CF extended STX is HMOS 6 /
CMOS 5 in its instruction entry (printed p. 212) and G2 (p. 241), despite
Appendix F's 5/5 (p. 231). G2 does not list CC extended JMP or CE extended LDX;
their chosen expectations are from their instruction entries only. The
observer spans accepted opcode `ni` edges, checks public PC plus the
synchronous-RAM-latched opcode, and calibrates three warmed NOP intervals to
four enabled CEN edges per E. The independent review reproduced all 237
endpoints without fractional or ambiguous intervals.

The RTS (`$81`) return-effect fixture starts at P3 SP `$7D` and reads the
frame at `$7E`–`$7F`, within the part's documented `$60`–`$7F` physical stack
range.

**65C02.** WDC, [*W65C02S Datasheet*](https://www.wdc65xx.com/wdc/documentation/w65c02s.pdf) (2024-02-16), opcode Table 5-2 (PDF p. 22),
base timing and page-cross rules Table 4-1 (pp. 19–20), decimal/reserved table
7-1 (p. 30), plus IRQ/NMI/reset sections. Original PDF SHA-256
`4fb4a2c1055e319c6d8df5a6f7b348d9cffa958fdabc982a494bda54e5e17195`. The
canonical table includes taken-branch page-cross timing for relative and
zero-page-relative forms; WAI/STP cycle cells are unknown/blank source values,
not zero-cycle CPU claims. The observer counts accepted instruction boundaries
at known public PCs, uses four enabled CEN edges per PHI2 cycle, rejects
non-integral intervals, and runs synchronous RAM on CPU CEN.

The IRQ stacked-status comparison uses MOS Technology, [*MCS6500 Microcomputer
Family Programming Manual*](https://www.bitsavers.org/components/mosTechnology/6500-50A_MCS6500pgmManJan76.pdf), second edition (Jan. 1976), §9.11, printed p. 144:
hardware IRQ saves B=0, while the measured RTL saves B=1. The repository does
not identify an exact WDC/Rockwell part, so this remains a source-backed
6500-family compatibility observation rather than a universal vendor claim.
The IRQ/NMI fixtures both observe B=1 in stacked P. A separate D-status gate
enters IRQ with D=1/I=0: the handler has D=0/I=1 and its `LDA #$09; ADC #$01`
produces binary `$0A`, but stacked P is `$30` (D not preserved) and RTI leaves
D=0 rather than restoring D=1. WDC Table 7-1 (PDF p. 30) specifies decimal-mode
clearing on interrupts and §3.4 (PDF p. 9) specifies restoration of saved P.
The four status rows are IRQ B, NMI B, stacked IRQ D, and RTI-restored D; they
are retained as family/WDC-relative compatibility observations, not universal
behavior claims.
The strict comparison mode fails while the 149 observations remain; default
simunit passes only if the same reviewed observation inventory is reproduced.

**DECO222.** No original DECO CPU manual or exact silicon part is established
by repository evidence. MAME's `src/mame/dataeast/deco222.cpp` at revision
`e5a5a102889d6c62f12e39a4db3e950e4f5d6822` independently corroborates the
opcode permutation and opcode-only disassembly transform; it is not a primary
hardware specification. Encrypted IRQ and NMI cases keep `opdec` asserted
through CLI, handler opcode, RTI, and return; operands remain unpermuted. IRQ's
accepted-NOP-to-vector interval is nine cycles including the two-cycle NOP
(seven cycles service), and NMI is seven cycles from its accepted boundary.
Both paths measure RTI as six cycles from the handler's RTI boundary to the
stacked-PC return boundary. NMI then executes the expected two-cycle instruction
at its distinct return address before reaching the common mainline store; both
paths verify that store's timing and architectural write effect.
The local DECO `$5C` additional NOP is three bytes/four cycles; WDC lists the
same reserved encoding as three bytes/eight cycles. These are distinct profile
claims.

## Prior-work audit

The assessment started from baseline
`a6a033c090a672f46c7b8739a362d771191f1333`. The bounded Gitea audit examined
128 distinct issue bodies and 137 comments attached to likely candidates; it
sampled only 50 of 1546 repository-wide comments, so it does not claim a full
global-comment search. Issue #142 was abandoned (final comment 3293), #86
records Pocket Gal decoder gating/integration rather than instruction timing,
and #101/#141 reuse CPU test approaches for other processors. The existing
Slap/Tiger-Heli MCU simunit checks command/acknowledgment behavior, not
instruction intervals. The legacy 65C02 testgen suite has 49 functional
groups, but its in-tree build is blocked by missing Go checksum entries; an
isolated dependency-resolved run passed and is not represented as a clean-tree
reproduction. Historical one-instruction corrections are regression context,
not a substitute for these independent matrices. See the issue audit for exact
queries, source snapshots, and commit references.

## Remaining limits

The exact deployed MC6805 part is not identified for every wrapper user, P5
stack-specific rules were not inferred from P3, and the 65C02 vendor profile
is unspecified. The HD special-operation bus-schedule difference is recorded
as outside the supported wrapper contract; throughput counts and architectural
effects remain contract checks. B reset-entry latency is
not assigned an oracle, and CMOS STOP/WAIT behavior is not dynamically tested
in the P3-targeted suite. The 65C02 assessment does not implement WAI/STP and
does not prove all operand combinations. DECO extra-NOP timing has no
independent original-hardware oracle. None of the directed matrices proves
arbitrary-state semantic equivalence or all pin/bus phase behavior.

The main reviewed fixture/oracle fingerprints are:

| Source | SHA-256 |
|---|---|
| `jt6801_timing/test.v` | `509eb810d75f2b694717f6c2753ba8ffcd060b928506e5dcef1e1bd3c2a75cd7` |
| `jt6301_timing/test.v` | `a3c9602b3982e7fc166d3ca2daef8abd06a71a722d2fdcc0a44f9228ae624359` |
| `jt6805_timing/test.v` | `f8e964f0917d0bd470b5148351fab2c61218040d41b02a8a6468e168d824b663` |
| `jt6805_timing/manual_inventory.py` | `de5b8d7c9933625ef4deb86d93cdb6aab2d23f6706af4c272299fb89e4aa1f28` |
| `jt6805_timing/known_observations.mem` | `8a75eeb68be54beb6d1bd1b643dd93e30deaebe3c6bdc0442190a6f5efba19a0` |
| `jt65c02_timing/test.v` | `44dfc1ba10e7b6e310455772738fe9adb8e4293ab83930d693574bf8165dd811` |
| `jt65c02_timing/canonical_wdc.csv` | `af436b97653ed2678977d06b536a83a5a5591b97e9e232ab487818c04faa8fba` |
| `jtdeco222_timing/test.v` | `3ddc0a864c36b98688a900cddafe16dc0580604263ea4ee29f6a4974cf5ca087` |

These are fingerprints of the principal reviewed fixture and oracle files,
not a substitute for the complete permanent source or its per-suite
regeneration/inventory checks.

## Related repair follow-ups

The assessment's measured findings have eight independently tracked repairs.
Each is related to #151 but does not block completing or closing the finite
assessment:

| Issue | Follow-up |
|---:|---|
| [#152](http://gitea.jotego.es/jotego/jtcores/issues/152) | MC6801/HD6301 WAI handover and HD6301 SLP resume |
| [#153](http://gitea.jotego.es/jotego/jtcores/issues/153) | Decide whether HD63701 Table 13 special bus schedule is required |
| [#154](http://gitea.jotego.es/jotego/jtcores/issues/154) | Resolve MC6805/68705 HMOS instruction timing deviations |
| [#155](http://gitea.jotego.es/jotego/jtcores/issues/155) | Preserve MC68705P3 stacked frame bits and legal stack wrap |
| [#156](http://gitea.jotego.es/jotego/jtcores/issues/156) | Latch MC6805 IRQ requests while the I mask is set |
| [#157](http://gitea.jotego.es/jotego/jtcores/issues/157) | Match MC6801 and HD63701 interrupt-service timing |
| [#158](http://gitea.jotego.es/jotego/jtcores/issues/158) | Decide intended CMOS profile and resolve W65C02S-relative timing findings |
| [#159](http://gitea.jotego.es/jotego/jtcores/issues/159) | Preserve 65C02 interrupt status semantics (B and D) |
