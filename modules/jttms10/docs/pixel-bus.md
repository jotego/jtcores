# Pixel tags and SRT at the physical-word boundary

`jttms10_word` captures the CPU's `mem_pixel` tag with each held logical
field request. Every physical word produced by `jttms10_field`, including a
partial-field read/modify/write pair, carries `word_pixel` to the NARC
arbiter. The wrapper samples `pixel_srt` at the same request boundary. A
non-pixel request remains ordinary even when DPYCTL.SRT is set. With SRT
clear, a tagged pixel uses the normal field path and returns real memory
data. `cen` can pause the CPU without stopping the field adapter or arbiter;
the captured tag holds through all bus waits and is cleared by reset.

The primary 1988 TI TMS34010 User's Guide DPYCTL description (printed
pp. 6-20–6-21) and §9.10.2 (pp. 9-26–9-27) state that SRT converts *pixel*
reads to memory-to-register (MTR) cycles and pixel writes to
register-to-memory (RTM) cycles, while instruction and non-pixel accesses
stay ordinary. SRT does not alter the row/column address. The field adapter
still aligns a bit-addressed field to its physical 16-bit word and uses the
low address bits to select field bits; SRT adds no further address change.
The physical transfer address is the same word address the ordinary pixel
cycle would have used.

Crucially, TI §11.4.3 (p. 11-9) recommends PSIZE=16 for an SRT PIXT write
**so the write is not preceded by a read cycle**. Thus SRT does not bypass
ordinary partial-field RMW sequencing. A partial pixel write produces one
tagged MTR read and then one tagged RTM write at the selected word address;
the arbiter's lock and HOLD restart rules continue to apply. A direct pixel
read produces one tagged MTR per physical word. TI §11.4.4 (p. 11-10) says
MTR data outputs remain high impedance, so this wrapper returns a
deterministic zero for SRT pixel reads rather than treating `cyc_rdata` as
pixel data. That zero is a project-level deterministic choice, not a claim
that original silicon guaranteed a register value. RTM write data is not a
VRAM serial-register payload on LAD. Compatible VRAM behavior belongs to the
external NARC cycle controller and memory devices.

`jttms10_system` wires fabric `pixel_srt` to the word wrapper and returns
`word_pixel` to the fabric. Graphics microcode tags its logical pixel reads
and writes; scalar and instruction requests stay untagged. The standalone pixel-bus test
forces only the CPU-side logical request while running the real word adapter
and arbiter. It checks normal and SRT partial writes, MTR/RTM kind and
address, non-SRT tagged read data, SRT read zero, a non-pixel access under
SRT, stable payload through waits with `cen=0`, and reset cancellation:

```sh
bash modules/jttms10/ver/build.sh /tmp/jttms10-pixelbus-build
iverilog -g2005 -s test -I /tmp/jttms10-pixelbus-build \
  -o /tmp/jttms10-pixelbus-test \
  modules/jttms10/ver/pixelbus/test.sv modules/jttms10/hdl/*.v
(cd /tmp/jttms10-pixelbus-build && vvp /tmp/jttms10-pixelbus-test)
```
