# Popeye and Sky Skipper

FPGA implementation by Chris Watson of Nintendo TPP2 (Popeye), TPP1 (Japanese
Popeye), the supported Popeye bootlegs and TNX1 (Sky Skipper). Jose Tejada's
JTFRAME integration and schematic reference circuits retain their attribution.
The supported FPGA target is currently MiSTer; other targets are explicitly
skipped until their analog/scaler integration is validated.

The board timing is preserved: a 20.16 MHz enable, 10.08/5.04 MHz video phases,
4 MHz CPU and 2 MHz PSG, with 513 half-lines and alternating interlace phase.
Measured field refresh is about 61.41 Hz (`JTFRAME_RATE=61.40`). MAME's 59.94 Hz
is explicitly marked FIXME and is not a reason to retune the PCB counters.
The progressive 512x448 path feeds the HDMI scaler; the separate interlaced
path feeds analog/direct video. CRT deflicker, width and position controls act
on that analog path. Monitor acceptance still needs hardware validation.

`cfg/mame2mra.toml` documents the per-set header bits for ROM scrambling,
bootleg protection and palette polarity, RAM decode, background nibble select
and TNX1 addressing. `hdl/jtpopeye_header.v` receives those bits during download.
Use `jtframe mra popeye` to generate all supported sets. Clone-only protection
PROMs are excluded from parent-only validation.

## Verification

After sourcing `setprj.sh`, run `simunit-all.sh --only popeye`. All twelve block
suites use generated inputs and pinned schematic models, with no private ROM
or sibling repository dependency. Each suite README describes its assertions.
The shared MiSTer routing regression is under
`modules/jtframe/ver/mister/split_video` and covers macro off/on, field routing,
direct video, scaler/framebuffer overrides and RGB/component conversion.

For a full boot, coin or start run, generate the ROMs and use a game folder:

```bash
cd cores/popeye/ver/popeye
jtutil sdram
jtsim -load start.cab -video 550 -batch
```

`-load` is required to initialize the graphics BRAMs and PROMs as well as the
board header. `jtutil sdram` by itself initializes only SDRAM. The start script
coins at frame 100 and waits until frame 350 before Start, allowing the credit
screen to settle. Check a nonblank frame and a nonzero, nonconstant gameplay
sound window. Coin insertion itself has no coin-triggered sound in MAME;
matching silent coin captures do not validate audio. The same inputs are
available for `popeyej`, `popeyebl` and `skyskipr`. `cfg/reg.yaml` registers
all four sets with the standard core regression runner, which supplies
`-load` and runs the 550-frame `reg.cab` sequence.

## Scene state

CPU-visible storage is declared in `cfg/mem.yaml`, in ioctl order:

| Region | Bytes | Content |
| --- | ---: | --- |
| work | 4096 | Physical scrambled work RAM, including CPU DMA source table |
| text | 1024 | Linear character codes |
| color | 1024 | Low nibble of each tile color |
| bglo | 4096 | Low background nibble |
| bghi | 4096 | High background nibble |
| scene MMR | 4 | AY port-B flip in byte 0 bit 0; remaining bytes reserved |

Total dump size is 14340 bytes. The three nibble memories use byte storage
with zero upper bits to support the standard ioctl byte interface, preserving
read/write latency and separate nibble enables. `mmr.yaml` mirrors the live AY
flip latch for capture; NOMAIN freezes the restored copy. NOSOUND retains PSG
bus and DIP/flip I/O while removing the audio filters. NOMAIN grants video DMA
the work RAM bus. DMA descriptors and all line/filter buffers rebuild normally;
none is restored from a MAME framebuffer.

Set `JOTEGO` to the private support directory. Canonical dumps live under
`$JOTEGO/scenes/popeye/<setname>/<frame>`. Run `ver/scene.sh <setname> <frame>`
from the core folder for a download, restore and explicit snapshot comparison.
The maintained MAME scene worktree supports this payload; see `doc/scenes.md`.
References and comparison images remain outside git.

## Hardware references and implementation choices

Local MAME reference files in `doc/` are from revision
`e5a5a102889d6c62f12e39a4db3e950e4f5d6822`, retaining their BSD notices.
The Nintendo Popeye manual/schematics and protection schematic are available
in the shared `arcade/schematics/NINTENDO` library. Independent 2020 circuits
used only for tests are pinned and attributed in `ver/fixtures/README.md`.

Schematic names are retained where they clarify timing: AD/DD are the
scrambled address/data buses, DM/DMCS the DMA descriptor write bus, ROH/ROV
background coordinates, INITE/O the field phase, RV the AY flip latch, and
AI/BI/HBD/VB the board timing taps. Numeric enable names state their frequency.
Trivial aliases have been removed; CPU read selection uses the standard
ternary mux. Tilemap horizontal offset is expressed through `HDUMP_OFFSET`.

The custom object renderer and double buffer implement alternating field
sampling, dual A/B sprite paths, the board's descriptor strobes and TNX1's
9-bit background counter. Generic `jtframe_objdraw` assumes a conventional
line schedule and does not preserve these relationships directly. Retain this
schematic implementation and its independent pixel/phase tests until a shared
helper can express those semantics. The custom half-line timer is necessary
for the same reason.
