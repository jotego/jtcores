# LF buffer scale stability

This simunit drives `jtframe_lfbuf_line` with a short synthetic video mode and
non-identity horizontal and vertical scale factors. The scanout line RAM is
filled with an address pattern so the visible pixel stream exposes the internal
horizontal read address.

The regression compares two consecutive scaled frames. With constant timing and
constant scale factors, the horizontal pixel sequence at a fixed scanline and
the `vread` sequence for visible lines must repeat exactly from frame to frame.
This targets frame-to-frame start-offset wobble like the shaking seen in the
CPS3 line-frame-buffer scale capture from jtcores issue #33.
