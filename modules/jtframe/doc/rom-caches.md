# SDRAM ROM caches and burst sizes

This guide covers read-only buses under `sdram.banks` in
[`mem.yaml`](jtframe-mem.md), using `jtframe_romrq` and the short-burst
`jtframe_sdram64` controller. The separate `sdram.cache-lanes` interface uses
the [burst SDRAM controller](burst_sdram.md) and has different settings.

## Four quantities to keep separate

| Quantity | Setting | Meaning |
| --- | --- | --- |
| Client word width | Bus `data_width` | Bits returned to the game for one request. |
| Bank burst size | `JTFRAME_BAn_LEN` in `macros.def` | Bits supplied per bank read: 16, 32 or 64. The default is 32. |
| Cache capacity | Bus `cache_size` | Either a count of client words or a byte capacity, depending on its syntax. |
| Address tag | Derived by the HDL | Address information used to check that a cache entry contains the requested data. |

The physical SDRAM data bus is 16 bits wide. A bank burst of 64 means four
16-bit transfers, not 64 transfers. The game can still receive 8-, 16- or
32-bit words from that burst; fetching and consuming are separate operations.

Bank burst size applies to **all clients sharing that bank**. Cache capacity
and client width are configured separately for each bus.

## Three ROM request paths

`cache_size: 4` and `cache_size: 4kB` select different cache module, not just
different capacities. In these settings, `kB` means 1024 bytes.

| `cache_size` | HDL selected by `jtframe_romrq` | Data retained | Lookup and replacement |
| --- | --- | --- | --- |
| Omitted or `0` | `jtframe_romrq_bcache` | Two 32-bit blocks, 8 bytes total. | Checks both block addresses; a new block displaces the older one. |
| Positive integer `N` | `jtframe_romrq_xscache`, using `jtframe_ucache` | `N` requested client words. | Searches all entries; new words replace entries in rotation. |
| Size string, such as `8kB` | `jtframe_romrq_lcache` | The specified byte capacity, divided into burst-sized lines. | Direct-mapped: each memory line has one possible cache entry. |

Entries do **not** have to describe adjacent addresses. Adjacency applies to
the words within an individual burst or large-cache line.

### Omitted or zero: the legacy burst buffer

The default path is often called "uncached", but it still has two 32-bit
buffers. A hit in either buffer avoids a new SDRAM request.

| Bank burst | What a miss brings into the buffer |
| --- | --- |
| 32 bits | One 4-byte block. The other entry can retain a previously fetched block from elsewhere. |
| 64 bits | Two adjacent 4-byte blocks from the same burst, replacing both entries. |

For a 16-bit client, a 64-bit burst can therefore supply four words, returned
individually as they are requested. It does not turn the client into a
64-bit consumer.

This helper is built around 32-bit blocks: use 32- or 64-bit bank bursts for
this path. The controller's ability to perform a 16-bit read does not make
that a supported general setting for the legacy buffer. Client widths are
8, 16 and 32 bits; 64-bit clients require the large cache.

### Numeric size: cache only the requested words

With `data_width: 16` and `cache_size: 4`, the cache holds four 16-bit words:
8 bytes of data, plus address and validity information. Those four words
may come from four unrelated locations.

On a miss, only the requested client word is inserted. For example, with a
16-bit client and a 64-bit burst, the three additional 16-bit words are not
saved in neighboring entries. Increasing the burst size does not increase
this cache's useful capacity or make it prefetch adjacent words.

This path is useful for a small set of repeatedly accessed addresses. All
entries participate in the address lookup, so increasing the integer is not
equivalent to building a larger BRAM cache. Supported client widths are
8, 16 and 32 bits; a 32-bit word needs at least a 32-bit bank burst.

### Size string: cache complete burst-sized lines

With `cache_size: 8kB`, the large cache holds 8192 bytes of data, plus tags
and valid bits. The size must be a power of two, at least 1 kB, and within
the address-space limit checked by `jtframe mem`.

Each cache line is **exactly one bank burst**. On a miss:

1. The requested address is aligned to the beginning of its line.
2. One burst is requested from SDRAM.
3. Its 16-bit transfers are assembled into the line.
4. After the final transfer, the complete line is stored and marked valid.
5. The requested client word is selected from that line.

Later requests to other words in the line hit without another SDRAM read.
A miss fills one line, not the entire cache. There is no automatic fetch
of the following line.

For example, a 32-bit client with a 64-bit burst can obtain two adjacent
32-bit words from one fill. A 64-bit client receives the complete line in
one response. The latter only helps the game if its consumer actually uses
the wider response.

## Supported large-cache combinations

| Client `data_width` | Bank burst 16 | Bank burst 32 | Bank burst 64 |
| --- | --- | --- | --- |
| 8 | Yes | Yes | Yes |
| 16 | Yes | Yes | Yes |
| 32 | No | Yes | Yes |
| 64 | No | No | Yes |

The burst must contain at least one complete client word. In particular,
`data_width: 64` requires a string `cache_size` and an explicit
`JTFRAME_BAn_LEN=64`. The implementation does not combine two 32-bit bursts
into a 64-bit response. There is no benefit to requesting that unsupported
combination.

This table describes the large cache; the legacy buffer and numeric cache
have the separate restrictions described above. Cached ROM paths do not
provide writable-memory caching or write coherence.

## Line count, tags and conflicts

The large-cache line count is:

```text
line count = cache capacity in bytes / (bank burst bits / 8)
```

| Data capacity | Burst 16: 2-byte lines | Burst 32: 4-byte lines | Burst 64: 8-byte lines |
| --- | --- | --- | --- |
| 4 KiB | 2048 | 1024 | 512 |
| 8 KiB | 4096 | 2048 | 1024 |

A tag identifies which memory line currently occupies an entry. Its width
is derived from the address space and cache capacity; it is not a separate
user-selected data width. Each entry also has a valid bit. The configured
byte capacity excludes this metadata and does not describe the exact FPGA
resource cost.

In a direct-mapped cache, memory lines whose byte addresses differ by the
cache capacity map to the same entry. For example, with a 4 KiB cache,
lines at byte offsets `0x0000` and `0x1000` replace each other. An 8 KiB
cache gives these two lines different entries. Other addresses can still
conflict, so doubling capacity does not guarantee a particular hit rate.

The `TAG_RAM` HDL parameter controls how the large-cache tags are stored
and read. It changes neither line size nor capacity. Hit latency is one
clock normally or two with registered tag reads (`TAG_RAM=1`), plus SDRAM
service time on a miss. The generator selects registered tag reads when
`JTFRAME_SDRAM96` is enabled, allowing block RAM to hold the tags.

## Choosing settings

| Access pattern or need | Starting point and tradeoff |
| --- | --- |
| Simple ROM reader with little reuse | Start with the legacy buffer and a 32-bit burst. It retains recent data with little storage. |
| A few frequently revisited addresses | A small numeric cache can retain those words even when they are far apart. |
| Reuse across a larger working set | Try a large cache sized for that working set. It can reduce refetches, at the cost of BRAM and metadata. |
| Neighboring words are usually consumed | A wider burst with the legacy buffer or large cache can satisfy more client requests per SDRAM transaction. |
| Sparse accesses that skip neighboring data | A smaller supported burst avoids fetching as much unused data. A numeric cache retains only the requested words regardless of burst size. |
| A consumer that processes 64 bits together | Use a 64-bit client, 64-bit bank burst and large cache; arrange the ROM data to match that consumption. |

Larger bursts do not inherently reduce first-request latency. Larger caches
do not shorten an individual SDRAM transaction or remove compulsory misses.
The physical SDRAM burst mode is selected from the largest configured bank
burst, while each bank has its own service length. Reducing one bank's
length therefore does not guarantee a proportional reduction in shared bus
occupancy.

Changing `data_width` also does not repack or interleave the ROM data. Its
download layout and the game's address and lane selection must agree with
the chosen width.

For packed 4-bpp graphics, a 64-bit word contains 16 source pixels. A drawer
that consumes all 16 can use the fetched data efficiently. A heavily
shrunk sprite may use just one pixel and skip the rest. A larger cache
helps only if some of that data is reused; it does not remove this sampling
waste or add a deeper prefetch pipeline.

Compare representative workloads using cache misses, SDRAM requests and
consumer wait time. For a sprite drawer, also compare whether it completes
its work before the scanline deadline. There is no universally optimal
burst or cache size.

## Example: a 64-bit sprite ROM client

The bank number is its position in `sdram.banks`. This example puts the
sprite client in bank 0.

In `cfg/macros.def`:

```text
JTFRAME_BA0_LEN=64
```

In `cfg/mem.yaml`:

```yaml
sdram:
  banks:
    - buses:
        - name: sprites
          addr_width: 21
          data_width: 64
          cache_size: 8kB
```

This creates 1024 cache lines of 8 bytes each. A miss fills one line using
four 16-bit transfers; a client response returns all 64 bits together.
Changing `data_width` to 32 would still fill the same 8-byte lines, but
return one selected 32-bit half per client request. Changing the bank burst
to 32 while keeping `data_width: 64` is invalid.
