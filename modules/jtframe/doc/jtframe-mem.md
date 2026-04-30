# Parses the core's YAML file to generate RTL files.

The YAML file name must be `mem.yaml` and be stored in `cores/corename/cfg`.
The output files are stored in cores/corename/target where target is
one of the names in the $JTFRAME/target folder (mist, mister, etc.).

## Audio Connections

- If both outputs of YM3012 are connected to the same summing net at an opamp input use the resistance value of one of the outputs as rsum.

Example with YM3012 having both channels connected to the summing net via:

- 1kOhm, 33pF parallel, 1kOhm, 4.7uF series, 1.2kOhm

The RC resistance is the parallel equivalent of 1k and 1+1.2.

``` YAML
- {name: fm,  module: jt51, rsum:  3.2k,  rc: [{ r:  687, c: 33n  }, {r: 1rout, c: 2.2n }] }
```

- If only one output of YM3012 is connected to the summing net, set the pregain to 0.5

``` YAML
- {name: fm,  module: jt51, rsum:  3.2k,  rc: [{ r:  687, c: 33n  }, {r: 1rout, c: 2.2n }], pre: 0.5 }
```


- For K007232, the output of jt007232 can be taken as two separate channels or a mixed one. The mixed one does not attenuate each channel, so it can clip. On the board, each channel will have its own DAC

## mem.yaml Schema

### Top-level keys

- `include`: list of YAML fragments to merge before the current file.
  - `game`: include another core’s `cfg/mem.yaml`.
  - `file`: include any other file path (resolved with the same search base as `mem.yaml`).
- `params`: macro `name/value` pairs available in `sdram.cache-lanes.at.offset`/`sdram.cache-lanes.at.length` and other expressions.
- `download`: controls optional download path transforms.
  - `pre_addr`, `post_addr`, `post_data`: booleans.
  - `noswab`: disable byte swapping in the download path.
- `ports`: additional explicit ports for the game module.
- `game`: override the default game module name.
- `clocks`: map of source clocks (`clk24`, `clk48`, `clk96`, `clk`) to lists of generated CEN definitions.
- `audio`: audio mixing/filter setup (`channels`, optional `pcb`, global `rc`, etc.).
- `sdram`: bank-based SDRAM map or cache-lane map, but never both.
- `bram`: list of BRAM/ROM/PROM blocks.

### Full example

```YAML
# Optional: include support files
include:
  - { game: cop }
  - { file: ../../cop/cfg/mem.yaml }

params:
  - { name: V_OFFS, value: "(`VTABLE_START-`JTFRAME_BA2_START) >> 1" }
  - { name: SPR_OFFS, value: "(`SPRITE_START-`JTFRAME_BA3_START) >> 1" }

download:
  pre_addr: false   # pass transformed pre-address into jtframe_dwnld
  post_addr: false  # pass transformed address into SDRAM slot arbiter
  post_data: false  # pass transformed data into SDRAM slot arbiter
  noswab: false

ports:
  - { name: foo_data, msb: 15, lsb: 0 }
  - { name: foo_cs }
  - { name: foo_ready, input: true }

game: mygame

clocks:
  clk48:
    - freq: 24000000
      gate: [ main, snd ]
      outputs: [ cen24, cen12 ]
    - freq: 3579545
      mul: 1
      div: 16
      outputs: [ cen_fm, cen_fm2 ]

audio:
  rsum: 1k
  gain: 1.2
  rsum_feedback_res: false
  mute: true
  rc: { r: 1k, c: 1n }
  pcb:
    - { machine: pacland, rfb: 10k, rsums: [ 7.1k, 12.25k ], pres: [ 1.0, 0.19 ] }
  channels:
    - name: fm
      module: jt51
      rsum: 3.2k
      rout: 100k
      pre: 0.5
      vpp: 5
      data_width: 16
      stereo: true
      unsigned: false
      rc_en: true
      rc:
        - { r: 1k, c: 33n }
        - { r: 1rout, c: 2.2n }
      dcrm: true
      fir: myfilter.csv

sdram:
  big_endian: true              # cache-lane mode only
  burst: 128k                   # optional burst size in bytes (must be power of two)
  banks:
    - buses:
      - name: tiles
        addr_width: 18
        data_width: 16
        offset: V_OFFS
        latch: TILES_LATCH
        cache_size: 4
        rw: false
        do_not_erase: true
        gfx_sort: hvvvh
        gfx_sort_en: video_en
        simfile:
          name: tiles.bin
          big_endian: false
      - name: obj
        addr_width: 20
        data_width: 8
        when: [MISTER]
        cs: obj_cs
        addr: obj_addr
  cache-lanes:
    - name: pcm
      data_width: 32
      blocks:
        count: 8
        size: 1kB
      rw: true
    - name: sprites
      data_width: 128
      blocks: { count: 16, size: 2kB }
      at:
        bank: 2
        offset: SPR_OFFS
        length: 8MB
      simfile:
        name: sprite_cache.bin
        big_endian: true
        data_type: u32

bram:
  - name: workram
    size: 32kB               # either size *or* addr_width
    data_width: 8
    rw: true
    we: ram_we
    addr: ram_addr
    din: ram_din
    dout: ram_q
    simfile: { big_endian: true }
    ioctl:
      save: true
      restore: true
      order: 0
      unless: [ JTFRAME_RELEASE ]
      when: [ SIDI ]
    dual_port:
      name: video
      addr: video_ram_addr
      din: video_ram_din
      dout: video_ram_dout
      rw: true
      we: video_ram_we
  - name: mcu_rom
    addr_width: 12
    data_width: 8
    simfile: {}
    rom:
      offset: 0
  - name: prom_data
    addr_width: 11
    data_width: 8
    prom: true
```

### Validation and defaults

- Unknown keys are rejected with an error. `mem.yaml` keys are strict.
- `sdram.banks` and `sdram.cache-lanes` are mutually exclusive.
- `sdram.banks` must contain **1–4** banks.
- `sdram.cache-lanes` must contain **1–8** entries.
- `include` entries are loaded then the active `mem.yaml` is reapplied to allow overrides.
- `params` values are evaluated as macro expressions when `cache-lanes` use `at.offset`/`at.length`.
- `clocks` is a map from base-clock names to lists of entries. The documented base clocks are `clk24`, `clk48`, `clk96`, and `clk`.
- For `clocks`, each entry supports:
  - `outputs`: required list of one or more names. The first output runs at the requested rate; each later output is divided by two from the previous one.
  - `gate`: optional list of SDRAM bus names. Each name expands to `(<name>_cs & ~<name>_ok)`.
  - `freq`: optional absolute frequency string. Accepted forms include `3579545`, `8e6`, `12M`, `12.5kHz`, and `8 MHz`.
  - `mul`, `div`: optional integer factors for the fractional enable generator.
- If an output name does not already contain `cen`, the generator appends `_cen`.
- If both `mul` and `div` are non-zero, they take precedence. Otherwise both are derived from `freq`.
- `freq` suffixes are case-sensitive: `p`, `n`, `u`, `m`, `k`, `M`, `G`, `T`, with optional `Hz`. Values below `1 Hz` are rejected.
- Base-clock remapping depends on `JTFRAME_SDRAM96`:
  - without `JTFRAME_SDRAM96`, `clk48` becomes `clk`.
  - with `JTFRAME_SDRAM96`, `clk96` becomes `clk`.
- SDRAM bus settings:
  - `banks[].buses[].data_width` supports **8**, **16**, **32**.
  - bus `addr_width` is counted in 16-bit words (LSB is bank address bit 0 for 8-bit, bit 1 for 16/32-bit).
  - `latch` passes a per-slot `SLOTn_LATCH` parameter into the generated SDRAM helper for read-only buses.
  - `cache_size` selects the request cache mix (`0` for regular ROM request path).
  - `do_not_erase` is only meaningful for writable SDRAM banks.
  - `gfx_sort` is limited to supported patterns (`hvvv`, `hvvvv`, `hhvvv`, `hhvvvv`, `vhhvvv` and `x` variants).
- Cache-lane settings:
  - supported lane widths are **8/16/32/64/128**.
  - `blocks.size` must be power-of-two, >=16, and parseable with exact suffixes `B`, `k`, `kB`, `M`, `MB`.
  - with `at` omitted, the lane spans full SDRAM space and the generator creates a full-address map.
  - only lanes `0..3` may set `rw: true`.
  - `sdram.burst` sets burst length and must be power of two (default derives from largest lane).
- BRAM settings:
  - `size` and `addr_width` are mutually exclusive; if `size` is used it must be power-of-two, greater than zero, and <=512kB.
  - `simfile.big_endian` is supported only for 16/32-bit BRAM and is rejected for 8-bit.
  - `prom: true` requires `data_width <= 8`.
  - `ioctl.order` defines file ordering for `dump2bin.sh`.
  - `rom.offset` is in `prog_addr<<1` space, with bank bits in `[24:23]` for MiST-family ROM layouts.
- BRAM `ioctl` and `dual_port` entries support `when`/`unless` as conditionals.
- `sdram.big_endian` affects cache-lane data ordering; for 32-bit cache lanes, it controls which SDRAM word becomes `dout[31:16]`.
