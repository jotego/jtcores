# Superman P0-039A timing diagnostic

Firmware to measure M68000 memory-access timing on the Superman Taito X
P0-039A PCB and to run the same bytes in the `taitox` core (#230). The timing
suite is described below and in [timing_protocol.md](timing_protocol.md). The
earlier boot/control images (v3–v7) that qualified the board and the PicoROM
transport are kept for reference after it.

## Timing suite (v3)

`timing_diag.s`, `timing_firmware.c` and `timing_layout.ld` build the timing
image. `python3 build_timing.py` (m68k-linux-gnu binutils and GCC) writes the
lanes `timing_*_odd_low.bin`/`timing_*_even_high.bin`/`timing_cpu.bin`, which
are not tracked in git; `timing_manifest.json` records their identity (build ID
`0x2303`, suite `taitox-p0-039a-timing-v3-low64k-1frame`).

Each case runs a matched 12-byte loop kernel (baseline, or 1/2/4 word reads or
writes to program ROM, work RAM, Y RAM and object RAM) for one discarded
transition frame and one counted frame. The PCB spread over eight frames was
0–1 loop, so one frame per case is enough. The image uses only the lower
64 KiB of each 27C010 lane: the green v1.2 PicoROM tested for A5 never sees A16.

Simulation (about 3 minutes): overlay the image with `prepare_timing.py` and run
`jtsim -load -d NOSOUND -video 100 -norotate -fast timing.cab` with `timing.cab`
set to `=100`. Work RAM `F00100` holds two 32-bit slots per case.

PCB: with the board off, load both PicoROMs at 64 KiB and capture:

```sh
python3 picorom_load.py load SUPERMAN-A10=timing_a10_even_high.bin \
    SUPERMAN-A5=timing_a5_odd_low.bin --size 64k --out <load-dir>
python3 timing_capture.py --preparation-report <load-dir>/report.json \
    --protocol-doc timing_protocol.md --output-dir <capture-dir> \
    --shelly-url http://192.168.68.52 --timeout 60 --power-on
```

Both need PyUSB and the PicoROM client in `modules/jtkcpu/ver/pcb/tools`. The
capture arms the A10 recorder at `0x0dc00`, powers the board through the Shelly,
checks the 28 marker events, retrieves the CRC-checked result frames and powers
the board off. `picorom_load.py` also offers `list`, `--xgecu` readback through a
TL866II+ and an A0–A16 `pattern` test.

Result: ROM and work RAM take 38/42/50 CPU clocks per loop for 1/2/4 accesses
on both PCB and core. X1-001 video RAM (`D0xxxx`, `E0xxxx`) takes 40/44/52 on the
PCB, reads and writes alike: the CPU only gets the RAM in one pixel clock of
every 4-pixel slot. `jttaitox_video.v` drives `vram_busy` from `hdump` and
`jttaitox_main.v` turns it into a board wait (`bus_busy` with `bus_legit`).

## Boot/control image

Build the lane images (not tracked in git) with:

```sh
python3 cores/taitox/ver/pcb_timing/build_boot.py
```

The build needs `m68k-linux-gnu-as`, `m68k-linux-gnu-ld`,
`m68k-linux-gnu-objcopy`, and `m68k-linux-gnu-objdump`. It emits:

| File | Contents |
|---|---|
| `boot_control_cpu.bin` | 256 KiB CPU-address-order image for addresses `000000–03ffff` |
| `boot_control_a10_even_high.bin` | 128 KiB even-address/high-byte lane for socket A10 / B61-09 |
| `boot_control_a5_odd_low.bin` | 128 KiB odd-address/low-byte lane for socket A5 / B61-07 |
| `boot_manifest.json` | Image sizes, SHA-256 values, and reserved-window identity |

The first boot performs a stackless fill/read and inverse-fill/read check over
all 16 KiB of work RAM. Only after that passes does it set SP to `F03FFE` and
initialize the display. It clears the X1-001 sprite/Y RAM, hides every unused
sprite outside the screen, sets a fixed palette, and draws a two-row strip of
game-graphics tiles over a blue backdrop. Sprite LUT entries use the active
Superman page: palette/X at `E02400+2*n`, code at `E02000+2*n`, and Y at
`D00000+2*n`. Matching source entries are also written at `E00400+2*n` and
`E00000+2*n`, so a frame-end source-to-active buffer copy preserves the test
screen. Unused entries are hidden in both LUT banks. The backdrop changes after
32 combined VBL interrupt entries: green means level 2 was observed, red means
level 6 was observed, and white means both levels were observed. Cyan indicates
a level-4 C-chip interrupt was observed; level 4 is counted separately and does
not satisfy the VBL threshold. Magenta indicates a fatal path. The foreground
services the watchdog while waiting and idling. The W5100307A sheet 2 decode
maps active-low IPL1/VBL to level 2, active-low IPL2/C-chip to level 4, and
both active to level 6; IPL0 is pulled high. Level 2 writes `0x0010` to the
VBL clear decode at `0x600000`; level 4 writes `0x0010` to the C-chip clear
decode at `0x300000`; level 6 clears both. All accepted handlers also service
the watchdog at `0x400000` with word value `0x0010`. This value matches the
stock Superman writes in the MAME driver. These are address-decode writes, not
C-chip register or RAM accesses. Counters for levels 2, 4, and 6 are at
`F00000`, `F00002`, and `F00004`. Thirty two combined level-2/level-6 entries
prove only that handlers ran; they do not prove a stable per-frame cadence.
This stage makes no measurements and does not access sound or C-chip
registers/RAM.

The image emits A10 PicoROM boot markers by reading the mapped
high-lane addresses:

| Read | Meaning |
|---|---|
| `0x03be02` | SR set to `0x2700`; reset entry reached (`0x01`) |
| `0x03be04` | First watchdog write at `0x400000` returned (`0x02`) |
| `0x03be06` | First backdrop write at `0xB003E0` returned (`0x03`) |
| `0x03be20` | Stackless work-RAM check passed (`0x10`) |
| `0x03be22` | X1-001 control screen initialized (`0x11`) |
| `0x03be24` | 32 combined level-2/level-6 VBL handler entries observed (`0x12`) |
| `0x03be3e` | Fatal exception or RAM test failure (`0x1f`) |

The capture profile ID is `superman-p0-039a-boot-v5`, bound to the full A10/A5
image SHA-256 readbacks in `boot_manifest.json`. The required boot-only success
order is exactly `01 02 03 10 11 12`, each once. Marker `01` is read immediately
after setting SR; `02` follows the first watchdog write; `03` follows the first
backdrop write. This brackets the two earliest board writes so a capture can
distinguish a reset/transport failure from a failure at either write.
`1f` is an error marker and is never a successful terminal state. These markers
do not carry a suite identity, sample counts, elapsed time, or checksums; the
full diagnostic must use the separate framed results protocol. A capture must
start with `01`; require exactly `01 02 03 10 11 12`. Any out-of-order,
duplicate, or missing marker before `12`, or any `1f`, fails boot qualification.
A timeout before `12` is a failed
qualification; after `12`, the image intentionally idles and emits no more
markers. Capture records must be bound to the full image SHA-256 values in
`boot_manifest.json`. Do not infer interrupt cadence from this stage.

For this P0-039A board, the low 256 KiB CPU window is the A10/A5 ROM pair. A10
is the even/high-byte lane and A5 is the odd/low-byte lane. The original
Superman region program socket at A3 is left installed. The byte-lane images
are padded to 128 KiB each. CPU address bytes `0x03b800–0x03bfff` are reserved
as the A10 PicoROM communication window; the corresponding A10 physical range
is `0x01dc00–0x01dfff`. This interval remains `0xff` in the A10 image. Keep
code, constants, and any full-suite result image outside that window.

The SHA-256 values for the generated control image are recorded in
`boot_manifest.json`. The checked-in images are generated from
`boot_control.s` by `build_boot.py`; `tasks/jtcores-230/artifacts/boot-control/boot_control.lst`
is the assembler listing from the current build.

The first jtsim validation used v1, whose image hashes are archived in
`tasks/jtcores-230/artifacts/boot-control-jtsim/boot_manifest_v1.json`. It
reached the red IRQ6 status but rendered no sprite tiles. Inspection of
`jtkiwi_obj` showed the active page's LUT address and word order were wrong in
v1; v2 corrected both and rendered glyphs in simulation. V3 also mirrors the
test entries into the source bank to tolerate a physical frame-end buffer
copy. The v3 physical attempt emitted `01 10 11 01`, with no `12`; the board
was left off and the A5 USB readback was absent. V4 added decoded watchdog
service and level-specific interrupt acknowledgements based on W5100307A sheet
2. The v4 physical attempt timed out with zero bytes/events at about 12.8 W;
the board was left off. V5 moves the reset marker before the first watchdog
write and adds markers `02`/`03` after that write and the backdrop write.
Captures and images from all versions and both failed attempts are retained
under `tasks/jtcores-230/artifacts/`; use the v5 capture profile and validate
the physical marker/display result before timing work.

## Physical recovery boundary

The v3 and v4 physical attempts were reported with the board left powered off;
v4 produced no bytes/events. V5 has not been programmed by this executor.
Before any future
hardware trial, retain and label the original A10/A5 ROM pair and save full
readbacks of both PicoROM images. Keep the original ROMs as the recovery image.
If the diagnostic does not show the control screen or the ordered stage
markers, stop and restore the original A10/A5 ROMs with the board powered off;
do not begin the timing suite. The A10 ROM must use the jumper-selected
27C1001 mapping documented for P0-039A and the PicoROM mask must be `0x1ffff`.

## V6 transport diagnostic

V6 keeps the reviewed v5 markers `01 02 03 10 11 12`, then reads CPU address
`0x03BE08` exactly 16 times. This is A10 physical byte address `0x01DF04` and
event address `0x104`; each read returns heartbeat marker `04`. The complete
byte sequence is those six boot markers followed by sixteen `04` bytes, for 22
events total. The capture must see exactly 22 final event-ring entries, zero
drops, and no stopped/overflow flag. This fits the 31-entry ring and the
32-byte raw FIFO. Fatal marker `1f`, missing or reordered markers, duplicates
outside the 16 heartbeat reads, or timeout before all 22 bytes fail
qualification. Capture identity is bound to both full lane readback hashes in
`boot_manifest_v6.json`.

The heartbeat delay uses DBRA counts `0xffff` and `0x3fff`, serviced by a
watchdog write between loops. At the nominal 8 MHz CPU clock the calculated
delay is about 102.4 ms per heartbeat, plus instruction and IRQ overhead. This
is pacing only; do not infer CPU timing from host poll intervals. After 16
heartbeat reads, the backdrop changes to gray and the firmware enters
watchdog-serviced idle without further PicoROM reads. The protocol note is
`boot_v6_protocol.md`.

## V7 lower-window discriminator

V7 keeps the complete v6 boot and heartbeat behavior while moving every
PicoROM marker read into the lower communication window. Its CPU window is
`0x01B800–0x01BFFF`, mapped to A10 physical `0x00DC00–0x00DFFF`; stage reads
use CPU addresses `0x01BE02/04/06/20/22/24/3E`, and the 16 paced heartbeat
reads use `0x01BE08`. Their A10 physical addresses are `0x00DF01/02/03/10/11/12/1F`
and `0x00DF04`, respectively. The event addresses remain `0x101/102/103`,
`0x110/111/112`, and sixteen `0x104` entries because offsets within the
1 KiB window did not change. V7 leaves the former v6 upper A10 window
`0x01DC00–0x01DFFF` unused. See `boot_manifest_v7.json` and
`boot_v7_protocol.md`; captures require the distinct profile
`superman-p0-039a-boot-v7` and full A10/A5 readback hashes.
