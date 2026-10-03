# SiDi128 HDMI border diagnostic

Run from this directory:

```sh
bash hdmi_border_sim.sh
```

The checks fail on any missing/reordered column, wrong row repetition, black
active sample, incorrect line width, or frame height. An optional argument
selects the input pixel enable phase (`7` by default, `3` for the other
aligned doubled-pixel enable). Each run checks all three blanking phases.

Requires Icarus Verilog (`iverilog`, `vvp`). The script prints a temporary
directory containing per-line logs and focused VCD traces.

The test instantiates the repository's unmodified `jtframe_scan2x`, its
dual-port RAM, and the MiST/SiDi128 HDMI `osd` module. OSD is disabled and
`JTFRAME_OSD_NOLOGO` omits the unused logo initialization, which Icarus cannot
elaborate. It does not instantiate the game, CPUs, sound, analog filter,
rotation SDRAM, PLL or physical HDMI transmitter.

The synthetic raster has M-Zone's 384-pixel line, 264-line frame, 288-pixel
active width and 224-line active interval. Enables are one per eight system
clocks for input pixels and one per four for doubled pixels. Time is scaled;
clock ratios, not absolute frequencies, are modeled. RGB encodes source X
and row; RGB and blanking receive a matched nine-input-pixel delay. The
test varies the vertical blanking transition across horizontal positions
319, 287 and 383 (before that delay). This is a controlled stimulus, not a
capture of an FPGA build or an exact emulation of the game's renderer.

`LINE` reports doubled-pixel samples within DE; `HDMI` samples every system
clock after the OSD register, corresponding to the default clk48 HDMI clock
relationship. VCD tracing covers two source lines near the active start in
the third input frame. Measurements allow two input frames for settling.

Before the fix: phase 319 produces 449 DE-active lines, including two black
lines at the beginning. The final source row appears only once instead of
twice. Horizontal measurements show 1152 HDMI samples, all source columns
0 through 287, and four samples each for the first and last column. Thus the
vertical discrepancy reproduces, but the reported horizontal loss does not
reproduce with these clock phases and matched input RGB/blanking.

Changing the input pixel enable phase from 7 to 3 also exposed a horizontal
column-alignment failure with the original reconstructed horizontal blanking.
This demonstrates a phase-dependent failure in the isolated path, but does
not establish the exact pixel-enable phase of the user's FPGA build.

The JTFRAME fix stores horizontal and vertical blanking alongside each pixel
in the line RAM and passes both bits through the RGB output pipeline. In
unrotated doubled output, blanking therefore belongs to the buffered image,
instead of being reconstructed from live input edges. The scan-doubler bypass
and rotation timing retain their existing paths.
This adds two bits per line-buffer entry. FPGA RAM packing impact depends on
the configured color width.

Expected corrected result: 448 active lines, each of the 224 source rows twice,
no black active samples and all 288 columns repeated four times at the HDMI
sample clock. A correct active-line count alone does not prove alignment;
the checks also verify the source row and column sequence.

The exact reported hardware clipping still needs comparison with actual game
RGB/DE input traces, clock phases, and transmitter/display cropping. This standalone branch has not been synthesized for SiDi128; hardware
validation remains separate from these simulation checks.
