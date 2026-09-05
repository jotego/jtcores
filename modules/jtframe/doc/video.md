# Scan Doublers

Although original JTFRAME supported a variety of scan doublers, the support has been simplified down to the following:

Macro Def.      |   Module          | Description
----------------|-------------------|----------------------------------------------------
 NOVIDEO        | none              | by pass values without scan doubler. Useful for sims
 SIMULATION     | none              | same as above
 JTFRAME_SCAN2x | jtframe_scan2x    | simple and fast scan doubler. Small area footprint
 *no macro*     | arcade_video      | from MiSTer framework. Large area footprint

 jtframe_scan2x and arcade_video both depend on macros VIDEO_WIDTH and VIDEO_HEIGHT. But with a difference:

 Macro       | Module                | Meaning
 ------------|-----------------------|--------------------------
 VIDEO_HEIGHT| both                  | Visible vertical pixels
 VIDEO_WIDTH | arcade_video          | Visible horizontal pixels
 VIDEO_WIDTH | jtframe_scan2x        | Total horizontal pixels

No image problems might be related to misdefinition of these macros.

For MiST, OSD control of *arcade_video* features is enabled with macro **MISTER_VIDEO_MIXER**

## Aspect Ratio
In MiSTer the aspect ratio through the scaler can be controlled via the core. By default it is possible to switch between 16:9 and 4:3. However, if the game AR is different, the following macros can be used to redefine it:

Macro       |  Default    |   Meaning
------------|-------------|----------------------
JTFRAME_ARX |     4       | horizontal magnitude
JTFRAME_ARY |     3       | vertical   magnitude

Internally each value is converted to an eight bit signal.

# CRT Adjustments

The base video signal can be altered in two ways:

1. H/V sync pulses can be delayed by a number of pixels or lines
2. The image can be scaled horizontally

These arrangements help fit the image on any CRT, as many don't have H/V potentiometers or don't tolerate well the overscan. However, these adjustments have their limitations and are only considered a small help. It may not be possible to get a perfect screen filling even with the help of these options.

There are two modules used for this:

1. jtframe_resync: moves H/V sync pulses
2. jtframe_hsize: scales the horizontal video signal

Note that the blanking period also gets scaled by the same factor. H/V sync adjustment occurs before the scaling.

The monitor may completely lose sync for some settings. Note that this is a secondary feature, which I cannot fully test, and receives less development attention.

## Analogue H size (jtframe_hretime)

On MiSTer the analogue h-size uses jtframe_hretime by default. It resizes the picture by re-timing the DAC pixel clock instead of resampling the pixels. Every source pixel is still emitted once and only once, just held for a longer or shorter number of master-clock cycles, so there is no shimmering on moving graphics and no blending. The line period is unchanged; the active window grows into the porches and a fixed-sweep CRT draws it wider.

To fall back to the legacy resampling scaler (jtframe_hsize), set **JTFRAME_NORETIME** in the core's `macros.def`.

### How the phase accumulator works

The module has a single clock (`clk` = master clock) and generates its own output pixel enable (`ce_slow`) using a phase accumulator. The key values:

* **DIV** — master-clock cycles per source pixel (8 for a 6 MHz pixel clock at 48 MHz)
* **STEP** — accumulator denominator, 64 by default
* **scale** — the OSD setting, signed -8..+7

The target period is **m = DIV × (STEP + scale)**. Each master-clock cycle the accumulator adds STEP. When the accumulator reaches or exceeds m, it fires `ce_slow` (one output pixel) and wraps by subtracting m. The accumulator resets at every horizontal sync, so every line starts with the same phase.

Every pixel normally takes DIV = 8 master clocks. The scale controls how many pixels in each group of 8 shift to the adjacent divisor (7 or 9 clocks). The shifted pixels are distributed evenly across the line by the accumulator — never two adjacent.

```
scale | per group of 8 pixels              | total clocks | % change
------+--------------------------------------+--------------+---------
  -8  | 8 at 7 clocks                       |  56          | -12.5%
  -7  | 7 at 7, 1 at 8                      |  57          | -10.9%
  -6  | 6 at 7, 2 at 8                      |  58          |  -9.4%
  -5  | 5 at 7, 3 at 8                      |  59          |  -7.8%
  -4  | 4 at 7, 4 at 8                      |  60          |  -6.25%
  -3  | 3 at 7, 5 at 8                      |  61          |  -4.7%
  -2  | 2 at 7, 6 at 8                      |  62          |  -3.1%
  -1  | 1 at 7, 7 at 8                      |  63          |  -1.6%
   0  | 8 at 8                    (bypass)   |  64          |   0%
  +1  | 7 at 8, 1 at 9                      |  65          |  +1.6%
  +2  | 6 at 8, 2 at 9                      |  66          |  +3.1%
  +3  | 5 at 8, 3 at 9                      |  67          |  +4.7%
  +4  | 4 at 8, 4 at 9                      |  68          |  +6.25%
  +5  | 3 at 8, 5 at 9                      |  69          |  +7.8%
  +6  | 2 at 8, 6 at 9                      |  70          |  +9.4%
  +7  | 1 at 8, 7 at 9                      |  71          | +10.9%
```

At scale = -8, all 8 pixels move from 8→7 clocks — a full divisor shift. At scale = +7, 7 out of 8 move from 8→9. The pattern is identical on every line (the accumulator resets at hs).

### Pixel edge placement

Because both "clocks" are really enables off the same master clock, the output pixel edges are quantized to the master-clock period. The worst-case placement error is ±½ master clock, which is ±10 ns at 48 MHz (about ±1/16 of a pixel period). This is a fixed spatial error — the same on every line and frame — and it is invisible on a CRT.

### The elastic FIFO

Source pixels are written into a small FIFO (~32–64 deep, MLAB-based) at the input pixel rate. The reader pops them at the `ce_slow` rate. The FIFO resets at every horizontal sync so it cannot drift across lines.

For stretch the reader is slower, so the writer stays ahead and the FIFO fills gradually. For shrink the reader is faster, so it waits until the writer is far enough ahead (the `started` flag) before beginning — this prevents underrun and ensures the tail of the line is not lost.

The FIFO depth is derived at build time from `JTFRAME_WIDTH` and STEP, sized to the worst-case occupancy at max stretch.

### Where it sits

The re-timer is instantiated in `sys_top.v` on the VGA branch, between the scanlines filter and the analog OSD — **downstream of the point where the HDMI scaler taps the stream**, so HDMI output is unaffected by construction. It is bypassed when the scandoubler is forced, as h-size only makes sense on a 15 kHz monitor.

### Auto-centring

Without centring, stretch grows the picture to the right and shrink pulls it left. The module delays hs/vs through a small delay line by half the growth amount, so the picture grows or shrinks about its own centre.

### OSD

The OSD shows *CRT H size* (enable, Off/On) and *CRT H size adjust* (signed -8..+7). The adjust entry is hidden until enable is On. Each step is `1/JTFRAME_HSIZE_STEP` of the picture width, 1/64 (1.6%) by default, so the range is roughly -12.5%..+11%. **JTFRAME_HSIZE_STEP** must be a power of two. Off is a true bypass (`ce_out = ce_in`), and scale 0 is the same bypass.

How far the picture can actually stretch is set by the core's blanking budget, not by the module: if the resized active region would run past hs it is truncated there — the right edge clips but sync is never corrupted. A 256-pixel game inside a 384-pixel line has room for the whole range; a 384-pixel active region runs out at around +6.

### Build-time macros

`jtframe cfgstr` derives two macros from the core's clocks, and neither should be set by hand:

* **JTFRAME_HSIZE_DIV**: master-clock cycles per pixel. Computed as `base / PXLCLK` where base is 48 (or 96 with SDRAM96). Default PXLCLK = 6 → DIV = 8.
* **JTFRAME_HSIZE_DEPTH**: elastic FIFO depth, from JTFRAME_WIDTH and the step size.

The unit test is at `$JTFRAME/ver/video/hretime`, and it sweeps every step at each of the three usual clock ratios (DIV 6, 8, 12).

# Frame Buffer

There is a line-based frame buffer available in the MiSTer and Pocket targets. It is line based because the frame buffer is drawn line by line and read line by line. This is enough for games that do not rotate the screen, and thus sprites can be drawn line by line.

To enable it use **JTFRAME_LF_BUFFER**. Refer to the standard include files to see which ports are required on the game side to access it. In MiSTer the DDR-backed line buffer can be combined with **JTFRAME_MR_DDRLOAD**: while the ROM download is active the DDR bus is assigned to the loader and the frame-buffer path is held idle, then normal frame-buffer traffic resumes after the download finishes.

The buffer was developed for the Out Run core but it is easier to test it with _Pirate ship Higemaru_ because the compilation time is much shorter. _Higemaru_ itself does not require it and it shouldn't be distributed with it enabled but it has been adapted so it is compatible with it by using the macros:

`jtcore hige -pocket -d JTFRAME_LF_BUFFER -d JTFRAME_LFBUF_CLR=15`

The macro **JTFRAME_LFBUF_CLR** sets the color used to clean the buffer. The default is 0, which suits Out Run, but CAPCOM games normally require 15.
