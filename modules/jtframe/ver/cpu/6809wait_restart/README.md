# jtframe_6809wait restart

Two `jtframe_6809wait` instances leave reset at different times while `cen`
keeps running. The test checks that their E and Q pulses follow the same
pattern counted from the reset release. Before, the E/Q phase counter ran
through the reset, so the CPU started with a phase that depended on how long
the reset lasted, and the game did not repeat from one run to the next.
