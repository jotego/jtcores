# TEST85

`test85` is a small bring-up core for checking the CPS3-style 85.909 MHz clocking and SDRAM cache path on MiSTer without the full CPS3 core.

The core keeps CPU firmware, work RAM, screen text storage, and font data in FPGA BRAM. The MiSTer MRA downloads a small data-only payload into SDRAM so the built-in firmware can verify the download path through the SDRAM cache lane. Downloaded bytes are never used as CPU executable code.

Current stage:

- Uses `jtframe_pll5369`, `JTFRAME_SDRAM96`, and a 1 kB burst cache lane.
- Instantiates `jt65c02` with a generated 16 KiB boot ROM image from `firmware/boot.s`.
- Provides 512 bytes of local CPU work RAM at `$0000-$01ff` for zero page and stack use.
- Displays a 256x224 text screen through `jtframe_vtimer` and `jtframe_tilemap`.
- Uses a CPU-writable 32x32 text RAM and a fixed `font0.hex` BRAM adapter for the character layer.
- Drives the SDRAM cache lane from CPU-visible registers and shows the cache and ROM-download status on screen.
- Latches the `LVBL` falling edge in `jttest85_main` with `jtframe_edge` to generate one maskable CPU interrupt per frame.
- Adds a `SIMULATION`-only monitor that fails `jtsim` if `TEST85`/`PASS CACHE`/`PASS ROM` are not written or if cache write/read/flush activity is missing.

## CPU memory map

- `$0000-$01ff`: local work RAM.
- `$2000-$23ff`: 32x32 text RAM, CPU writable and video readable.
- `$3000`: cache address bits `[7:0]`.
- `$3001`: cache address bits `[15:8]`.
- `$3002`: cache address bits `[23:16]`.
- `$3003`: cache write data on writes, latched cache read data on reads.
- `$3004`: cache command on writes and status on reads.
- `$3005`: frame IRQ/blanking register. Any access clears the latched frame IRQ. Reads return bit 0 as the IRQ latch and bit 1 as live vertical blank.
- `$c000-$ffff`: 16 KiB boot ROM.

`$3004` write commands are bit-coded: bit 0 starts a cache write, bit 1 starts a cache read, and bit 2 starts a cache flush. `$3004` read status uses bit 0 as the latched operation-done flag, bit 1 as busy, bit 2 as live flushing, and bit 3 as latched flush-done.

## SDRAM download map

- `$000000-$00003f`: 64-byte MRA payload generated from `firmware/test85.s`.
- `$001000-$00101d`: firmware-generated cache stress writes for the 30 cache-test passes.
- `$001400`: cache eviction read used by the cache stress test.

The expected byte table is shared through `firmware/payload.inc`; `firmware/test85.s` emits it into the MRA payload, and `firmware/boot.s` includes the same table in the built-in boot ROM for comparison.

## Video

`jttest85_video` uses the same 256x224 `jtframe_vtimer` constants as `jtbubl_video`. The text layer is a no-scroll `jtframe_tilemap` with `PALW=1` and `BPP=1`; bit 7 of each text RAM byte selects the foreground color, while bits `[6:0]` hold the ASCII character code. `jttest85_font` adapts the tilemap ROM address to `font0.hex`, where ASCII `$20` is stored at font index zero. Non-printable codes map to the blank space glyph.

The tilemap pixel output is driven straight to RGB without a colmix module: background is black, palette 0 foreground is white, and palette 1 foreground is red.

`hdl/font0.hex` is a symlink to the shared `modules/jtframe/bin/font0.hex` asset so both synthesis and `jtsim` find the same fixed font contents.

## Firmware

`firmware/boot.s` enables maskable interrupts after reset. Each frame IRQ clears the `$3005` latch, waits for vertical blank, and runs at most one test phase:

1. On the first IRQ, clears text RAM and prints `TEST85` plus the loop label.
2. Runs the cache stress test once per frame for 30 successful iterations.
3. Writes a deterministic byte pattern to the cache lane at `$001000+iteration`.
4. Flushes the dirty cache line to SDRAM.
5. Reads `$001400` to evict the single 1 KiB cache block.
6. Reads the original address back through the cache and compares it.
7. Prints `PASS CACHE xx` in white and advances to the next frame, or prints `FAIL CACHE xx` in red and stops testing until reset.
8. After 30 cache passes, reads `$000000-$00003f` through the cache lane and compares the downloaded payload against the built-in expected table.
9. Prints `PASS ROM 3f` in white, or `FAIL ROM xx` in red with the failing byte index, and stops testing until reset.

Each cache handshake wait has a finite timeout, so a missing `cpu_ok` or `cpu_flush_done` reaches the firmware FAIL path instead of spinning forever.

Rebuild the boot ROM manually with:

```bash
make -C cores/test85/firmware
```

`hdl/boot.hex` is generated and ignored by git. The Makefile assembles with `asl`, emits Intel HEX with `p2hex`, pads the `$c000-$ffff` image with `objcopy`, and writes one byte per line for `jtframe_ram`. `JTFRAME_BUILD_FIRMWARE` in `cfg/macros.def` makes `jtsim` and `jtcore` run this Makefile before they link HDL hex files.

## SignalTap

`cfg/macros.def` enables `JTFRAME_SIGNALTAP` and `MISTER_DEBUG_NOHDMI` for the MiSTer build. `jtcore` appends `syn/signaltap.qsf`, which loads `syn/stp1.stp` from the generated `cores/test85/mister` Quartus project.

The SignalTap file samples a kept 64-bit `st85_tap` register in `jttest85_game` plus the cache controller `flushing` signal. The tap register is clocked by the main game clock and packs the CPU-facing cache lane as follows:

- `[23:0]`: `cpu_addr`.
- `[31:24]`: `cpu_din`.
- `[39:32]`: `cpu_data`.
- `[40]`: `cpu_rd`.
- `[41]`: `cpu_we`.
- `[42]`: `cpu_ok`.
- `[43]`: `cpu_flush`.
- `[44]`: `cpu_flushing`.
- `[45]`: `cpu_flush_done`.
- `[46]`: `text_we`.
- `[47]`: `LVBL`.
- `[48]`: `rst`.
- `[56:49]`: `cache_status`.
- `[57]`: `cen6`.
- `[58]`: `pxl_cen`.
- `[59]`: `pxl2_cen`.
- `[60]`: `LHBL`.
- `[61]`: `HS`.
- `[62]`: `VS`.
- `[63]`: `text_din[7]`, set when firmware writes red FAIL text.

## Validation

The Stage 4 RTL and firmware were checked with:

```bash
source setprj.sh >/dev/null && jtframe cfgstr test85 --target=mister
source setprj.sh >/dev/null && jtframe mem test85 --target=mister
source setprj.sh >/dev/null && jtframe files plain test85 --target=mister
source setprj.sh >/dev/null && modules/jtframe/bin/lint-one.sh test85 -mister
source setprj.sh >/dev/null && jtframe mra test85
source setprj.sh >/dev/null && cd cores/test85/ver/game && jtsim -mister -setname test85 -video 90 -q
```

For the simulation frame check, inspect `cores/test85/ver/game/frames/frame_00085.jpg`; it should show the `TEST85`, cache-loop status, and `PASS ROM 3f` text.
