# CPS3CRC

`cps3crc` is a CPS3 SDRAM download-path diagnostic core. It reuses the small `test85` 65C02, text display, PLL, and SDRAM cache vehicle, but uses the CPS3 MRA layout so MiSTer downloads full CPS3 ROM images into SDRAM.

The firmware never writes to SDRAM. It continuously reads the first 8 KiB initialized by the CPS3 MRA download stream in each SDRAM bank and computes standard CRC-32 values. The checked range is `0x000000-0x001fff` for all four banks.

Expected CRC-32 values are embedded for both `sfiiin` and `redearthn`:

| setname | bank0 | bank1 | bank2 | bank3 |
| --- | --- | --- | --- | --- |
| `sfiiin` | `3DEEA694` | `C7FFDE8C` | `542050D0` | `FBCCEB98` |
| `redearthn` | `32616815` | `99B7FBB8` | `836D3B95` | `F34A940E` |

A set is detected only when all four bank CRCs match the same set. Mixed matches or unknown values display `DETECTED FAIL`.

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

Do not pass `-setname` for the short preload smoke test; that enables the full SPI ROM download path and is much slower. The firmware checks only the first 8 KiB of each bank. The simulation monitor reports each bank completion, independently checks the captured CRC against the `sfiiin` and `redearthn` references, and prints a pass message once all four banks have matched.
