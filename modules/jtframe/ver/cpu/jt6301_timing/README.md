# HD6301-family instruction and timing assessment

This simunit executes all 230 bytes in the Hitachi HD63701V0 instruction map
with result/state or control-flow checks. The branch fixture checks all 16
branch encodings across all 16 N/Z/V/C pre-states. Data-driven cases cover
addressing modes, arithmetic, memory updates, stack/control instructions,
three DAA result paths, HD bit operations, XGDX, MUL, SLP, and a CEN pause,
plus BA/ext_halt grant hold/release, a one-enabled-CEN NMI pulse, signed PC
branch wrap in both directions, indexed effective-address carry wrap, and
push/pull stack wrap. Runtime coverage checks 753 timing assertions over 229
distinct opcode bytes.
Ordinary timing uses a calibrated microcode-entry-to-`ni` boundary; RTI is
checked at 10E through the next dispatched opcode and WAI at 9E through its
first halt. SLP has a nominal 4E entry/wait/exit sequence in Table 13, but its
unbounded wait interval and failed resume prevent a fixed-cycle assertion.
PULA, PULB, PULX, DAA, XGDX, and MUL use separate equal-phase Table 13
landmarks. The intervals match the documented cycle counts. The observed
public bus schedule omits the documented `$FFFF` restart-LSB reads for these
operations, and MUL's next-opcode prefetch occurs at the end of its sequence.
This is a recorded Table 13 bus-schedule difference, not a wrapper-contract
failure: the required checks are throughput cycle counts and architectural
register/memory effects. The suite does not require the annotated filler-read
or prefetch sequence to match.

The no-interrupt WAI positive control exposes the same handover failure as the
MC6801 profile, so IRQ/NMI wake and pre-stacked WAI resume are unassessed. SLP
holds PC/SP without an interrupt and enters the configured IRQ handler, but
RTI returns to SLP rather than continuing after it. External IRQ and edge-
triggered NMI have separate vector, stack/RTI, and mainline-flow checks, and
separate fixtures check IRQ, ICF, OCF, TOF, SCI, CMI (`irq_cmf`), and IRQ2
vectors using the HD63701Y0 vector table. A simultaneous all-source fixture
checks the documented highest-priority IRQ selection. A separate priority
fixture executes CLI and asserts IRQ and NMI together with I clear and the NMI
request pending at the next opcode-arbitration boundary; it requires the NMI
vector. These tests do not assert public bus equivalence. A one-CEN NMI pulse
is recognized while I is set; RTI returns to execute CLI, then ISR and mainline
markers are checked. This does not claim the pulse is stored until CLI.
BA is held for eight enabled CEN samples with stable PC/uaddr/bus, then the
mainline resumes and performs one store. Stack wrap checks PSHA at SP=$0000
through `$FFFF`, poisons that unused wrap address with `$C3`, clears A before
PULA, then checks the restored `$5A`, final SP `$0000`, and unchanged poison.
Branch tests wrap PC at both ends of the
16-bit range; indexed X=$FFF0+$30 verifies a carry into $0020. The calibrated
C70-to-handler-entry IRQ and NMI intervals are each 50 CEN intervals (12.5E), compared with the manual's 12E
service sequence; this is emitted as a fidelity finding and the raw equal-phase
measurement is guarded at 50. The no-IRQ WAI and SLP/RTI findings remain.

The canonical manual encoding/cycle keys are in `manual-opcodes.csv`; the
simunit compares its runtime-dispatched and runtime-timed opcode sets to the
independent masks and `verify_coverage.py` reconciles the emitted 256-byte
coverage table. 229/230 documented opcodes have cycle checks; SLP (opcode 1A) is explicitly blocked from a fixed-cycle assertion. Reproduce this profile from a clean checkout with
`bash modules/jtframe/ver/cpu/jt6301_timing/run_assessment.sh`.
Run `bash modules/jtframe/ver/cpu/jt6301_timing/run_negative_controls.sh` to
confirm result, timing, vector mutations and strict-spec mode fail as intended.
For a direct specification run, source `setprj.sh` and run
`simunit.sh --macros STRICT_SPEC --run modules/jtframe/ver/cpu/jt6301_timing`; it is
expected to fail at the first documented fidelity mismatch.
