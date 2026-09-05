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

At **scale = 0**: m = 8 × 64 = 512. The accumulator adds 64 each cycle and fires every 512 / 64 = **8 clocks** — exactly the input pixel rate. 1:1, no change.

At **scale = +1** (stretch by 1/64 = 1.5625%): m = 8 × 65 = 520. The accumulator fires every 520 / 64 = 8.125 clocks on average. Since clocks are integers, some pixels are held for 8 clocks and some for 9, with the extra clock distributed evenly across the line:

```
Pixel | Held for | acc after
------+----------+----------
    0 | 9 clocks |    56
    1 | 8 clocks |    48
    2 | 8 clocks |    40
    3 | 8 clocks |    32
    4 | 8 clocks |    24
    5 | 8 clocks |    16
    6 | 8 clocks |     8
    7 | 8 clocks |     0
    8 | 9 clocks |    56      ← pattern repeats
    9 | 8 clocks |    48
   ...
```

The pattern repeats every 8 pixels: 7 pixels × 8 clocks + 1 pixel × 9 clocks = **65 clocks for 8 pixels**. At scale = 0 the same 8 pixels take 64 clocks. The extra clock per group is the 1/64 stretch.

The residual accumulator value decreases by 8 each pixel (= m mod STEP = 520 mod 64 = 8). When it hits 0, the next pixel gets the extra clock and the residual resets to 56. This distributes the fractional remainder uniformly — no two consecutive pixels get the extra clock, and the pattern is the same on every line.

Shrink works symmetrically: at scale = -1, m = 8 × 63 = 504, and the output fires every 7.875 clocks on average — most pixels get 8 clocks, one in eight gets 7.

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
