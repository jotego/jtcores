# HD6301-family instruction and timing assessment

This simunit executes all 230 bytes in the Hitachi HD63701V0 instruction map
with result/state or control-flow checks. The branch fixture checks all 16
branch encodings across all 16 N/Z/V/C pre-states. Data-driven cases cover
addressing modes, arithmetic, memory updates, stack/control instructions,
three DAA result paths, HD bit operations, XGDX, MUL, SLP, and a CEN pause,
plus BA/ext_halt grant hold/release, a one-enabled-CEN NMI pulse, signed PC
branch wrap in both directions, indexed effective-address carry wrap, and
push/pull stack wrap. Runtime coverage checks 766 timing assertions over 229
distinct opcode bytes.
Ordinary timing uses a calibrated microcode-entry-to-`ni` boundary; RTI is
checked at 10E through the next dispatched opcode and WAI at 9E through its
first halt. WAI fixtures check the no-interrupt hold, IRQ and NMI wake, the
pre-stacked frame and RTI stack restore, mainline resume, masked IRQ behavior
while I=1, and stable state/bus during a CEN pause. The saved PC/X/A/B bytes are
checked exactly; the fixture seeds H/Z/V and verifies IRQ saves CCR `$E6` after
CLI and NMI saves `$F6` with I still set. It also checks A/B/X and all CCR flags
are restored before mainline code overwrites A. The WAI microcode moves CC_RMUX
into ALU operand 0 before `md_ld`, so the stacked CCR reflects live flags
instead of a stale ALU result. SLP increments PC once,
holds PC/SP without an interrupt, vectors on IRQ/NMI and resumes after RTI, and
releases on a masked IRQ without vectoring or stacking. The IRQ/NMI wake cases
seed distinct A/B/X/CCR values and check the single stacked PC/X/A/B/CCR frame
(CCR `$E6` for IRQ and `$F6` for NMI), then verify RTI restores A/B/X/all CCR
flags at the next-instruction handoff before LDA overwrites A. Its unbounded
wait interval prevents a fixed-cycle assertion.
PULA, PULB, PULX, DAA, XGDX, and MUL use separate equal-phase Table 13
landmarks. The intervals match the documented cycle counts. The observed
public bus schedule omits the documented `$FFFF` restart-LSB reads for these
operations, and MUL's next-opcode prefetch occurs at the end of its sequence.
This is a recorded Table 13 bus-schedule difference, not a wrapper-contract
failure: the required checks are throughput cycle counts and architectural
register/memory effects. The suite does not require the annotated filler-read
or prefetch sequence to match.

External IRQ and edge-triggered NMI have separate vector, stack/RTI, and
mainline-flow checks, and
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
C70-to-handler-entry IRQ and NMI intervals are each 48 CEN intervals (12E),
matching the HD63701Y0 Figure 52 service sequence.
Each service fixture also pauses CEN mid-entry for 24 master clocks and checks
PC/SP/uaddr/address/data/write stability before resuming the unchanged 48-CEN
interval.

The canonical manual encoding/cycle keys are in `manual-opcodes.csv`; the
simunit compares its runtime-dispatched and runtime-timed opcode sets to the
independent masks and `verify_coverage.py` reconciles the emitted 256-byte
coverage table. 229/230 documented opcodes have cycle checks; SLP (opcode 1A) is explicitly blocked from a fixed-cycle assertion. Reproduce this profile from a clean checkout with
`bash modules/jtframe/ver/cpu/jt6301_timing/run_assessment.sh`.
Run `bash modules/jtframe/ver/cpu/jt6301_timing/run_negative_controls.sh` to
confirm result, timing, vector, and omitted-CCR-load mutations fail as intended;
strict-spec mode passes the selected HD63701 timing and effect checks.
For a direct specification run, source `setprj.sh` and run
`simunit.sh --macros STRICT_SPEC --run modules/jtframe/ver/cpu/jt6301_timing`; it is
expected to pass the selected HD63701 checks.
