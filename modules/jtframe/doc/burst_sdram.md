# JTFRAME Burst SDRAM

`jtframe_burst_sdram` is a single-consumer SDRAM controller for sequential
bursts. It keeps the same programming and SDRAM pin interface as
`jtframe_sdram64`, but exposes one runtime port instead of four bank request
ports.

## Programming Phase

When `prog_en` is high, the controller behaves like `jtframe_sdram64`:

- `prog_addr`, `prog_rd`, `prog_wr`, `prog_din`, `prog_dsn` and `prog_ba`
  drive the SDRAM through the non-burst programmer path
- `prog_ack`, `prog_dst`, `prog_dok` and `prog_rdy` report programmer
  progress
- refresh and SDRAM initialization are still handled internally

This mode is intended for ROM downloading at startup.

## Runtime Burst Port

When `prog_en` is low, the consumer uses the following interface:

```verilog
input  [AW-1:0] addr,
input  [ 1:0]   ba,
input           rd,
input           wr,
input  [15:0]   din,
output [15:0]   dout,
output          ack,
output          dst,
output          dok,
output          rdy
```

- `addr` is the word address inside the selected SDRAM bank
- `ba` selects one of the four SDRAM banks
- `rd` starts or sustains a read burst
- `wr` starts or sustains a write burst
- `din` supplies write data one word per clock after the request is accepted
- `dout` returns read data one word per clock while `dok` is high

The handshake signals have these meanings:

- `ack`: request accepted
- `dst`: first valid read word
- `dok`: data transfer in progress
- `rdy`: transfer finished

To request a burst shorter than a full page, keep `rd` or `wr` high only for
the desired transfer length. The controller switches the SDRAM to full-page
burst mode for normal operation and terminates the burst when the consumer
withdraws the request.

## MiSTer Mode

Set `MISTER=1` for MiSTer SDRAM modules. In that mode the controller mirrors
`DQM` onto `A[12:11]`, matching the MiSTer SDRAM wiring quirk where those pins
are shorted.

## Notes

- `AW=22` maps 8 MB per SDRAM bank, for a total of 32 MB
- `AW=23` maps 16 MB per SDRAM bank, for a total of 64 MB
- `rfsh` triggers the same distributed refresh helper used by
  `jtframe_sdram64`
- the controller is verified by the simunit test in
  `modules/jtframe/ver/sdram/burst_sdram`
