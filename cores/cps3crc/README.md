# CPS3CRC

`cps3crc` is a CPS3 SDRAM download-path diagnostic core. It reuses the small `test85` 65C02, text display, PLL, and SDRAM cache vehicle, but uses the CPS3 MRA layout so MiSTer downloads full CPS3 ROM images into SDRAM.

The firmware never writes to SDRAM. It runs four read-only CRC-32 rounds over the CPS3 MRA download stream:

| round | checked content | success line |
| --- | --- | --- |
| 1 | first 8 KiB of each bank | `8KB PASS` |
| 2 | first 64 KiB of each bank | `64KB PASS` |
| 3 | first 256 KiB of each bank | `256KB PASS` |
| 4 | full initialized MRA area | `FULL PASS` |

The full round checks bank0 `0x880000` bytes, bank1 `0x1000000` bytes, bank2 `0x1000000` bytes, and bank3 `0x400000` bytes. A round passes only when all four bank CRCs match the same set (`sfiiin` or `redearthn`). Mixed matches or unknown values display `DETECTED FAIL`, mark that round as red `FAIL`, and stop the test.

The reference values can be recalculated from the `jtutil sdram` bank files with:

```bash
cores/cps3crc/bin/calc_crc.py
```

The helper reads `cores/cps3/ver/<setname>/sdram_bank<0-3>.bin`, processes bytes in the 16-bit word-swapped order seen through the SDRAM cache, and prints the CRC-32 values for all firmware rounds. Use `--window` to calculate one custom byte window for all banks.

## CPU Memory Map

- `$0000-$01ff`: local work RAM.
- `$2000-$23ff`: 32x32 text RAM, CPU writable and video readable.
- `$3000`: SDRAM cache address bits `[7:0]`.
- `$3001`: SDRAM cache address bits `[15:8]`.
- `$3002`: SDRAM cache address bits `[23:16]`.
- `$3003`: latched cache read data.
- `$3004`: cache command/status. Read command bit 1 starts a read; command bit 7 aborts/clears a stuck local cache request for retry.
- `$3005`: frame IRQ/blanking register. Any access clears the latched frame IRQ.
- `$3006`: SDRAM bank/address bits `[25:24]`.
- `$c000-$ffff`: 16 KiB boot ROM.

## Screen

The screen is updated from the frame IRQ during vertical blank. The display shows the current bank being checked, each bank CRC found versus expected, the detected set, the four round status lines, and a software clock that advances one second every 60 frame IRQs. Bank rows and round rows are drawn red when the final detected result marks them wrong.

## Firmware

Rebuild the boot ROM with:

```bash
make -C cores/cps3crc/firmware
```

`hdl/boot.hex` is generated and ignored by git. `JTFRAME_BUILD_FIRMWARE` in `cfg/macros.def` makes `jtsim` and `jtcore` rebuild it before using HDL hex files.

## Validation

Useful checks:

```bash
source setprj.sh >/dev/null && jtframe cfgstr cps3crc --target=mister
source setprj.sh >/dev/null && jtframe mem cps3crc --target=mister
source setprj.sh >/dev/null && jtframe files plain cps3crc --target=mister
source setprj.sh >/dev/null && jtframe mra cps3crc
cd cores/cps3crc/ver/sfiiin
ln -sf ../../../cps3/ver/sfiiin/sdram_bank*.bin .
ln -sf ../../../cps3/ver/sfiiin/rom.bin rom.bin
cd ../../../..
source setprj.sh >/dev/null && cd cores/cps3crc/ver/sfiiin && jtsim -mister -video 20 -q
```

Do not pass `-setname` for the short preload smoke test; that enables the full SPI ROM download path and is much slower. The simulation monitor checks that the display starts, SDRAM reads begin, no SDRAM write command is issued, and the 8 KiB round reaches `PASS`; longer rounds are intended for FPGA runtime because the full active-area pass is slow in simulation.
