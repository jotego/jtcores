# S16 MCU bus-ready regression

This short simunit instantiates the production `jts16_main` and
`jts16_mcu_romresp` modules. Test-only stubs replace the unrelated 68000,
video, PPI, decryption, and timing blocks. The real S16 MCU bus ownership,
mode/address decode, registered ROM chip select, `mcu_ok` / `mcu_gated`
handshake, and ROM response-byte latch remain under test.

The test holds P1 at `0xef` (the checksum mode that keeps the 68000 reset),
then models the held MCU read at byte addresses `0x0408` and `0x0409`. It
checks the real decode to ROM word `0x00204`, holds `rom_ok` low for 18
clock-enable pulses, and expects the MCU gate to stay closed. Once ready,
the lower and upper byte lanes must return `0x00` and `0x60` respectively.

A second ROM read checks the running CPU bus grant. A work RAM read and write
check `ram_ok`. IO, text, palette, unmapped, and ROM write requests must wait
while the CPU is running without granting the bus, then advance after grant;
the ROM write does not wait for a read response. An idle MCU enable advances
without a grant. The request pins are forced at
the `jts16_main` boundary so the test isolates the bus grant and ready logic. The MCU's architectural MOVX consume path is
covered by the BODYSLAM full-core simulation.

Run from the repository root:

```sh
source setprj.sh
simunit.sh --run cores/s16/ver/mcu_bus
```
