# jtframe_8751mcu regression

This is a wrapper-level test of the new `jt8051` CPU. It programs the
wrapper PROM while reset is asserted, uses the wrapper's synchronous internal
RAM, and applies deterministic variable gaps between `cen` pulses. The test
covers register, indirect and direct addressing, stack accesses, `LCALL`/
`RET`, `MOVC`, and `MOVX` read/write paths. The MOVX read test models the
short XDATA response observed on the S16 shared bus: it arrives on the enable
after the request and changes on the next one. It checks both a MOVX write by
reading it back and a distinct read value, so the wrapper must retain the
response until the CPU source microstep consumes it after the three required
wait microsteps. It also asserts that PC, register,
microcode-address, and the core-side ROM/RAM/XDATA bus signals cannot advance
during an idle `cen` gap. The wrapper's external outputs are intentionally
registered on the following idle clock, preserving the established synchronous
memory pipeline.

Run it with:

```sh
source setprj.sh
simunit.sh --run modules/jt8051/ver/wrapper
```
