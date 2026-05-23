# `jtframe_cache`

`jtframe_cache` is a small write-back cache that converts a consumer-side read/write interface into burst SDRAM transfers.

## Consumer Interface

```verilog
input      [AW-1:AW0] addr,
output reg [DW-1:0]   dout,
input      [DW-1:0]   din,
input                 rd,
input                 wr,
input      [MW-1:0]   wdsn,
output reg            ok
```

Rules:

- `rd` and `wr` are edge-triggered. Only the rising edge starts a request.
- `rd` has priority if both edges appear together.
- `ok` is a one-cycle completion strobe.
- On reads, `dout` becomes valid in the same cycle as `ok`.
- On writes, `ok` means the cache accepted the write and updated its cached copy.
- `din` and `wdsn` must remain stable from the `wr` edge until `ok`.
- `wdsn` is active low. For `DW=16` and `DW=32`, the MSB selects the upper byte.
- supported data widths are `8`, `16`, `32`, `64`, and `128`

## Cache Behavior

- hits are served from the local cache memory
- misses start a burst refill through the external SDRAM interface
- writes are write-back, not write-through
- a write miss refills the line first, then applies the write
- dirty lines are written back only when selected as the victim on a later miss

Victim selection:

- an invalid block is preferred
- otherwise a pseudo-random victim is chosen
- the last physical block accessed is protected from eviction unless `BLOCKS==1`

## Flush Interface

```verilog
input  flush,
output flushing,
output flush_done
```

`flush` asks the cache to scan all tags and write back every valid dirty line.
Normal write requests and read misses are blocked while a flush is pending or
active. Read hits to valid cached lines may complete while dirty lines are being
written back.

Handshake rules:

- `flush` is edge-triggered
- if `flush` rises while the cache is busy, the request is latched as pending
- `flushing` stays high while the dirty-line scan is active
- `flush_done` is a one-cycle pulse after the final set/way has been scanned
- clean valid lines remain valid
- dirty lines written back by the flush remain valid and become clean

This operation preserves cached contents. It only makes dirty data coherent with
SDRAM.

## Invalidate Interface

```verilog
input  invalidate,
output invalidating,
output invalidate_done
```

`invalidate` asks the cache to clear all tag valid bits. It is used by
`jtframe_cache_mux` after another lane flushes overlapping data to SDRAM.

Handshake rules:

- `invalidate` is edge-triggered
- if `invalidate` rises while the cache is busy, the request is latched as pending
- normal read/write requests are blocked while invalidation is pending or active
- `invalidating` stays high while the tag-clear walk is active
- `invalidate_done` is a one-cycle pulse after the final tag set has been cleared

Invalidation is a tag operation:

- no dirty write-back is performed
- cached data RAM contents are not cleared
- all lines become invalid because their tags are cleared
- the next read refills from SDRAM

Because invalidation drops dirty state without writing it back, it is only safe
for read-only lanes. The `jtframe mem` generator rejects configurations that
try to invalidate writable target lanes.

## Endianness

`DW=8` and `DW=16` map naturally onto SDRAM half-words.

For `DW=32`, the cache assembles two SDRAM words:

- `ENDIAN=1`: `{word0, word1}
- `ENDIAN=0`: `{word1, word0}`

The same ordering is used when splitting 32-bit writes into SDRAM words.

For `DW=64` and `DW=128`, the cache always uses little-endian byte packing and
`ENDIAN=1` is invalid.

## Parameter Checks

`jtframe_cache` stops simulation if:

- `ENDIAN=1` and `DW!=32`
- `BLOCKS` is not a power of two
- `BLKSIZE < 16`

When `SIMULATION` is defined, the cache also keeps a running `real`
`ext_total_read_kb` counter. It increments by `BLKSIZE/1024` each time a fill
request is accepted on the external SDRAM read interface.

## External Burst Interface

```verilog
output [EW-1:1] ext_addr,
input  [15:0]   ext_din,
output [15:0]   ext_dout,
output          ext_rd,
output          ext_wr,
input           ext_ack,
input           ext_dst,
input           ext_dok,
input           ext_rdy
```

The external interface is word-addressed in SDRAM half-word units.

Handshake meaning:

- `ext_rd`/`ext_wr`: request a burst
- `ext_ack`: burst accepted
- `ext_dok`: a read beat is available on `ext_din`
- `ext_rdy`: the burst is finishing
- `ext_dst`: first returned beat of a read burst

Implementation note:

- after a dirty write-back, the following refill has one extra pre-data cycle on the burst path
- the cache handles that by priming the first refill word before normal `ext_dok` streaming resumes

## Typical Uses

- direct unit tests against `jtframe_burst_sdram`
- internally, one lane of `jtframe_cache_mux`

Required direct regression folders are under:

- `modules/jtframe/ver/sdram/cache/read`
- `modules/jtframe/ver/sdram/cache/rw`
- `modules/jtframe/ver/sdram/cache/big_endian`
- `modules/jtframe/ver/sdram/cache/stress`
- `modules/jtframe/ver/sdram/cache/stress64-128`
