# Superman P0-039A boot transport diagnostic v6

V6 retains the reviewed v5 boot path and does not alter production RTL. Its
early markers remain `01 02 03 10 11 12` with the same meanings recorded in
`README.md`. After marker `12`, it emits sixteen heartbeat reads and then idles
with watchdog service. It does not loop the heartbeat or emit an end byte.

| Marker | CPU read address | A10 physical byte address | Meaning |
|---|---:|---:|---|
| `01` | `0x03BE02` | `0x01DF01` | Reset entry after setting SR |
| `02` | `0x03BE04` | `0x01DF02` | First watchdog write returned |
| `03` | `0x03BE06` | `0x01DF03` | First backdrop write returned |
| `10` | `0x03BE20` | `0x01DF10` | Work RAM test passed |
| `11` | `0x03BE22` | `0x01DF11` | Control display initialized |
| `12` | `0x03BE24` | `0x01DF12` | 32 combined level-2/level-6 IRQ entries observed |
| `04` × 16 | `0x03BE08` | `0x01DF04` | Finite transport heartbeat |
| `1F` | `0x03BE3E` | `0x01DF1F` | Fatal path; failure |

The physical A10 `CommsStart` window is `0x01DC00–0x01DFFF`; the corresponding
CPU window is `0x03B800–0x03BFFF`. The full CPU window remains `0xFF` in the ROM
image and is serviced by the PicoROM communication overlay. V6 expects the
complete byte sequence `01 02 03 10 11 12` followed by exactly sixteen `04`
bytes. A fatal byte, wrong order, duplicate boot stage, missing heartbeat, or
timeout before all 22 bytes fails qualification.

The event recorder must finish with exactly 22 events, zero dropped bytes, and
no stop/overflow indication. Expected event addresses are `0x101, 0x102,
0x103, 0x110, 0x111, 0x112`, then sixteen `0x104` events. This is below the
31-entry event ring capacity and the 32-byte raw FIFO bound. Preserve the full
A10/A5 readbacks and bind their SHA-256 values from `boot_manifest_v6.json` to
the capture. `CommsStart` overlays A10 SRAM and `CommsEnd` does not restore it;
the capture tool must snapshot events before ending capture and retain USB
connection while relying on volatile image contents.

The heartbeat uses two DBRA delays initialized to `0xFFFF` and `0x3FFF`: 65,535
and 16,383 taken branches, followed by each loop's 14-cycle exit. At the
nominal 8 MHz CPU clock and ten cycles per taken DBRA branch, this is 819,208
cycles or about 102.4 ms, plus surrounding instruction and interrupt overhead.
This is firmware pacing for transport observation, not a physical timing
result or a claim about interrupt cadence. The watchdog is serviced between
the delay intervals. After the six boot stages and sixteen heartbeat reads,
the backdrop becomes gray and execution stays in watchdog-serviced idle with
no more PicoROM reads.

`detect_pc` and `bus_state`, when available from the configured A10 diagnostic
service, are supplemental diagnostic snapshots only. They are not substitutes
for the marker/event sequence and their semantics must be recorded from the
active POG firmware before drawing conclusions.
