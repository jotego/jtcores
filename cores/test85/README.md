# TEST85

`test85` is a small bring-up core for checking the CPS3-style 85.909 MHz clocking and SDRAM cache path on MiSTer without the full CPS3 core.

The core is intentionally ROM-less. Firmware, work RAM, screen text storage, and font data are FPGA BRAM contents. `cfg/mem.yaml` defines one writable SDRAM cache lane with flush support.

Current stage:

- Uses `jtframe_pll5369`, `JTFRAME_SDRAM96`, and a 1 kB burst cache lane.
- Instantiates `jt65c02` with a generated 16 KiB boot ROM image from `firmware/boot.s`.
- Provides 512 bytes of local CPU work RAM at `$0000-$01ff` for zero page and stack use.
- Displays a 256x224 text screen through `jtframe_vtimer` and `jtframe_tilemap`.
- Drives the SDRAM cache lane from CPU-visible registers and shows the loop status on screen.

## CPU memory map

- `$0000-$01ff`: local work RAM.
- `$2000-$23ff`: 32x32 text RAM, CPU writable and video readable.
- `$3000`: cache address bits `[7:0]`.
- `$3001`: cache address bits `[15:8]`.
- `$3002`: cache address bits `[23:16]`.
- `$3003`: cache write data on writes, latched cache read data on reads.
- `$3004`: cache command on writes and status on reads.
- `$c000-$ffff`: 16 KiB boot ROM.

`$3004` write commands are bit-coded: bit 0 starts a cache write, bit 1 starts a cache read, and bit 2 starts a cache flush. `$3004` read status uses bit 0 as the latched operation-done flag, bit 1 as busy, bit 2 as live flushing, and bit 3 as latched flush-done.

## Firmware

`firmware/boot.s` clears the text RAM, prints `TEST85`, then repeatedly:

1. Writes a deterministic byte pattern to the cache lane.
2. Flushes the dirty cache line to SDRAM.
3. Reads `$000400` to evict the single 1 KiB cache block.
4. Reads the original address back through the cache and compares it.
5. Prints `PASS ITER xx` or `FAIL ITER xx` on the text screen.

Rebuild the boot ROM manually with:

```bash
make -C cores/test85/firmware
```

`hdl/boot.hex` is generated and ignored by git. The Makefile assembles with `asl`, emits Intel HEX with `p2hex`, pads the `$c000-$ffff` image with `objcopy`, and writes one byte per line for `jtframe_ram`. `JTFRAME_BUILD_FIRMWARE` in `cfg/macros.def` makes `jtsim` and `jtcore` run this Makefile before they link HDL hex files.

## Validation

The Stage 3 RTL and firmware were checked with:

```bash
source setprj.sh >/dev/null && jtframe cfgstr test85 --target=mister
source setprj.sh >/dev/null && jtframe mem test85 --target=mister
source setprj.sh >/dev/null && jtframe files plain test85 --target=mister
source setprj.sh >/dev/null && modules/jtframe/bin/lint-one.sh test85 -mister
```
