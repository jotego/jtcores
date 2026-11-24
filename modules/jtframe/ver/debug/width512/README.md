Checks that the binary debug overlay remains in the cell left of screen centre
for both 256- and 512-pixel pictures, rather than wrapping to x=496 when bit 9
of the width is lost before division by two.

Run `simunit-all.sh --only jtframe_debug_ctrl.v` from the project environment.
