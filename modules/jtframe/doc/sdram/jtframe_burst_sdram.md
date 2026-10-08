# `jtframe_burst_sdram`

`jtframe_burst_sdram` is the SDRAM wrapper used by the cache path.

It combines:

- SDRAM power-up/init sequencing
- refresh generation and arbitration
- optional programming/download mode
- a single consumer burst interface
- registered SDRAM I/O handling

## Consumer Burst Interface

```verilog
input  [AW-1:0] addr,
input  [1:0]    ba,
input           rd,
input           wr,
input  [15:0]   din,
output [15:0]   dout,
output          ack,
output          dst,
output          dok,
output          rdy
```

Meaning:

- `addr` and `ba` select the SDRAM location
- `rd` or `wr` start a burst
- `ack` confirms the burst was accepted
- `dok` marks each returned read beat
- `dst` marks the first returned read beat
- `rdy` marks burst completion

The interface is designed for full-page sequential bursts. The requester keeps `rd` or `wr` asserted while the burst should continue and drops it to stop at the desired length.

## Internal Structure

Main blocks:

- `jtframe_sdram64_init`: SDRAM startup sequence
- `jtframe_sdram64_rfsh`: periodic refresh requester
- `jtframe_burst_mode`: switches between programming and burst operation
- `jtframe_sdram64_bank`: programming-mode SDRAM path
- `jtframe_burst_ctrl`: burst-state machine for cache traffic
- `jtframe_burst_mux`: selects init, refresh, programming, or burst traffic
- `jtframe_burst_io`: registered SDRAM command/data I/O

## Refresh Rule

Refresh is requested from `rfsh` pulses, usually one every `64us`.

The intended behavior is:

- defer refresh while an acknowledged burst is still in progress
- allow refresh once the burst path is free again

The cache-mux stress bench checks that refresh does not interrupt a live burst window.

## Programming Mode

The same wrapper also exposes a programming port:

```verilog
input               prog_en,
input  [AW-1:0]     prog_addr,
input               prog_rd,
input               prog_wr,
input  [15:0]       prog_din,
input  [1:0]        prog_dsn,
input  [1:0]        prog_ba,
output              prog_dst,
output              prog_dok,
output              prog_rdy,
output              prog_ack
```

This is the path used by `jtframe_dwnld` during ROM download. In normal cache tests it is usually tied off.

## Cache-Oriented Notes

- the cache path always talks in 16-bit SDRAM words
- `jtframe_cache` and `jtframe_cache_mux` build higher-level widths on top of that
- post-write read latency is important because the cache refill logic depends on the alignment of `ack`, `dok`, and returned data

Direct burst-controller regressions live in:

- `modules/jtframe/ver/sdram/burst_sdram`
- `modules/jtframe/ver/sdram/burst_sdram_64mb`
