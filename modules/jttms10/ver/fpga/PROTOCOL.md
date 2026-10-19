# Autonomous runner protocol, version 1

This interface is under development for jtcores #145. Verilator tests exercise
the synthesizable runner through its Avalon registers. The first physical
25 MHz DataStorm image passed ten representative cases in five batches with
zero architectural, instruction-clock or checked bus-event differences from
the original Verilator bench. Physical timeout and overflow checks also passed:
the failing command returned nonzero, the later case passed independently, and
a clean subsequent batch passed without resetting the FPGA. Overflow was
explicitly reported at the 128-record bound. A 25,000,000-cycle timeout took
1000 ms in the target's monotonic measurement, consistent with the fitted clock.

Those results cover the bounded v1 contract below. They do not establish full
timing-suite support or an end-to-end speedup. Preserve the raw captures,
programming receipt and phase timings when reproducing them.

The same loaded image subsequently passed 3,360 scalar cases in 105 batches
and all 17,840 supported read-only cases in 558 batches, with full host-command
times of 5.83 s and 19.79 s. No FPGA reset or reprogramming occurred between
these runs. Evidence is under
`/nobackup/tasks/jtcores-145/artifacts/physical-matrices/`; independent rechecks
of the raw captures are stored beside the original reports. The first full
Quartus flow took 536.26 s, excluding Platform Designer creation/generation
(138.52/87.27 s). Programming took 0.292432 s, excluding payload transfer.
These phases must be included when comparing a fresh configuration with
software, and kept separate from subsequent reuse of that configuration.

The HPS stages descriptors and program words before START. The FPGA clears
memory, loads the program, resets the CPU, executes and snapshots each case
without consulting Linux. Transfers between batches do not contribute to the
measured instruction duration. One configured image can accept different
programs and host expectations.

## Supported fixture contract

`check_results.py` imports fixture generation, program construction and checks
from `../timing/run.py`. Expected results and timing remain host data; the
transport does not generate or change them. Current v1 supports selected
register, immediate, XY, coordinate and EMU RUN-high programs, with zero added
wait states and zero clock-enable pauses. It checks instruction duration,
status, initialized architectural registers, next decode PC/opcode and the
existing logical-bus and physical-target expectations.

Programs start at bit address `0x1000`. The local target has 4096 16-bit words;
its address range is `0x00000000..0x0000ffff` in TMS34010 bit addresses. Each
case clears all words and copies at most 3840 program words. Reset-vector
reads return the program start. Raw target readiness is four input clocks;
the timed bus independently enforces the CPU bus duration. A machine state
is eight input clocks. Physical FPGA clock frequency is a build property and
must agree with the fitted design's timing constraints.

Initial sparse memory, memory-result snapshots, following-instruction checks,
configurable waits, CEN pauses, HOLD, interrupts and EMU RUN-low scheduling are
not implemented in v1. Fixtures requiring unsupported memory or continuation
checks must be rejected. Selecting a fixture family never waives its oracle
checks. `prepare --read-only-matrix` currently selects 17,840 independent
fixtures; it is not the full timing regression.

The checker accepts an explicit set of supported fixture fields. A new or
unknown observation or stimulus requirement is rejected until its hardware
capture and independent check are implemented; it cannot silently pass through
the transport as unused metadata.

## Avalon register window

The current Platform Designer integration maps a 64-byte slave at physical
address `0xff210840`. Registers below use word indices; the slave has one-cycle
read latency. Validate the programming receipt and compiled SYSID at the known
valid address `0xff210820` before accessing this runner window. The vendor
baseline does not implement the runner window.

| Word | Access | Meaning |
| ---: | --- | --- |
| 0 | Read | Magic `0x4a545231` (`JTR1`) |
| 1 | Read/write | START bit 0; read status; write zero in DONE to rearm |
| 2 | Read/write | Case count, 1 through 32 |
| 3 | Read/write | Descriptor word pointer |
| 4 | Write | Descriptor word; increments pointer |
| 5 | Read/write | Program word pointer |
| 6 | Write | Program data, low 16 bits; increments pointer |
| 7 | Read | Event count; bit 31 indicates overflow |
| 8 | Read/write | Result word index |
| 9 | Read | Result word at index |
| 10 | Read/write | Event index |
| 11–14 | Read | Four words of indexed event, least significant first |
| 15 | Read/write | Case timeout in input clocks; minimum 1000 |

Descriptor and program writes are accepted in IDLE. After draining a completed
batch, write zero to word 1, then stage the next batch. No FPGA reset or
reprogramming is needed between batches. A completed case, including a timed
out case, is followed by full memory initialization and CPU reset for the next
case. Host code must check the batch and every case status, even when the
expected number of results is present.

Each descriptor is eight unsigned 32-bit words:

```text
external_case_id, program_base_word, program_length_words,
test_pc, next_pc, measure_pass, reserved, reserved
```

The shared program staging pool has 4096 words. `measure_pass` counts earlier
acceptances of `test_pc` before measurement begins; it is not a loop count
inferred by the host. PCs are aligned bit addresses. Reserved words are zero.

Each result has 72 unsigned 32-bit words:

```text
external_case_id, status, measured_clocks, test_pc, next_pc,
next_accepted_opcode, architectural_status, start_clock,
physical_rf_shadow[0..63]
```

Status 1 is busy; 2 is successful completion. Errors use bit 31. Case codes
`0x80000002`, `0x80000003` and `0x80000004` report timeout, invalid descriptor
and execution/protocol failure respectively. The batch status is sticky across
cases: a later success cannot erase an earlier failure. A timeout's clocks
field is elapsed case time and must not be interpreted as an instruction
measurement.

Poll while bit 0 is set and bit 31 is clear. Diagnostic bit 8 can become set
before execution finishes, so a busy status can be `0x00000101`. Comparing the
entire status word to 1 would stop polling too early and drain incomplete
results. Error codes with bit 31 set are terminal even if their low bit is set.

The register shadow observes the real synchronous RF write transaction and
tracks validity per case. It adds no asynchronous RF read port. Slots 0–14
are A0–A14, slot 15 is the shared SP, and slots 16–30 are B0–B14. Other slots
are physical workspace. Unwritten snapshot slots contain `0xdead0000 + slot`.
This sentinel representation is a v1 limitation: a valid register containing
that exact value is indistinguishable from an unwritten slot and fails closed.
Snapshotting excludes writes on the next-decode boundary, matching the
software bench's pre-edge observation.

## Bounded diagnostic events

The runner stores at most 128 event records per case and 4096 per batch.
Events cover the measurement interval. Each record has four unsigned 32-bit
words:

| Word | Contents |
| ---: | --- |
| 0 | Per-case input-clock count |
| 1 | Response data in bits 15:0; write data in bits 31:16 |
| 2 | Full bit address |
| 3 | Flags below; unused high bits zero |

Flags: bit 0 is IAQ, bits 4:1 are cycle kind, bit 5 is logical-bus completion,
bit 6 is logical-bus allocation, bit 7 is physical-target acknowledgement,
bit 8 is physical-target allocation, and bits 13:9 identify the case's batch
index. Simultaneous events share a record. The external case ID remains in
its result and descriptor; event indices are local to the batch.

The host reconstructs the existing `BUS_BEGIN`, `BUS_ACCEPT`, `BUS_END`,
`TARGET_BEGIN` and `TARGET_END` records. Logical `BUS_BEGIN` uses the enclosing
eight-clock machine-state boundary; `BUS_ACCEPT` preserves the actual raw
allocation clock. Physical-target clocks are unrounded. Logical completion
uses the CPU bus response; target completion uses target response data.

Exceeding either bound sets the overflow flag and fails the batch. The host
must preserve the bounded capture and report overflow explicitly. It must not
truncate an unbounded trace into an apparently successful result. Event order,
case association, reserved bits and drained counts are checked before invoking
the independent oracle.

## Linux transport and reproducibility

`run_batch.py` stages one binary payload and starts one board process for the
whole matrix. `transport.c` iterates batches, polls completion and drains
results; it performs no per-case stimulus. The binary payload starts with
`JTR2` and a little-endian 32-bit batch count. Each batch contains three
32-bit header words (`case_count`, `program_word_count`, `timeout_clocks`),
eight 32-bit words per descriptor, then the 16-bit program words. The transport
returns JSON captures with batch status, results, events and measured staging,
execution and draining times.

Preserve the programming receipt, RBF hash, compiled SYSID timestamp, source
and generated-image hashes, Quartus settings and timing reports with each
measurement. Host and board elapsed times use monotonic clocks. Report full
compilation, programming, transfer, execution, draining and Python checking
separately before claiming an end-to-end speedup. A no-change Rapid Recompile
is a control, not evidence of improved recompilation after a CPU RTL change.

A failing transport command, malformed capture, wrong case ID, incorrect
architecture, duration mismatch, protocol violation, timeout or overflow must
return a nonzero host command. Raw captures and diagnostics should be retained
when checking fails. Small Verilator comparisons remain necessary when the
runner or observation contract changes; long supported matrices belong on the
FPGA once the image has passed physical validation.

## Reproduce focused verification

From the selected source checkout, compare two cache modes with the original
bench and exercise the autonomous runner through Avalon:

```sh
fpga_evidence=/nobackup/tasks/jtcores-145/artifacts/my-runner-check
mkdir -p "$fpga_evidence"
python3 modules/jttms10/ver/timing/run.py --simulator verilator \
    --exact-case nop_hit --exact-case nop_off --report "$fpga_evidence/reference.json"
python3 modules/jttms10/ver/fpga/check_runner.py --case nop_hit --case nop_off \
    --batch-size 1 --reference "$fpga_evidence/reference.json" \
    --output "$fpga_evidence/avalon"
python3 modules/jttms10/ver/fpga/check_recovery.py --output "$fpga_evidence/recovery"
python3 -m unittest discover -s modules/jttms10/ver/fpga -p test_check_results.py
```

Evidence directories created by the Verilator helpers must be new. The recovery
helper runs two small descriptor negatives. A missing second acceptance of a
setup PC causes a timeout; an unreachable next PC after a measured cache-off
NOP causes a bounded trace overflow followed by timeout. It retains each
expected failing command's exit code, independently checks the next original
case, and checks a subsequent clean batch through DONE rearm. A compiler error
or missing capture cannot count as rejection. These checks validate controller
recovery in Verilator; repeat them on physical hardware separately.

After a fitted image has passed timing analysis, been programmed and had its
identity verified, prepare the supported matrix and run it with the receipt:

```sh
python3 modules/jttms10/ver/fpga/check_results.py prepare --read-only-matrix \
    --output "$fpga_evidence/read-only.json"
python3 modules/jttms10/ver/fpga/run_batch.py "$fpga_evidence/read-only.json" \
    --receipt /path/to/verified-programming-receipt.json \
    --artifacts "$fpga_evidence/hardware" --run-name read-only-1
```

For representative cases with a saved original-bench reference, check the raw
multi-batch hardware capture and compare architectural values, instruction
clocks and relative bus events with one command:

```sh
python3 modules/jttms10/ver/fpga/check_results.py compare \
    /path/to/representative-manifest.json /path/to/hardware/capture.json \
    /path/to/verilator-reference.json --report /path/to/comparison.json
```

Both an oracle failure and a cross-backend difference return nonzero. Use the
same fixture inventory in the manifest and reference.

Preparing a matrix does not execute RTL. Do not use the large manifest with the
representative Verilator helper as a substitute for the FPGA run. Changing
fixtures or expectations does not require rebuilding the image within this
protocol's supported scope.

The transport's `run_ms` measures START through host-observed completion and
includes polling and MMIO overhead. Instruction clocks come from the FPGA
result counters, not this wall-time measurement. Use `run_ms` for end-to-end
benchmarks and coarse clock calibration; do not reinterpret Linux polling
latency as added instruction wait states. Use one transport process per board.
