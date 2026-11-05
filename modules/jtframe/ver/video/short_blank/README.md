# Orientation-aware short blanking test

This simunit verifies `jtframe_short_blank` with the orientation selection used
by `jtframe_board`. It checks that horizontal games shorten only `LHBL`, vertical
games shorten only `LVBL`, disabled cropping passes both inputs through, and the
8/16-pixel-or-line settings remove the requested amount at both sides.
