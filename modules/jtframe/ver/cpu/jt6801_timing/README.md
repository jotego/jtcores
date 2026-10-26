# MC6801/MC6803 instruction and timing assessment

This simunit executes all 220 bytes in the Motorola MC6801/MC6803 opcode map
with result/state or control-flow checks. The branch fixture checks 16 branch
encodings across all 16 N/Z/V/C pre-states. Data-driven cases cover addressing
modes, arithmetic, memory updates, stack/control instructions, DAA, MUL,
interrupt return, a CEN pause, BA/ext_halt grant hold/release, a one-enabled-CEN
NMI pulse, signed PC branch wrap in both directions, indexed effective-address
carry wrap, and push/pull stack wrap. Runtime coverage checks 745 timing
assertions over all 220 documented opcode bytes. Ordinary assertions use a
calibrated microcode-entry-to-`ni` boundary; PULA is checked at 4E, RTI at
10E through the next dispatched opcode, and WAI at 9E through its first halt.
WAI fixtures check the no-interrupt hold, IRQ and NMI wake, the pre-stacked
frame and RTI stack restore, mainline resume, masked IRQ behavior while I=1,
and stable state/bus during a CEN pause. The saved PC/X/A/B bytes are checked
exactly; the fixture seeds H/Z/V and verifies IRQ saves CCR `$E6` after CLI and
NMI saves `$F6` with I still set. It also checks A/B/X and all CCR flags are
restored before mainline code overwrites A. The WAI microcode moves CC_RMUX into
ALU operand 0 before `md_ld`, so the stacked CCR reflects live flags instead of
a stale ALU result.

Controller-input fixtures check the profile-specific IRQ vectors; an all-active
test checks the highest-priority vector. A separate priority fixture executes
CLI, asserts IRQ and NMI together with I clear and the NMI request pending at
the next opcode-arbitration boundary, and requires the NMI vector. External IRQ
and edge-triggered NMI have separate vector, stack/RTI, and mainline-flow checks.
A one-CEN NMI pulse is recognized while I is set; RTI returns to execute CLI,
then the ISR and mainline markers are checked. This does not claim the pulse is
stored until CLI.
The calibrated C70-to-handler-entry service interval is 48 CEN intervals
(12E), matching the MC6801 manual for both IRQ and NMI. Each service fixture
also pauses CEN mid-entry for 24 master clocks and checks PC/SP/uaddr/address/
data/write stability before resuming the unchanged 48-CEN interval. BA is held
for eight enabled CEN samples with stable PC/uaddr/bus, then the
mainline resumes and performs one store. Stack wrap checks PSHA at SP=$0000
through `$FFFF`, poisons that unused wrap address with `$C3`, clears A before
PULA, then checks the restored `$5A`, final SP `$0000`, and unchanged poison.
Branch tests also wrap PC at both ends of
the 16-bit range; indexed X=$FFF0+$30 verifies a carry into $0020. Public bus
timing is separately limited by the captured write/read sequence.

The canonical manual encoding/cycle keys are in `manual-opcodes.csv`; the
simunit compares its runtime-dispatched and runtime-timed opcode sets to the
independent masks and `verify_coverage.py` reconciles the emitted 256-byte
coverage table. 220/220 documented opcodes have cycle checks; none is explicitly blocked from a fixed-cycle assertion. Reproduce this profile from a clean checkout with
`bash modules/jtframe/ver/cpu/jt6801_timing/run_assessment.sh`.
Run `bash modules/jtframe/ver/cpu/jt6801_timing/run_negative_controls.sh` to
confirm result, timing, vector, and omitted-CCR-load mutations fail as intended;
strict-spec mode passes the selected MC6801 timing and effect checks.
For a direct specification run, source `setprj.sh` and run
`simunit.sh --macros STRICT_SPEC --run modules/jtframe/ver/cpu/jt6801_timing`; it is
expected to pass the selected MC6801 checks.
