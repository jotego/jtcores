# Timing image and capture protocol

Build the timing image from the project root with:

```sh
python3 cores/taitox/ver/pcb_timing/build_timing.py
```

The builder emits a 256 KiB CPU-address image, a 128 KiB A10 even/high-byte
lane, a 128 KiB A5 odd/low-byte lane, an assembler listing, and
`timing_manifest.json`. It checks that the assembled code fits below the
PicoROM window, all seven kernels are contiguous 12-byte blocks, the sample
array fits in work RAM, the CPU image CRC reproduces, and the A10 communication
range remains `FF`.

The primary matrix has 22 distinct runs: one shared baseline, ROM reads, and
1/2/4 reads and writes for work RAM, the object-RAM tail, and Y RAM. Twelve
supplemental runs compare hidden sprite-entry code words in the source and
active object banks. Entry 511 is hidden by setting its X and Y coordinates
offscreen before measurement. The shared baseline repeats last. Each run keeps
one transition interval internally and exports the next eight frame loop
counts. A single 12-byte baseline kernel is used for every comparison.

The image initializes the X1-001 using the boot-v4 pattern: mirrored source
and active sprite LUTs, hidden unused entries, a two-row strip of tile codes
1–32 in eight palette groups, and a blue backdrop. The backdrop shows cyan
while only IRQ4 has been seen, green for IRQ2, red for IRQ6, white after suite
completion, and magenta for a fatal path. Screen setup and status writes are
outside the measured kernels.

## Lower 64 KiB layout (v2)

Version 2 (`taitox-p0-039a-timing-v2-low64k`, build ID `0x2302`) and version 3
(`taitox-p0-039a-timing-v3-low64k-1frame`, build ID `0x2303`, one steady frame
per case after the PCB showed a 0–1 loop spread over eight frames) use only the
lower 64 KiB of each 27C010 lane, because the green v1.2 PicoROM tested for A5
never sees A16. The code and vectors are unchanged; the PicoROM window moved
from A10 physical `0x1dc00` (CPU `0x03b800–0x03bfff`) to `0x0dc00` (CPU
`0x01b800–0x01bfff`), and the ROM-read kernels read CPU `0x010000` instead of
`0x020000`. The builder rejects any data placed above CPU `0x01ffff` and any
listing reference to CPU `0x020000–0x03ffff`. Load both PicoROMs with
`picorom_load.py load --size 64k` (addr_mask `0xffff`); the comms detector
then sees A16 as 0, which matches the `0x0dc00` window.

## PicoROM event trace

Start the PicoROM event recorder at physical A10 address `0x0dc00` before the
CPU executes the image. The timing image emits marker `01` at reset, `10`
after RAM qualification, and `11` after clearing pending IRQ latches and just
before enabling IRQs. It then emits 24
distinct fixed-count markers from CPU reads `0x01bc40–0x01bc6e`, followed by
completion marker `12`. The recorder should contain 28 events in total, with
low-nine-bit IDs `101, 110, 111, 020–037, 112` in that order. Snapshot the stable event header
and ring before asking for result frames: the later TX frames can overwrite
ring entries. Require active capture, zero dropped bytes, and
`capture_stopped=false`.

The fixed-count measurements bracket DBRA loops with N=0, 128, 256, and 512,
three times each. N=0 skips DBRA; for N>0 the CPU instruction path costs
`10*N + 4` cycles before observer overhead. Fit the slope using positive N;
the N=0 brackets measure marker overhead. Event timestamps are RP2040
microseconds at 1 us resolution, so report the fitted slope in microseconds
per iteration and do not label it a CPU edge or cycle measurement.

## Framed results

After the event ring is saved, send command byte `0x47` (`G`) through the
PicoROM RX path. The CPU sends version-2, 27-byte frames through A10 reads at
`0x01be00 + 2*byte`; every frame has sync `A5 5A`, build ID `0x2303`, a
monotonic 16-bit sequence, 16-byte payload, CRC16-CCITT, and a matching RX
sequence ACK before the next frame.

Flags identify the payload:

| Flag | Payload |
|---|---|
| `01` | image CRC32, suite CRC32, run ID, run/sample counts |
| `02` | compact-sample CRC32, backing sample range, byte count, data-frame count |
| `04` | IRQ2 count, IRQ4 count, IRQ6 count, selected sample level |
| `10` | four big-endian 32-bit frame loop counts |
| `20` | terminal CRC32 and final sample/frame counts |

The stream has 74 frames: three metadata frames, 70 data frames, and one
terminal frame. The result CRC covers the 280 exported samples in wire order;
the transition interval in slot zero of each nine-word run record is omitted.

Save `Pico.poll()` response bytes as one concatenated frame stream. Save
`Pico.events(base)` output as JSON with these fields:

```json
{
  "magic": "PICO",
  "active": 1,
  "dropped_bytes": 0,
  "capture_stopped": false,
  "count": 28,
  "events": [
    {"sequence": 0, "address": 257, "time_us": 10}
  ]
}
```

Then validate and decode both inputs:

```sh
python3 cores/taitox/ver/pcb_timing/timing_decode.py \
  --frames timing_frames.bin --events timing_events.json
```

The decoder verifies image/suite identity, packet sequence and CRCs, complete
run/sample inventory, IRQ totals and a single VBlank sample source (and reports
whether it matches the P0-039A level-6 expectation), event recorder
health/order, the fixed-marker pairs, and final sample integrity. IRQ2 is
VBlank, IRQ4 is the C-chip source, and IRQ6 combines both lines. IRQ4 events are
acknowledged and counted but are excluded from the frame sample cadence. The
firmware acknowledges IRQ2 with `0x0010` at `0x600000`, IRQ4 with `0x3000` at
`0x300000`, and IRQ6 with both writes. It services the board watchdog at
`0x400000` on every interrupt and during long waits. These fixed handler writes
are outside the timed kernels but remain part of the observed per-frame loop
count. The decoder rejects captures where IRQ2 and IRQ6 both sample because
that mixes two VBlank source levels within the matrix. If standalone IRQ4s are
present, the capture remains transport-valid but the decoder marks per-frame
comparison as unqualified because IRQ4 handler overhead is not allocated to
individual samples. Each vector masks IPL7 immediately on entry, before
register saves, to prevent higher-level IRQ nesting from corrupting shared
sample/redirect state; RTE restores the interrupted SR.
