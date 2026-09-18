# CPS timing and line-frame-buffer extent

Uses the actual `jtcps1_timing` generator used by CPS3, including its vertical
render-counter lead and delayed blanking edges. A fast completion responder
checks that each accepted frame requests exactly 224 lines at unity scale and
299 lines at vertical step 0x155 (ceil(224 * 341 / 256)).

This catches an inclusive/exclusive end-of-video error that would request an
extra line and wait indefinitely for a producer that renders exactly the visible
height. It also checks fractional source-height rounding and frame restart.
