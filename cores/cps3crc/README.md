# CPS3CRC

`cps3crc` is a CPS3 SDRAM download-path diagnostic core. It reuses the small `test85` 65C02, text display, PLL, and SDRAM cache vehicle, but uses the CPS3 MRA layout so MiSTer downloads full CPS3 ROM images into SDRAM.

The firmware never writes to SDRAM. It continuously reads only the byte ranges initialized by the CPS3 MRA download stream and computes standard CRC-32 values for each SDRAM bank. The initialized ranges are:

- bank0: `0x000000-0x87ffff`
- bank1: `0x000000-0xffffff`
- bank2: `0x000000-0xffffff`
- bank3: `0x000000-0x3fffff`

Expected CRC-32 values are embedded for both `sfiiin` and `redearthn`:

| setname | bank0 | bank1 | bank2 | bank3 |
| --- | --- | --- | --- | --- |
| `sfiiin` | `AC19E7D7` | `0B1E3015` | `E012FA06` | `58933DC2` |
| `redearthn` | `3BA33E23` | `C5FFF13E` | `DFB96816` | `2F5B44BD` |

A set is detected only when all four bank CRCs match the same set. Mixed matches or unknown values display `DETECTED FAIL`.

## CPU Memory Map

- `$0000-$01ff`: local work RAM.
- `$2000-$23ff`: 32x32 text RAM, CPU writable and video readable.
- `$3000`: SDRAM cache address bits `[7:0]`.
- `$3001`: SDRAM cache address bits `[15:8]`.
- `$3002`: SDRAM cache address bits `[23:16]`.
- `$3003`: latched cache read data.
- `$3004`: cache command/status. Only read command bit 1 is honored by RTL.
- `$3005`: frame IRQ/blanking register. Any access clears the latched frame IRQ.
- `$3006`: SDRAM bank/address bits `[25:24]`.
- `$c000-$ffff`: 16 KiB boot ROM.

## Screen

The screen is updated from the frame IRQ during vertical blank. The display shows the current bank being checked, each bank CRC found versus expected, the detected set, and a software clock that advances one second every 60 frame IRQs. Rows are drawn red when the final detected result marks them wrong.

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

Do not pass `-setname` for the short preload smoke test; that enables the full SPI ROM download path and is much slower. A complete pass over all banks is intended for FPGA use and is too slow for a normal short simulation. The simulation monitor only checks that the display starts, SDRAM reads begin, and no SDRAM write command is issued.
