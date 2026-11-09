# Native interlace through MiSTer arcade video

Run `./sim.sh` to check that a native interlaced source keeps its VSync edge
at either side of the half-line phase through `arcade_video` and MiSTer's real
video mixer, native-pixel OSD, bypassed horizontal retimer, and final VGA
output pipeline. The test suppresses existing Verilator warnings in MiSTer
modules that Quartus accepts; it checks sampled and final VGA sync edges and
constant half-line field periods through the full chain.
