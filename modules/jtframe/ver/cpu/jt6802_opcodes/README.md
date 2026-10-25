# MC6802 documented opcode fixture

`manual-opcodes.csv` is the independent MC6802 opcode/cycle inventory. Its
encoding and fixed-cycle expectations are from the MC6802 data sheet's
instruction matrix and cycle table (Tables 3 and 7), cross-checked against the
local MAME `cycles_6800` table and MC6800 user manual. The inventory has 197
documented bytes. It omits the
compatibility bytes `$21` (BRN) and `$9D` (direct JSR), and the four immediate
store forms `$87/$8F/$C7/$CF`; those are outside the documented MC6802 set.

`init.go` turns the CSV into a runtime oracle. The simunit resets the native
CPU for each listed encoding, seeds the addressing operand and required vector
or return bytes, and measures from accepted public `opcode_fetch` to the next
accepted `opcode_fetch` (or the WAI stop boundary). Architectural checks wait
for the public fetch at a marker address and the matching native dispatch entry
at microstep zero, then sample after that clock edge before the next instruction
executes. Runtime cycle rows are checked against all 197 CSV entries by
`verify_manifest.py`.

The architectural sequence uses synchronous `jtframe_ram` and checks all four
CPX modes with two compare values and both C seeds, then checks a taken BNE and
not-taken BEQ, PSHA/PULA, indexed INC, and BSR/RTS stack and return effects. A
second program checks ADD/ADC/SBC/SUB/CMP,
AND/EOR/OR, shift carry, DAA, direct/indexed/extended byte and word loads and
stores, plus stack wrap at `$0000`. Address schedules
for direct/indexed/extended operations are visible on the wrapper bus in this
fixture.

Run from the repository root after sourcing `setprj.sh`:

```sh
source setprj.sh
python3 modules/jtframe/ver/cpu/jt6802_opcodes/verify_manifest.py
simunit.sh --run modules/jtframe/ver/cpu/jt6802_opcodes
python3 modules/jtframe/ver/cpu/jt6802_opcodes/verify_manifest.py \
  tasks/jtcores-164/artifacts/jt6802-opcodes-simunit.log
```
