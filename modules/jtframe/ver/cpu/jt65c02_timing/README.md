# JT65C02 timing and bus assessment

The repository does not identify a vendor part for `jt65c02`. This suite uses
WDC's W65C02S documentation as an explicit comparison profile; it does not
claim that this CPU is a complete W65C02S or any exact Rockwell variant. The
permanent independent oracle is `canonical_wdc.csv`, checked and expanded to
`expected.mem` by `check_manifest.py`. The checker also reconciles all local
YAML opcode encodings against the 212 named WDC Table 5-2 cells and validates
the exact 149-row known-finding baseline (145 timing rows and four
status/compatibility rows).

The main timing matrix measures 393 opcode/path cases across all 210
implemented encodings, branch outcomes and page-cross paths, indexed crossing paths, 18 decimal ADC/SBC forms plus
nine BCD boundary vectors, interrupt/reset/RTI paths, zero-page wrapping,
public writes, and CEN pause/release. Two additional status/control gates cover
SEI-masked IRQ, decimal-mode interrupt save/clear/RTI behavior, and BIT
memory/immediate flags. The D-status gate adds two known findings: IRQ entry
pushes P=$30 without the prior D=1 bit, and RTI resumes with D=0. The handler
correctly enters D=0/I=1 and computes binary $09+$01=$0A; BIT flag checks pass.
Results and evidence are summarized in
[`tasks/jtcores-151/artifacts/65c02-result.md`](../../../../../tasks/jtcores-151/artifacts/65c02-result.md).

Run the normal regression from the repository root:

```sh
source setprj.sh && simunit.sh --run modules/jtframe/ver/cpu/jt65c02_timing
```

Normal mode passes only when there are no unexpected semantic/bus errors and
the complete ordered observation fingerprint exactly matches
`known_findings.csv`. It fails on a changed, missing, or additional finding.
Run `source setprj.sh && simunit.sh --macros STRICT_SPEC --run modules/jtframe/ver/cpu/jt65c02_timing`
to make any WDC-relative timing or compatibility finding fatal. The current
known baseline contains discrepancies; a normal PASS means baseline regression
stability, not conformance to WDC timing.

In canonical metadata, `page_cross_extra=1` is recorded for relative and
zero-page-relative branches; it applies only when taken (BRA is always taken),
while `taken_extra` records the ordinary taken-branch cycle. WAI/STP have
blank manual cycle cells and are not implemented; the generated zero in their
expected-memory encoding is an unsupported-opcode sentinel, not a claim that
either instruction takes zero cycles.
