# HD6309 MiSTer long-batch validation

This harness counts 25 fetch-to-fetch intervals per loop. It runs the HD6309
extension/native-mode paths and inherited instructions that exercise timing
and indexed addressing. The result checker validates against the Atkinson
timing reference and indexed-postbyte table, then can compare MiSTer and
Verilator captures.

The mode is selected by `LDMD` in the ROM. Build and run separate RBFs for
emulation (`NATIVE_MODE=0`) and native mode (`NATIVE_MODE=1`). Each default run
completes 99,999,975 instructions, or 3,999,999 loops. This produces expected
totals of 835,999,791 E cycles in emulation and 819,999,795 in native mode.
The result window has 96 little-endian 32-bit words: header, 25 `(PC, count,
cycles)` records, and frozen RAM/register/data snapshots.

The test CPU runs from Template's existing 20 MHz PLL output because its
decode path does not meet the 50 MHz board clock. The MiSTer HPS transport and
system-facing `clk_sys` remain at 50 MHz. Reset deassertion and the completion
flag cross between these domains through two-flop synchronizers; result data
is frozen before completion is synchronized to the transport. The CPU test
samples E cycles once per four 20 MHz PLL clocks, so a full batch takes about
167 seconds, plus the HPS result transfer and board startup time.

| Slot | Operation | PC | Emulation E | Native E |
| ---: | --- | ---: | ---: | ---: |
| 0 | INCE | `$0110` | 3 | 2 |
| 1 | TFR E,A | `$0112` | 6 | 4 |
| 2 | ADDR E,F | `$0114` | 4 | 4 |
| 3 | LDD immediate | `$0117` | 3 | 3 |
| 4 | MULD immediate | `$011A` | 28 | 28 |
| 5 | DIVD immediate | `$011E` | 25 | 25 |
| 6 | LDW immediate | `$0125` | 4 | 4 |
| 7 | DIVQ immediate | `$0121` | 34 | 34 |
| 8 | TFM X+/Y+, W=0 | `$0129` | 6 | 6 |
| 9 | BAND direct | `$012C` | 7 | 6 |
| 10–13 | AIM direct, OIM indexed, EIM extended, TIM direct | `$0130`–`$013A` | 6,7,7,6 | 6,7,7,6 |
| 14–17 | LDA E,X; F,X; W,X; ,W | `$013D`–`$0143` | 5,5,5,4 | 5,5,5,4 |
| 18–23 | LDA `n,W`; `[n,W]`; `,W++`; `[,W++]`; `,--W`; `[ ,--W ]` | `$0145`–`$0153` | 6,9,5,8,5,8 | 6,9,5,8,5,8 |
| 24 | BRA | `$0155` | 3 | 3 |

The harness leaves E/F arithmetic live across the loop. It resets W to zero after
DIVQ before the TFM and W-indexed cases. Memory sentinels distinguish direct
and indexed writes; the parser checks AIM/OIM/EIM/TIM final bytes, W, MD, every
PC count, every per-PC cycle sum, and the total cycles.

DIVD immediate has a single 8-bit operand (`11 8D 01`). The direct BAND
instruction has both its register/bit postbyte and direct address (`11 30 40
40`). Keep these instruction lengths intact when extending the test ROM.

## Reproduce

Source `setprj.sh` from the repository root. For each mode, record the SHA-256
of `mc6809i.v` and `jtframe_hd6309_arith.v`; the build script copies the sources
into an isolated build directory and records hashes for every HDL source.

```bash
source setprj.sh
HARNESS=modules/jtframe/ver/cpu/hd6309_mister
TARGET_INSTRUCTIONS=99999975 NATIVE_MODE=0 \
  BUILD_DIR=/nobackup/tasks/jtcores-147/hd6309_mister_emu \
  bash "$HARNESS/scripts/build_hd6309_mister.sh"
TARGET_INSTRUCTIONS=99999975 NATIVE_MODE=1 \
  BUILD_DIR=/nobackup/tasks/jtcores-147/hd6309_mister_native \
  bash "$HARNESS/scripts/build_hd6309_mister.sh"
```

Build a temporary module-test Main from `/nobackup/tasks/jtcores-skills-2/firmware`
(commit `e8b4ea0d56e2328282382fea34b2349025483ff5`). For each mode, run
`/home/jtejada/jtcores-skills/skills/mister-module-test/scripts/host_module_test.py`
with its RBF, the temporary Main binary, a distinct output path, and a timeout
long enough for the 100-million-instruction capture. The helper captures the
active stock Main/core, loads the test RBF temporarily, retrieves the result,
restarts stock Main, reloads the captured core, and checks restoration. Keep
the MiSTer credential in the subprocess environment (`SSHPASS`) only; never put
it on a command line or in logs.

For each mode, create the independent Verilator capture and compare the
little-endian result words:

```bash
"$HARNESS/scripts/verilator/sim.sh" --mode emulation \
  --instructions 99999975 --result-bin /tmp/hd6309-emu-verilator.bin
python3 "$HARNESS/scripts/verilator/compare_results.py" \
  /tmp/hd6309-emu-fpga.bin /tmp/hd6309-emu-verilator.bin \
  --mode emulation --instructions 99999975
```

Repeat with `--mode native` and the native capture paths. Keep Quartus
`build-summary.txt`, `source_manifest.sha256`, `quartus.log`, both raw result
files, and comparer output with the issue artifacts. Report both RTL hashes,
per-mode cycle totals and result hashes, plus the host runner's explicit
restoration status. Build and capture outputs belong in the ignored task
artifacts directory, not in this tracked source directory.
