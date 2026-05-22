# `jtframe_cache_mux`

`jtframe_cache_mux` instantiates up to eight `jtframe_cache` lanes and multiplexes their SDRAM bursts onto one shared `jtframe_burst_sdram` port.

## Lane Model

Each lane has a cache-facing request interface:

```verilog
input  [AWN-1:AW0_N] addrN,
output [DWN-1:0]     doutN,
input                rdN,
output               okN
```

Lanes `0..3` may also be writable:

```verilog
input                wrN,
input  [DWN-1:0]     dinN,
input  [DWN/8-1:0]   wdsnN
```

The mux contract is slightly different from `jtframe_cache`:

- the lane consumer raises `rdN` or `wrN` for a new request
- the consumer keeps that signal high until service is observed
- `okN` stays high until the consumer drops `rdN` or `wrN`
- changing `addrN` while the request stays high is ignored

This makes the lane side level-sensitive for completion while the inner cache remains edge-triggered.

## Arbitration

- arbitration is fixed-priority
- lane `0` is highest priority
- lane `7` is lowest priority
- only one SDRAM burst owner is active at a time
- once a lane owns the shared burst port, it keeps it until that burst reaches `rdy`

Important consequence:

- if a requester drops `rdN` before `okN`, the already-launched internal cache transaction still completes
- later lanes wait until that in-flight transaction reaches `rdy`

At the same time, a lane that already has `okN=1` does not block later bursts by itself. Other lanes may continue to make progress while that completed requester still holds its request high.

## Address Mapping

Each lane has:

- its own cache geometry: `BLOCKSN`, `BLKSIZEN`, `DWN`
- its own mode flag: `FULLN`
- for bank-relative lanes, its own SDRAM bank: `BAN`
- for bank-relative lanes, its own offset: `OFFSETN`
- its own endianness flag: `ENDIANn`

For bank-relative lanes, the mux adds `OFFSETN` to the cache-generated external
address and forwards `BAN` to the burst controller.

For full-space lanes, the cache emits a wider external address. The mux uses the
top two half-word address bits as the SDRAM bank and forwards the remaining
lower bits as the bank-local burst address.

Offsets are applied in the same half-word address space used by the cache
external interface.

The generator only enables `ENDIANn=1` for lanes with `DWN=32`. Wider lanes
use little-endian packing only.

## Write Lanes

The first four lanes expose write ports because the generated game interface may map writable cache-lanes there.

Generator rule:

- `rw: true` is valid only for cache-lanes `0..3`
- lanes `4..7` are always read-only

If a cache line is not writable, the generated `game_sdram.v` wiring ties `wrN` low and feeds neutral `dinN`/`wdsnN` values.

## Flush-Driven Invalidation

Writable lanes `0..3` can expose a flush interface:

```verilog
input  flushN,
output flushingN,
output flush_doneN
```

`flushN` asks the source `jtframe_cache` lane to write back all dirty lines.
`flush_doneN` is normally forwarded when the source cache finishes that dirty
write-back scan.

Some systems also map read-only lanes over the same SDRAM region as a writable
lane. If the writable lane flushes new data to SDRAM, those read-only lanes may
still hold stale cache tags. `jtframe_cache_mux` handles this with static
per-source invalidation masks:

```verilog
parameter INVAL_MASK0 = 8'b00000000,
          INVAL_MASK1 = 8'b00000000,
          ...
          INVAL_MASK7 = 8'b00000000
```

Each bit names one target lane:

- bit `0` invalidates lane `0`
- bit `1` invalidates lane `1`
- bit `2` invalidates lane `2`
- bit `3` invalidates lane `3`
- bit `4` invalidates lane `4`
- bit `5` invalidates lane `5`
- bit `6` invalidates lane `6`
- bit `7` invalidates lane `7`

For example, if lane `0` writes sprite RAM and lanes `4` and `5` read the same
SDRAM region, the generator emits:

```verilog
.INVAL_MASK0( 8'b00110000 )
```

The sequence is:

- source lane receives `flushN`
- source cache performs its normal dirty write-back
- source cache raises its internal flush-done pulse
- mux checks `INVAL_MASKN`
- if the mask is zero, `flush_doneN` is exposed immediately
- if the mask is nonzero, the mux pulses `invalidate` on every target lane whose bit is set
- each target cache clears its tags and raises `invalidate_done`
- mux waits until all masked target lanes have reported `invalidate_done`
- only then does the mux expose `flush_doneN`

This is whole-cache invalidation. It does not invalidate only the overlapping
address range.

The generated `mem.yaml` API is:

```yaml
flush: { enable: true, invalidates: [scndma, scrmap] }
```

Generator validation enforces:

- the source lane must use `flush.enable: true`
- invalidation targets must exist
- invalidation targets must be read-only
- source and target SDRAM ranges must overlap
- if `flush.enable` is false or omitted, `flush.invalidates` must be empty or omitted

The mux serializes delayed flush completion for sources `0..3`. If multiple
flushes finish close together, pending source completions are queued and each
source `flush_doneN` is released after its selected target invalidations finish.

## Regression Coverage

Required mux regressions are:

- `modules/jtframe/ver/sdram/cache_mux/simple`
- `modules/jtframe/ver/sdram/cache_mux/big_endian`
- `modules/jtframe/ver/sdram/cache_mux/multibank`
- `modules/jtframe/ver/sdram/cache_mux/stress`
- `modules/jtframe/ver/sdram/cache_mux/rw`
- `modules/jtframe/ver/sdram/cache_mux/flush`
