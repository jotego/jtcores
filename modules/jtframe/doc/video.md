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

# Frame Buffer

There is a line-based frame buffer available in the MiSTer and Pocket targets. It is line based because the frame buffer is drawn line by line and read line by line. This is enough for games that do not rotate the screen, and thus sprites can be drawn line by line.

To enable it use **JTFRAME_LF_BUFFER**. Refer to the standard include files to see which ports are required on the game side to access it. This buffer is not compatible with high speed DDR load in MiSTer.

The buffer was developed for the Out Run core but it is easier to test it with _Pirate ship Higemaru_ because the compilation time is much shorter. _Higemaru_ itself does not require it and it shouldn't be distributed with it enabled but it has been adapted so it is compatible with it by using the macros:

`jtcore hige -pocket -d JTFRAME_LF_BUFFER -d JTFRAME_LFBUF_CLR=15`

The macro **JTFRAME_LFBUF_CLR** sets the color used to clean the buffer. The default is 0, which suits Out Run, but CAPCOM games normally require 15.
