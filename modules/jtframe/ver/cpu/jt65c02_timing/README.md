# JT65C02 Rockwell R65C02 timing and bus assessment

The selected target is the original Rockwell R65C02 from the shared R65C00
family. The primary source is
`/gdrive/jotego/arcade/components/datasheets.chipdb.org/Rockwell/R65C02-R65C102-R65C112.pdf`
(SHA-256 `0c526b991bff7133e53d753cf6ec1a7a7b31520daf938961676b3bd43e2b37f5`).
`canonical_rockwell.csv` is transcribed from the Rockwell instruction matrix,
printed page 1-11 (PDF page 9), with conditional and decimal footnotes kept as
separate fields. Its `encoding_bytes` field preserves the matrix's one-byte
BRK encoding; `pc_span=2` separately represents the padding-byte fetch and
PC+2 behavior measured by the simulation fixture. Table 4 on printed page
1-10 (PDF page 8) supplies the CMOS
RMW, reserved-opcode, decimal-mode, and indirect-JMP enhancements. The OCR and
rendered source pages used for visual verification are in
`tasks/jtcores-158/artifacts/rockwell/`.

The source lists 210 named instructions, including Rockwell RMB/SMB/BBR/BBS
opcodes. Its opcode matrix omits WAI and STP. Table 4 says invalid encodings
act as NOPs; all 46 blank matrix cells, including `$CB` and `$DB`, therefore
use the generic NOP path. The manual gives no timing for those reserved NOPs,
so they are checked for no architectural changes and forward progress without
including them in the strict timing comparison.

`rockwell_oracle.py` validates the transcribed grid, YAML's exact 210-opcode
set, and the controller's reserved-opcode map before writing `expected.mem`.
It includes negative controls for a missing opcode, a changed timing cell, a
conditional branch page-cross value, a decimal-cycle value, the fixed absX-RMW
cycle, and the Rockwell `$XXFF` indirect-JMP extra cycle. `canonical_wdc.csv` and
`known_wdc_findings.csv` remain separately labeled historical W65C02S comparison
data; they are not used as the R65C02 target expectations.

The simulation measures all 210 named opcodes, conditional branch outcomes,
taken forward/backward same-page and page-cross branch paths, indexed
page-cross paths, binary and decimal ADC/SBC cases, the Rockwell
indirect-JMP `$XXFF` path, interrupt/reset/RTI behavior, public writes,
zero-page pointer wrapping, reserved NOP semantics, and a CEN pause/release
case. IRQ/NMI and BRK/PHP status behavior is checked independently from timing.

Run from the repository root:

```sh
source ./setprj.sh && simunit.sh --run modules/jtframe/ver/cpu/jt65c02_timing
source ./setprj.sh && simunit.sh --macros STRICT_ROCKWELL --run modules/jtframe/ver/cpu/jt65c02_timing
```

The strict mode requires zero Rockwell timing discrepancies and rejects
non-integral CEN intervals. Both modes retain the semantic, bus, reserved-NOP,
and oracle-negative-control assertions. `check_manifest.py` validates the
separate historical WDC CSV and finding inventory; it does not run the current
RTL against a WDC timing target.

Rockwell Table 4 specifies that D is cleared after reset and interrupts,
valid decimal-operation flags are correct, and decimal arithmetic takes one
extra cycle. It also specifies an additional cycle for `JMP ($XXFF)` as the
indirect pointer increments across a page. The interrupt prose says the
pre-interrupt PC and status are stacked before I is set. Rockwell describes
seven processor-status flags and does not specify the B-bit stack convention.
MOS Technology's MCS6500 Microcomputer Family Programming Manual, 2nd ed.
(publication 6500-50A), §§3.4, 8.11, and 9.11 describes B as a
microprocessor-generated break marker, PHP as an unchanged status push, and the
BRK-versus-IRQ stack distinction. IRQ/NMI B=0 and BRK B=1 are checked against
that family reference. PHP's B byte is logged as an observation, not a
Rockwell requirement; PHP's physical flags and PLP restoration are checked
independently.
