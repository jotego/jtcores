# Autonomous runner protocol, version 2

This interface is under development for jtcores #145. Version 2 adds sparse
read-only memory, deterministic waits and early CEN pauses. The fitted v2 image
passes 21 physical representative executions with zero differences from the original
Verilator bench, including sparse loads, high branch targets, maximum-length
register lists, wraparound stack reads and pixel reads. Six cases repeat with
one wait state and a seven-clock early CEN pause. Physical timeout and
512-record overflow tests return failure, preserve the later case and pass a
clean subsequent batch without reset. An overlapping W1/P7-after7 pause
returns per-case protocol failures for MOVE-load and POPST; later MMFM/PIXT
cases and the clean rearm batch pass independently.

The same image passes all 51,542 supported cases in 1,665 batches for each of base,
W1/P7-after0 and W3/no-pause profiles: 154,626 physical executions. Full host
command walls are 86.28 s, 98.26 s and 100.75 s respectively, including transfer
and checking. Independent raw-capture rechecks pass every
case; the largest case trace contains 141 records. Detailed phase timings are
retained beside the captures. The driver timer is sampled before report
serialization/stdout/cleanup, so external wall time is the full-command measure.
These results do not establish a matched end-to-end software speedup.

The validated v2 RBF SHA-256 is
`5c7e6b9a8fc11a6164c12800eaf61eaf31383ad9adc50e88d8b577712c156f2e`, with
runner RTL SHA-256
`0a681b94a6b6b0aaa71437975d398508f1294de2f6dbc97ab1ae940e58c709fc`.
Its 25 MHz runner has worst setup slack +5.857 ns; all four analyzed corners
have zero negative TNS. The complete appliance uses 6,837 ALMs, 343 memory
blocks and six DSP blocks; this is not a CPU-only area result. The successful
Quartus flow took 771.34 s and physical programming took 0.345287 s, excluding
transfer and SSH startup. Preserving the previous build's IP/database avoided
Platform Designer regeneration, but no matched recompilation speedup is claimed.

The actual QIP-bound synthesis SYSID is 22, timestamp 1792433033. The preserved
`db/ip` tree contains a different older SYSID and must not identify this image.
The original input snapshot omitted the QIP's child sources; a separate audit
records all 97 synthesis-subtree hashes, unchanged from the preceding build.
Those are post-compilation observations, not a claim of pre-compilation freezing.
Evidence and the corrected receipt are under
`/nobackup/tasks/jtcores-145/artifacts/v2-7-{physical,program}/`.

Verilator tests exercise
the synthesizable runner through its Avalon registers. The first physical
25 MHz DataStorm image passed ten representative cases in five batches with
zero architectural, instruction-clock or checked bus-event differences from
the original Verilator bench. Physical timeout and overflow checks also passed:
the failing command returned nonzero, the later case passed independently, and
a clean subsequent batch passed without resetting the FPGA. Overflow was
explicitly reported at the 128-record bound. A 25,000,000-cycle timeout took
1000 ms in the target's monotonic measurement, consistent with the fitted clock.

Those historical results cover v1's register-only contract. They do not establish full
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
transport does not generate or change them. Version 2 supports selected
register, immediate, XY, coordinate, EMU RUN-high, memory-load, register-list
load, pixel-read and control-flow programs. It checks instruction duration,
status, initialized architectural registers, next decode PC/opcode and the
existing logical-bus and physical-target expectations.

Programs start at bit address `0x1000`. The local target has 4096 16-bit words;
its address range is `0x00000000..0x0000ffff` in TMS34010 bit addresses. Each
case clears all words and copies at most 3840 program words. Reset-vector
reads return the program start. Raw target readiness is four input clocks;
the timed bus independently enforces the CPU bus duration. A machine state
is eight input clocks. Physical FPGA clock frequency is a build property and
must agree with the fitted design's timing constraints.

Each case can initialize up to 64 sparse halfwords at unique aligned 32-bit
bit addresses in at most 16 regions, each spanning 1024 bit addresses. The
synchronous sparse RAM stores a valid bit alongside each halfword; registered
region tags select it. Sparse data overrides local program memory, IO and
reset-vector responses, matching the original bench. All sparse valid bits,
tags, local memory and CPU state are initialized independently for every case.
The runner reads the initialized sparse words back after the architectural
snapshot. The RF observer adds no asynchronous read port to CPU RAM.

Per-case `wait_states` adds eight input clocks per state to the fixed four-clock
target response delay. `pause_clocks` and `pause_after_clocks` select a CEN pause
relative to the measured instruction start; target logic keeps running. The
runner counts actual paused clocks and checks architectural stability. This
version supports the original bench's early-pause contract: an outstanding
physical request during the pause fails explicitly. A one-clock target ACK
is preserved even when CEN is low. In-flight response pauses require a future
contract extension.

External memory writes, following-instruction checks, positive or -2 drain
modes, HOLD, interrupts and EMU RUN-low scheduling are not implemented in v2.
Drain 0 and -1 retain the immediate next-decode snapshot behavior of the original
bench. Fixtures requiring unsupported observations or continuation must be
rejected. Selecting a fixture family never waives its oracle checks.
`prepare --read-only-matrix` currently selects 51,542 independent fixtures
covering 93 forms; the remaining 89,694 fixtures require unsupported features.
The manifest records exclusion reasons and inventory hashes. This is not the
full timing regression. Version 1's 17,840-case scope remains supported by the
capture checker for archived evidence; the current board transport requires v2.

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
| 0 | Read | Magic `0x4a545232` (`JTR2`) |
| 1 | Read/write | START bit 0; read status; write zero in DONE to rearm |
| 2 | Read/write | Case count, 1 through 32 |
| 3 | Read/write | Descriptor word pointer |
| 4 | Write | Descriptor word; increments pointer |
| 5 | Read/write | Program/initializer pool word pointer |
| 6 | Write | Pool data, low 16 bits; increments pointer |
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

Each descriptor is twelve unsigned 32-bit words:

```text
external_case_id, program_base_word, program_length_words,
test_pc, next_pc, measure_pass,
initializer_base_word, initializer_count, wait_states,
pause_clocks, pause_after_clocks, flags
```

The shared staging pool has 4096 halfwords for programs and initializers. Each
initializer is three halfwords: address low 16 bits, address high 16 bits, value.
Program and initializer ranges must fit and must not overlap. `measure_pass`
counts earlier
acceptances of `test_pc` before measurement begins; it is not a loop count
inferred by the host. PCs may be any aligned 32-bit bit addresses, including
high sparse targets; equal start/end PCs are legal self-jumps. Flags are zero.
Wait states are at most `0x1fffffff`; pause duration and trigger are bounded by
the batch timeout. The transport validates these bounds before MMIO access.

Each result has 202 unsigned 32-bit words:

```text
external_case_id, status, measured_clocks, test_pc, next_pc,
next_accepted_opcode, architectural_status, start_clock,
physical_rf_shadow[0..63], actual_paused_clocks, memory_count,
(address, halfword_value)[0..63]
```

Memory pairs follow the initializer order. Unused pairs are zero, and the host
checks count, association, halfword bounds and padding before invoking the oracle.

Status 1 is busy; 2 is successful completion. Errors use bit 31. Case codes
`0x80000002`, `0x80000003` and `0x80000004` report timeout, invalid descriptor
and execution/protocol failure respectively. The batch status is sticky across
cases: a later success cannot erase an earlier failure. Terminal batch error
`0x80000002` is generic; inspect individual case codes to distinguish timeout
from descriptor or protocol failures. Diagnostic bit 8 need not survive the
terminal status assignment. A timeout's clocks
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
This sentinel representation remains a limitation: a valid register containing
that exact value is indistinguishable from an unwritten slot and fails closed.
Snapshotting excludes writes on the next-decode boundary, matching the
software bench's pre-edge observation.

## Bounded diagnostic events

The runner stores at most 512 event records per case and 16,384 per batch.
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

For a CPU/runner change that preserves the Avalon/HPS interfaces, reuse a
successful generated build and its database. The incremental helper clones
that build, refreshes the selected checkout's RTL and generated CPU payload,
and uses the existing QIP rather than regenerating Platform Designer:

```sh
bash modules/jttms10/ver/fpga/build-runner-incremental.sh \
    /path/to/fitted-build /path/to/new-build full
```

The new directory must not exist. This runs the full Quartus flow once. The
optional `map` mode is useful when diagnosing inference; following it with
`compile` can repeat analysis and is not the normal iteration path. Review
inferred memories
and final STA before programming. A changed interface or clock/reset topology
requires the full `build-runner.sh` flow. Preserving IP/database avoids their
regeneration; measure the actual map/fit/assembly/STA costs before claiming
incremental or Rapid Recompile speedup. An interrupted command is a failed
attempt even if a timing wrapper misleadingly prints exit code zero.

`run_batch.py` stages one binary payload and starts one board process for the
whole matrix. `transport.c` iterates batches, polls completion and drains
results; it performs no per-case stimulus. The binary payload starts with
`JTR3` and a little-endian 32-bit batch count. Each batch contains four
32-bit header words (`case_count`, `pool_halfword_count`, `timeout_clocks`,
`batch_flags`), twelve 32-bit words per descriptor, then the 16-bit pool words.
All integers are little-endian; batch flags are zero. JSON manifests use
`format: jttms10-fpga-batch-v2`; manifests, every batch and captures declare
`protocol_version: 2`. Mixing versions fails explicitly. The transport
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
python3 -m unittest discover -s modules/jttms10/ver/fpga -p 'test_*.py'
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


## Image/source binding and inherited-fit ROM variants

The wire protocol is unchanged by source-bound receipts. Before SSH access,
`run_batch.py` checks CPU implementation/generator fingerprints, runner RTL,
image hash and receipt identity. Timing fixtures/oracle expectations are not
hardware inputs and can change without another FPGA compilation. A historical
receipt lacking CPU fingerprints fails explicitly; refresh to a new file using
the original fitted build and matching sources.

`build-rom-update.sh` supports only main-control YAML changes regenerating
`tms10.uc` with unchanged synthesized templates, other ROMs and geometry.
It verifies and updates the fitted main-control MIF, runs CDB/assembly with
`/opt/quartus_free`, and certifies inherited placement/routing/STA separately
from a full compile. See the [README reproduction commands](README.md#source-bound-runs-and-rom-only-updates).

Use `--source-root` for the baseline oracle checkout and an explicit
`--hardware-source-root` for changed CPU microcode. A
`jttms10-fpga-rom-update-receipt-v1` additionally requires `--parent-receipt`
with the original source-bound full-fit certificate. Runtime validates source,
parent evidence, generated ROM/MIF delta, image, phase records and unique
firmware/overlay identity. Variants inherit SYSID/timestamp, so these IDs alone
cannot identify changed ROM contents. Program each distinct image through its
own verified firmware/overlay and restore baseline controls after negative
runs. This path adds no descriptor/result words or per-case host intervention.
