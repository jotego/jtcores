# SiDi128 CAB input stream

SiDi128 enables `JTFRAME_CAB_STREAM` in its target defaults. Other targets do
not instantiate this interface. The target advertises `FEAT_CAB_STREAM`
(`0x00020000`), `FEAT_CAB_DIPS` (`0x00040000`) and the dump-barrier protocol
(`0x00080000`) to the MCU. Actual dump support also requires the core's valid
Save NVRAM `R<length>,...` entry. This is independent
of debug/release build selection. Input-only version-1 scripts and the legacy
status/PUSH SPI commands remain supported.

The host exporter `jtframe-cab-pack input.cab output.jtcab [frames]` shares
`verilator/cabinet.cpp` with simulation. It produces duration/state runs for a
small FPGA queue; firmware streams them from SD over existing user-I/O SPI.
See firmware `doc/ftp-cab.md` for user commands and operational limitations.

## Packed file

All integers are unsigned little-endian. The header is 32 bytes:

| Offset | Size | Value |
| --- | --- | --- |
| 0 | 8 | Magic `JTCAB01`, `JTCAB02` or `JTCAB03` followed by NUL |
| 8 | 4 | Version 1, 2 or 3, matching magic |
| 12 | 4 | Total frames, 1..0x7fffffff |
| 16 | 4 | Event count, at least 1, no greater than frames |
| 20 | 4 | Versions 1/2: zero; version 3: number of requested dumps |
| 24 | 4 | CRC-32 of payload, polynomial 0xedb88320, initial/final XOR 0xffffffff |
| 28 | 4 | Header size, 32 |

Version 1 has `event_count` eight-byte records: duration (positive uint32),
then logical inputs (uint32). Versions 2/3 have twelve-byte records: duration,
logical inputs with DIP flag, then full 32-bit DIP value. Durations sum exactly
to total frames. Extra or
truncated data, invalid masks and CRC mismatches are errors before game reset.

Logical bits match the existing CAB schema:

| Bits | Inputs |
| --- | --- |
| 0, 1, 2, 3 | P1 coin, service, P1 start, P2 start |
| 4..7 | P1 right, left, down, up |
| 8..10 | P1 b1, b2, b3 |
| 11, 12, 13 | Test, reset, P2 coin |
| 14..17 | P2 right, left, down, up |
| 18..20 | P2 b1, b2, b3 |
| 21 | Version 2: apply DIP value; version 1: must be zero |
| 22 | Version 3: request a dump on each frame of this run; versions 1/2: zero |
| 23..31 | Reserved, must be zero |

The exporter selects version 2 only when a script contains DIP statements. It
carries the effective DIP through subsequent runs, loops and idle padding.
An unset flag means preserve the current override, not clear it. The first
statement may be at frame zero or later; until then the configured DIP is used.
Zero and 0xffffffff are valid values. Dump scripts select version 3. The header
dump count must equal the sum of durations marked with bit 22; idle padding
never repeats this flag. `cheat` still fails preflight; tracing is only a marker.

These are canonical CAB bits, distinct from raw immediate joystick port masks.
Injection in `jtframe_joysticks` bypasses physical rotation/player swapping
while preserving beta locking and normal core direction reordering.

## SPI commands

Commands use the existing user-I/O chip select and byte transfer conventions.
MCU commands are serialized outside network callbacks. Payloads are LE32 unless
specified; ARM/PUSH/START apply only after their complete payload arrives.

| Opcode | Payload | Operation |
| --- | --- | --- |
| 0x81 | Clock out 32 response bytes | Read coherent status snapshot |
| 0x82 | Total frames, total events, one reset-flags byte | ARM new epoch; reset flag bit 0 holds game reset |
| 0x83 | Epoch, event sequence, duration, logical mask | Append run to FIFO using available credit |
| 0x84 | Epoch | START, consume first run, preload frame-zero inputs, release ARM reset |
| 0x85 | One dummy guard byte | STOP, release inputs/reset, empty FIFO |
| 0x86 | Epoch, sequence, duration, mask/flag, DIP value | Append version-2 run, same credit and boundary rules |
| 0x87 | Clock out 40 response bytes | Extended coherent status, protocol 2 |
| 0x88 | Epoch, dump sequence | Acknowledge completed checkpoint; resume on a raster boundary |
| 0x89 | Clock out 64 response bytes | Dump-capable coherent status, protocol 3 |

The guard byte allows the STOP command to cross the SPI/system clock boundary
before chip select rises. Firmware verifies IDLE/neutral readback afterwards.
No other flags are valid. The FPGA owns frame timing; SPI arrival is not the
input timestamp.

The 32-byte legacy status response is latched once per request. Extended status
adds eight bytes and sets the protocol byte to 2; dump status extends to 64 bytes
with protocol 3:

| Offset | Size | Value |
| --- | --- | --- |
| 0, 1 | 1 each | Magic 0xca, protocol 1 |
| 2, 3 | 1 each | State, error |
| 4 | 4 | Epoch (increments on ARM) |
| 8 | 4 | Completed CAB frames |
| 12 | 4 | Accepted events |
| 16 | 4 | Applied events |
| 20 | 4 | Independent native raster counter |
| 24, 25 | 1 each | Queued events, free credits (capacity 8) |
| 26 | 2 | Reserved, zero |
| 28 | 4 | Current logical inputs |
| 32 | 4 | Extended only: last scripted DIP value |
| 36 | 1 | Extended only: DIP override currently effective (0 or 1) |
| 37 | 3 | Extended only: reserved, zero |
| 40 | 4 | Protocol 3: dump request sequence (starts at 1) |
| 44 | 4 | Protocol 3: requested CAB frame |
| 48 | 4 | Protocol 3: raster at request |
| 52 | 12 | Protocol 3: reserved, zero |

State values: IDLE=0, ARMED=1, RUNNING=2, DONE=3, ERROR=4,
DUMP_WAIT=5, RESUME_WAIT=6.
Errors: underrun=1, stale epoch=2, sequence=3, full=4, invalid event=5,
length/totals=6, state=7. ARM clears the error; STOP retains diagnostics.
Sequence starts at zero;
every accepted PUSH increments it. Counters wrap at 32 bits; compare epochs
within one MCU/FPGA configuration and acquire fresh status after reloading.

START preloads frame 0 without consuming a raster edge. Each synchronized
native `LVBL` rising edge completes one script frame and decrements the current
run. On its last edge the next queued run becomes active, or the script ends
at exactly total_frames with neutral inputs. The current run is held outside
the FIFO, so credits describe queued future events. Firmware checks credits
before refill and polls progress about every 2 ms. Underflow or protocol errors
release inputs/reset rather than silently delaying a boundary.

DIP updates occur on the same pop/boundary as inputs. A value remains in effect
until another statement during playback. `jtframe_mist` selects the full 32-bit
CAB DIP input directly, leaving packed status and ARC/OSD settings unchanged.
Completion, STOP or errors release the override; diagnostic readback retains
the last value until ARM clears it. Every new epoch starts without an override.
A DIP change does not automatically pulse reset.

On a marked frame the FPGA enters DUMP_WAIT, retains inputs/DIPs and requests
pause. CAB frame/duration counters hold while independent raster count advances.
MCU waits two rasters, reads the normal Save NVRAM index -1 data in checked
2,048-byte chunks and publishes RAM/JSON files. Only then does it ACK the exact
epoch/sequence. RESUME_WAIT retains pause until a native boundary; that edge
releases pause without consuming the pending CAB frame. A duration-N dump run
requests N independent dumps. STOP/errors release pause and all overrides.

These are explicit **best-effort debug barriers**, without a CPU-quiescence
acknowledgement. Boot/raster-sensitive games may advance during the held CAB
cursor. Sidecars declare unverified pause and retain request/start/end rasters;
do not infer continuous game/CPU-frame progress across a barrier. Strict capture
and regression pause synchronization remains future work.

Outside dump barriers the timeline runs unpaused, including boot with masked CPU IRQs.
Independent raster count continues outside playback. There is no accepted-IRQ
or effective-pause indication yet, and no screenshot scheduler. Do not infer
CPU quiescence or live-frame identity from CAB state.

## Resource and verification evidence

The queue is eight 96-bit records (96 bytes), implemented with registers; the
dump flag uses a spare bit and does not grow the queue.
A dump-capable Mikie SiDi128 fit used 2,259 logic elements / 1,632 registers
for the complete controller and zero memory bits. The DIP-capable Trojan fit
used 1,922 logic elements / 1,431 registers; the input-only predecessor used
64 bytes / 1,552 logic elements. These are different observed fits, not fixed
per-feature costs. Resource/timing results depend on the core.

```sh
simunit-all.sh --only jtframe_cab_stream,jtframe_joysticks
make -C modules/jtframe/verilator/tests/cabinet test
```

Tests cover frame-zero preload, exact duration boundaries, completion, queue
wrap/refill, stale/invalid events, overflow/underrun, physical-input exclusion,
player mapping, beta locking, parser iteration equivalence and export errors.
Hardware validation includes a 2,000-frame Trojan `reg.cab` run and 1,200
consecutive one-frame events through the same eight-entry queue. Firmware tests
cover malformed files, ownership/file guards, acknowledged stop, disconnect,
Ctrl-C and a suspended client whose lease expires without resuming inputs.
Dump-specific tests cover frame-zero/repeated/final checkpoints, exact
acknowledgements, retained duration, cancellation, file capability/count
preflight, directory ownership and checked PC downloads. Mikie hardware tests
retrieved nonconstant 2,048-byte VRAM dumps at scheduled gameplay checkpoints;
the boot checkpoint was allowed to be blank and marked pause-unverified.
