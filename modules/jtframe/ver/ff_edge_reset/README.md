# `jtframe_ff` edge-history test

Exercises `jtframe_ff` at widths 1, 8, and 32 with both the default reset edge history and `EDGE_RESET=1`. A reference state model checks reset, clear/set/edge priority, ungated edge capture at `cen=0`, and independent wide-bus edges. A local legacy-helper model verifies the Nemesis `EDGE_RESET=1` mapping against the old latch behavior, including reset-free cases only after their first defined capture. The high-through-reset default-vs-override check is a negative control for the new parameter.
