# SH7604 Bus Timing Notes

This directory contains the SH7604-compatible CPU implementation. These notes
describe the external bus timing observed while building the
`ver/cpu/sh7604_async_mem` Verilator test and reading the BSC/wrapper logic.

The implementation has two useful interfaces:

- `SH7604`, the native CPU with address, data, chip-select, read/write and wait
  pins.
- `jtsh7604`, a JTFRAME wrapper that converts the native bus into a latched
  request plus `cache_ok` acknowledge interface.

## Clock Enables

The core is driven by a fast FPGA `clk` plus two non-overlapping enables. In the
async-memory test the master clock is 80 MHz. `ce_r` is asserted once every four
master clocks and `ce_f` is asserted two clocks later, giving a 20 MHz effective
CPU phase rate.

```wavedrom
{
  signal: [
    { name: "clk",  wave: "p...............", period: 0.5 },
    { name: "ce_r", wave: "10..10..10..10.." },
    { name: "ce_f", wave: "0.10..10..10..10" }
  ],
  head: { text: "80 MHz master clock, 20 MHz SH7604 enable phasing" }
}
```

Most bus-state changes in `BSC.sv` happen on `ce_r`. Read data is latched and
some active-low bus strobes are released on `ce_f`.

## Native Bus Signals

The native bus presents a 27-bit byte address on `A[26:0]` and a 32-bit data
bus. The area select is taken from `A[26:25]` and drives one of `CS0_N` through
`CS3_N`.

Important active-low controls:

| Signal | Meaning |
| ------ | ------- |
| `BS_N` | Bus strobe. Low during an external bus cycle. |
| `CSx_N` | Area chip selects from `A[26:25]`. |
| `RD_WR_N` | Read/write direction. Low means write. |
| `RD_N` | Read strobe. Low means read cycle active. |
| `WE_N[3:0]` | Write byte strobes. Low bits select written byte lanes. |
| `WAIT_N` | External ready. Low inserts wait states. |

`BSC.sv` evaluates `WAIT_N` on `ce_r` while the bus is in `T1`, `TW`,
`TRAS`, `TRCAS` or vector-fetch wait states. For asynchronous SRAM-like areas,
the cycle can advance to `T2` only when the programmed wait count has expired
and `WAIT_N` is high. On `T2` and `ce_f`, read data is latched from `DI`, bus
strobes are deasserted, and `CACK` is cleared.

## Read Cycle

The following diagram shows the shape of a normal external read with one
externally inserted wait. The exact number of idle master clocks depends on the
position of the next `ce_r`/`ce_f` pulse, but the ordering is fixed.

```wavedrom
{
  signal: [
    { name: "clk",     wave: "p..................." },
    { name: "ce_r",    wave: "10..10..10..10..10.." },
    { name: "ce_f",    wave: "0.10..10..10..10..10" },
    { name: "A",       wave: "x=...............x...", data: ["addr"] },
    { name: "BS_N",    wave: "1.0.............1...." },
    { name: "CSx_N",   wave: "1.0.............1...." },
    { name: "RD_WR_N", wave: "1..................." },
    { name: "RD_N",    wave: "1.0.............1...." },
    { name: "WAIT_N",  wave: "1..0....1..........." },
    { name: "DI",      wave: "x......=.........x..", data: ["read data"] },
    { name: "latch",   wave: "0........1.0........" }
  ],
  head: { text: "Native asynchronous read" },
  foot: { text: "BSC samples WAIT_N on ce_r and latches DI on ce_f in T2." }
}
```

For a zero-wait external device, `WAIT_N` may already be high when the BSC first
checks it. Data still must remain valid through the `ce_f` where the BSC enters
the data-latch point.

## Write Cycle

Writes are identified by `RD_WR_N == 0`. `DO` carries write data and `WE_N`
selects byte lanes. The wrapper mirrors these active-low byte strobes to
`cache_dsn`.

```wavedrom
{
  signal: [
    { name: "clk",       wave: "p..................." },
    { name: "ce_r",      wave: "10..10..10..10..10.." },
    { name: "ce_f",      wave: "0.10..10..10..10..10" },
    { name: "A",         wave: "x=...............x...", data: ["addr"] },
    { name: "DO",        wave: "x=...............x...", data: ["write data"] },
    { name: "BS_N",      wave: "1.0.............1...." },
    { name: "CSx_N",     wave: "1.0.............1...." },
    { name: "RD_WR_N",   wave: "1.0.............1...." },
    { name: "WE_N[3:0]", wave: "x=.............=x...", data: ["lanes", "1111"] },
    { name: "WAIT_N",    wave: "1..0....1..........." }
  ],
  head: { text: "Native asynchronous write" },
  foot: { text: "A low WE_N bit writes the corresponding byte lane." }
}
```

The byte-lane mapping used by the async-memory test is big-endian:

| `WE_N` bit | `DO` bits | Byte address |
| ---------- | --------- | ------------ |
| `WE_N[3]` | `DO[31:24]` | `A + 0` |
| `WE_N[2]` | `DO[23:16]` | `A + 1` |
| `WE_N[1]` | `DO[15:8]` | `A + 2` |
| `WE_N[0]` | `DO[7:0]` | `A + 3` |

## `jtsh7604` Request/Acknowledge Wrapper

`jtsh7604.sv` watches the native bus and creates a latched request:

- `cache_cs` stays high while a request is outstanding.
- `cache_rd` is high for reads, `cache_wr` is high for writes.
- `cache_addr` is `A[26:1]`, so append one low address bit to reconstruct the
  byte address.
- `cache_din` is the latched native `DO`.
- `cache_dsn` is the latched native `WE_N`.
- `WAIT_N` is driven high only when no request is active or when `cache_ok` is
  high.

The wrapper latches a request once, then suppresses duplicate launches while the
CPU is still holding the same native bus signals after `cache_ok`. If the CPU
changes address, direction, write data or byte strobes, the wrapper treats that
as a new request. This is important for long cache-line transactions because the
BSC can keep the bus active while stepping through multiple beats.

```wavedrom
{
  signal: [
    { name: "clk",       wave: "p..........." },
    { name: "native req",wave: "0.1.......0." },
    { name: "cache_cs",  wave: "0..1.0......" },
    { name: "cache_rd",  wave: "0..1.0......" },
    { name: "cache_addr",wave: "x..=.......x", data: ["A[26:1]"] },
    { name: "cache_ok",  wave: "0...1.0....." },
    { name: "WAIT_N",    wave: "1..0.1......" }
  ],
  head: { text: "Wrapper handshake for a one-clock external response" },
  foot: { text: "The BSC only observes WAIT_N on ce_r, so cache_ok timing must be held until that sample point." }
}
```

For reads, the external target should drive `cpu_din` with valid data before it
asserts `cache_ok`, and keep it stable until the request is released. For
writes, the target should perform the write when `cache_cs && cache_wr` is true;
using `cache_ok` as a registered acknowledge gives the CPU one clean wait-state
stretch.

The async SRAM test uses this pattern:

```verilog
assign cache_dout = {mem[word_addr], mem[word_addr + 24'd1],
                     mem[word_addr + 24'd2], mem[word_addr + 24'd3]};

always @(posedge clk or posedge rst) begin
    if (rst) begin
        cache_ok <= 1'b0;
    end else begin
        cache_ok <= cache_cs & (cache_rd | cache_wr) & selected;
    end
end
```

## Reset Fetch Note

In the wrapper test the observed reset sequence fetches vector data from the
external bus before normal instruction fetches begin. The test image mirrors the
initial vector pair at `0x00000000` and `0x00000008` so this early fetch pattern
does not depend on uninitialized memory.

## Practical Integration Rules

- Generate `ce_r` and `ce_f` as single-master-clock pulses. They must not
  overlap.
- Treat `WAIT_N` as a CPU-phase signal. Raising `cache_ok` for only one master
  clock can be missed if it does not cover a `ce_r` sample.
- Keep read data stable from `cache_ok` through request release.
- Use `RD_WR_N`, not `WE_N`, to classify reads vs writes at the wrapper level.
- Use active-low `WE_N`/`cache_dsn` for byte enables.
- Expect cache refills and burst-like instruction fetches to appear as a stream
  of separate external reads, not as one wide transaction.
