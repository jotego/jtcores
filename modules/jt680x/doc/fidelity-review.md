# JT680x CPU fidelity assessment

This report records a finite, directed assessment of the five active CPU
profiles selected by JTFRAME. It compares measured behavior with independent
device documentation. A passing simunit means its inventory, fixtures, and
observer ran as designed; it does not imply that every measurement matches the
manual. Profile repairs made in response to measurements are identified in the
relevant rows; target expectations come from independent device documentation.
Generated HDL remains a local simulation artifact.

## Scope and reproducibility

The active configurations are `jt6801.yaml` (MC6801/MC6803 execution),
`jt6301.yaml` (HD6301 execution, selected through HD63701V/Y wrappers),
`jt6805.yaml` (MC6805/68705 execution), `jt65c02.yaml` (the original Rockwell
R65C02 target profile), and `jtdeco222.yaml` (the DECO222 opcode/data
adaptation on the 65C02 core). README references to MC6800/MC6802/HD63705 do not select
separate configurations here. For the HD profile, the V0 sheet supplies
instruction timing and the Y0 sheet supplies IRQ2/CMI vectors; that does not
establish identical behavior for every member of either family.

Run the permanent aggregate suite from a fresh checkout:

```sh
bash modules/jtframe/ver/cpu/run_jt680x_timing_assessment.sh
```

It sources `setprj.sh`, runs all five independent simunits, checks MC6801 and
HD6301 result/timing/vector negative controls plus strict-spec positive runs,
then runs the MC6805 inventory/timing/result/vector negative controls. The
optional strict HMOS mode compares all 237 measured MC6805 instruction
intervals with the selected P3 HMOS oracle; the current implementation passes
all 237 outcomes:

```sh
bash modules/jtframe/ver/cpu/run_jt680x_timing_assessment.sh --strict-hmos
```

The profile-specific instructions are in the
[MC6801](../../jtframe/ver/cpu/jt6801_timing/README.md),
[HD6301](../../jtframe/ver/cpu/jt6301_timing/README.md),
[MC6805](../../jtframe/ver/cpu/jt6805_timing/README.md),
[65C02](../../jtframe/ver/cpu/jt65c02_timing/README.md), and
[DECO222](../../jtframe/ver/cpu/jtdeco222_timing/README.md) suite READMEs.
The existing `cores/slap/ver/mcu` simunit is a supplementary functional
integration gate; it passed in the
independent review, but it is not an instruction-timing oracle.

The strict original-Rockwell target check is:

```sh
bash modules/jtframe/ver/cpu/run_jt680x_timing_assessment.sh --strict-rockwell
```

It requires zero discrepancies against the 210-opcode Rockwell source matrix
and its directed conditional paths. The original assessment snapshot recorded
149 WDC-relative observations (145 timing observations and four stacked-status
compatibility observations).
Those are retained as historical WDC comparison data; they do not define the
selected Rockwell target expectations or its strict zero-finding result.
There is no WDC-targeted RTL run in the current suite; `--strict-wdc` is
rejected so it cannot silently run the Rockwell oracle under a WDC label.

An earlier, superseded five-suite snapshot is preserved at
`tasks/jtcores-151/artifacts/aggregate-final2.log` (SHA-256
`f94281ea338de99eeb3c0f2515f0663335bab942b99f71ccdc9353ee52cf1c92`). Its
strict-HMOS log records the pre-repair result (215/237 timing deviations across
185 encodings) and is superseded by the current 237/237 pass. Its WDC log
records 149 historical comparison observations; it is not a current strict
target run.
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
| MC6805/68705; P3 HMOS timing target with audited P3/P5 user profiles | 207 HMOS forms; 237 instruction intervals including alternate branch outcomes; 169 explicit effect assertions plus three focused address probes; both outcomes of conditional and bit branches; stack-frame, wrap, masked IRQ, and service fixtures | All 237 outcomes match the independent HMOS manual oracle (22 also match CMOS); zero timing deviations and observer/fixture failures. The 11-bit stack frame and `$60–$7F` stack format are independently supported by the P3 and P5 sheets. IRQ/TIRQ service is 44 CEN edges (11 E) each; simultaneous priority, first-eligible masked request acceptance, CLI/SEI completion behavior, and pulse/rearm cases pass. Three non-timing effects confirm IX1 carry, IX2 high-offset reads, and public `$0800` aliasing to physical `$0000`, with distinct poison bytes. The timing result is specifically the P3 HMOS profile; it does not establish P5 timing equivalence or exact part identity for every wrapper user. |
| Original Rockwell R65C02 target | All 210 documented opcode encodings; 420 timing/path cases, 46 reserved-opcode NOP effect/progress checks, and five status/control gates. Branch coverage includes forward/backward same-page taken paths, both page-cross directions, BRA, conditional branches, BBR/BBS, and not-taken conditions. Decimal, indexed, indirect-JMP `$XXFF`, reset/IRQ/NMI/BRK/RTI, public writes and CEN behavior are also directed. | Strict Rockwell run passes with zero timing discrepancies and zero semantic/bus errors. The 46 reserved timings are unspecified by the source and are excluded from timing comparison. Absolute-X RMW is checked at seven cycles with two target reads and one write; `$XXFF` JMP adds its documented cycle. The suite is finite directed coverage, not exhaustive operand or pin-phase proof. |
| Historical WDC W65C02S comparison | The selected 210-opcode profile compared with 212 named WDC forms; prior 393-path comparison snapshot included decimal, indexed crossings, branches, status, reset/interrupt and CEN cases. | The historical inventory retains 149 WDC-relative observations (145 timing plus IRQ B, NMI B, stacked IRQ D, and RTI-restored D). It is not the current target oracle. WAI `$CB` and STP `$DB` are absent from the selected original-Rockwell profile. |
| DECO222 local profile | 512 opcode-remap comparisons and 19 runtime cases, including decrypted IRQ/NMI handler paths. | The local opcode permutation, opcode/data separation, public bus behavior, extra NOP forms, and encrypted IRQ/NMI paths pass. No original DECO silicon manual or exact vendor part is identified, so extra-NOP timing is checked against local YAML, not claimed as a silicon timing pass. |

The 149 WDC rows are historical measured comparison observations, not 149
proven independent defects. Likewise, B's 215 timing rows include multiple
outcomes for some encodings. The per-suite reports and CSV manifests retain
the case-level expected and observed values.

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
`f80b78c56a84a4097de597d272828e81322d5b045a3b7aed224daecb7d81f801`. The selected 11-bit P3 timing target is anchored by the exact MC68705P3 sheet, SHA-256
`df1625d1419ce38be5c35b276699c5428beec90d5b3ab84f2439fe7df05950b2`. The
P3 sheet shows the `$60`–`$7F` physical stack range and fixed stacked CCR/PCH
bits. The P5 sheet, SHA-256
`a294850e0b7b396e3b6bf7b10d45236ed7d2510c809347f12457e797406c2cad`,
independently shows the same 11-bit PC and stack/frame format (Figure 5 and
stack description, printed pp. 3-855–856). These common frame properties are
supported by both parts; P3 timing claims below remain P3-specific.

The per-user audit found P5S for Fairy Land Story and Slap Fight, P5 for Get
Star, and a P3-compatible MCU on Tiger-Heli A47_14. In Kunio, `renegade.cpp`
labels Renegade's MCU ROM P5 and the original Kuniokun MCU ROM P3; the
Renegadeb no-MCU bootleg is a separate configuration. The Bubl wrapper path
uses Tokio's P5 MCU; Bubble Bobble's original MC6801 path is separate. The
wrapper's default `ROMW=11` and P5 `pc_in` comment do not establish a single
part for all users.

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
four enabled CEN edges per E. All 237 runtime outcomes now match the original
P3 HMOS counts, with no fractional or ambiguous intervals. The old result at
source revision `35dbb7636` (22 HMOS matches and 215 CMOS-only observations) is
retained only as historical context; `known_observations.mem` is not an
acceptance oracle.

The RTS (`$81`) return-effect fixture starts at P3 SP `$7D` and reads the
frame at `$7E`–`$7F`, within the part's documented `$60`–`$7F` physical stack
range.

**Original Rockwell R65C02 target.** Rockwell, *R65C02, R65C102, and R65C112
R65C00 Microprocessors*, source scan
`/gdrive/jotego/arcade/components/datasheets.chipdb.org/Rockwell/R65C02-R65C102-R65C112.pdf`,
SHA-256 `0c526b991bff7133e53d753cf6ec1a7a7b31520daf938961676b3bd43e2b37f5`.
The printed p. 1-11 opcode matrix (PDF p. 9) supplies the 210 named
instructions, encoding lengths, and base cycles. Its footnotes distinguish
indexed/BRA page-cross increments from taken conditional/bit-branch increments:
the latter add one cycle on a same-page take and two when the destination page
differs. Printed p. 1-10 Table 4 (PDF p. 8) specifies reserved encodings as
NOPs, two reads and one write for CMOS RMW, fixed seven-cycle absX RMW,
`JMP ($XXFF)` pointer-page increment plus one cycle, decimal +1 cycle, and D
clearing after reset and interrupts. The matrix has no WAI or STP.

The sheet is internally ambiguous about decimal flags. Table 4 calls the
decimal N/V/Z flags valid for the CMOS family, while the instruction-summary
note 7 calls decimal Z invalid. The suite checks decimal arithmetic and the
unambiguous extra cycle, but makes no blanket N/V/Z conformance claim; boundary
flag checks are limited to the stated vectors and mask undocumented cases.
Similarly, the Rockwell sheet does not define the B-bit stack convention. The
status suite checks pre-interrupt D and PC/status ordering against Rockwell,
and uses MOS Technology's [*MCS6500 Microcomputer Family Programming Manual*](https://www.bitsavers.org/components/mosTechnology/6500-50A_MCS6500pgmManJan76.pdf),
2nd ed. (Jan. 1976), §§3.4 and 9.11 for IRQ/NMI B=0 and BRK B=1. §8.11 says
PHP transfers P unchanged but does not establish forced PHP B=1; PHP's B byte
is logged as an observation, while N/V/D/I/Z/C preservation and PLP restore
are tested. Rockwell Table 4 and the IRQ/reset prose support D clearing and
interrupt ordering; RTI's saved D restoration is checked by directed
architectural behavior.

The observer measures accepted instruction boundaries at public PCs, uses
four enabled CEN edges per PHI2 cycle, rejects non-integral intervals, and
runs synchronous RAM on CPU CEN. Strict coverage is finite: 420 opcode/path
cases plus separate reserved-opcode and status/control checks; it is not proof
over every operand, initial state, pin history, or bus phase.

**Historical WDC W65C02S comparison.** WDC, [*W65C02S Datasheet*](https://www.wdc65xx.com/wdc/documentation/w65c02s.pdf)
(2024-02-16), opcode Table 5-2 (PDF p. 22), base timing and page-cross rules
Table 4-1 (pp. 19–20), decimal/reserved Table 7-1 (p. 30), plus IRQ/NMI/reset
sections. Original PDF SHA-256
`4fb4a2c1055e319c6d8df5a6f7b348d9cffa958fdabc982a494bda54e5e17195`. This
was the prior comparison target, not the selected Rockwell target. The
historical snapshot recorded 149 WDC-relative observations (145 timing and
four stacked-status rows); the WDC CSV and finding inventory remain separately
labeled for historical comparison. They are not used as Rockwell expectations.
In that prior comparison the status rows are source-backed WDC/family
observations, not universal vendor claims.

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

The exact deployed MC6805 part is not identical across every wrapper user.
P3 timing equivalence is not established for P5; the frame properties used by
the shared implementation are backed by both part sheets. The finite suite
does not prove every operand combination or all pin/bus phases. Reserved-opcode timing is
unspecified by the Rockwell source; WAI/STP are not implemented as modern
extensions in this profile. The HD special-operation bus-schedule difference is recorded
as outside the supported wrapper contract; throughput counts and architectural
effects remain contract checks. B reset-entry latency is
not assigned an oracle, and CMOS STOP/WAIT behavior is not dynamically tested
in the P3-targeted suite. DECO extra-NOP timing has no
independent original-hardware oracle. None of the directed matrices proves
arbitrary-state semantic equivalence or all pin/bus phase behavior.

The main reviewed fixture/oracle fingerprints are:

| Source | SHA-256 |
|---|---|
| `jt6801_timing/test.v` | `509eb810d75f2b694717f6c2753ba8ffcd060b928506e5dcef1e1bd3c2a75cd7` |
| `jt6301_timing/test.v` | `bc1780ca059283613d9a98e0ead7eff94c84025ba5fc31c3053d956c40d0e664` |
| `jt6805_timing/test.v` | `ee59b72c971131007e9a5c5531e5a7e910e93b42efafb35defc9ac2d7e255864` |
| `jt680x/ucode/6805.yaml` | `6d5fd4890a4fbade24bb8ff7b6dd13e45adcc278e3b051ac7a18210e4cc2eedd` |
| `jt6805_timing/manual_inventory.py` | `de5b8d7c9933625ef4deb86d93cdb6aab2d23f6706af4c272299fb89e4aa1f28` |
| `jt6805_timing/known_observations.mem` | `8a75eeb68be54beb6d1bd1b643dd93e30deaebe3c6bdc0442190a6f5efba19a0` (historical diagnostic, unused by gates) |
| `jt65c02_timing/test.v` | `860941c3e059deb535236fbc040aa8122091dad622cf9b2ffb3c99cc225ef88d` |
| `jt65c02_timing/rockwell_oracle.py` | `352f1111ab01e834101d6f9bc8651b265c47dd7e0cbed088548813daf487fca9` |
| `jt65c02_timing/canonical_rockwell.csv` | `0611228c370c01b9f18a9b11a8b8ece443ac0e5c2cdf4420353a48f9ece2f5e8` |
| `jt65c02_timing/canonical_wdc.csv` | `af436b97653ed2678977d06b536a83a5a5591b97e9e232ab487818c04faa8fba` |
| `jt65c02_timing/known_wdc_findings.csv` | `e791025afbeee85109370a8732fc11b6d922bd2541a963528a79346d97382ee3` |
| `jtdeco222_timing/test.v` | `3ddc0a864c36b98688a900cddafe16dc0580604263ea4ee29f6a4974cf5ca087` |

These are fingerprints of the principal reviewed fixture and oracle files,
not a substitute for the complete permanent source or its per-suite
regeneration/inventory checks.

## Related repair follow-ups

The original assessment's measured findings were tracked in eight repair
issues. The selected-profile and saved-status repairs in #158 and #159 are
incorporated above; the remaining follow-ups are tracked separately from this
finite assessment:

| Issue | Follow-up |
|---:|---|
| [#152](http://gitea.jotego.es/jotego/jtcores/issues/152) | MC6801/HD6301 WAI handover and HD6301 SLP resume |
| [#153](http://gitea.jotego.es/jotego/jtcores/issues/153) | Decide whether HD63701 Table 13 special bus schedule is required |
| [#154](http://gitea.jotego.es/jotego/jtcores/issues/154) | Resolve MC6805/68705 HMOS instruction timing deviations |
| [#155](http://gitea.jotego.es/jotego/jtcores/issues/155) | Preserve MC68705P3 stacked frame bits and legal stack wrap |
| [#156](http://gitea.jotego.es/jotego/jtcores/issues/156) | Latch MC6805 IRQ requests while the I mask is set |
| [#157](http://gitea.jotego.es/jotego/jtcores/issues/157) | Match MC6801 and HD63701 interrupt-service timing |
| [#158](http://gitea.jotego.es/jotego/jtcores/issues/158) | Select the original Rockwell R65C02 profile and match its documented timing |
| [#159](http://gitea.jotego.es/jotego/jtcores/issues/159) | Preserve IRQ/NMI/BRK saved-status semantics; leave PHP B convention unassessed |
