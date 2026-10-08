# JTGAIDEN

FPGA arcade core compatible with Technos' Ninja Gaiden hardware

# Implementation Details

The core mostly follows MAME, with deviations natural from a digital logic implementation point of view.

Blending is implemented by blinking the two elements to blend, this is different from MAME's implementation. It does not require two color reads and should achieve the same effect.


# To Do

Some items may not be accurate on MAME driver and should be double checked:

- measure video timings
- extract at least enough schematic diagrams to cover:
	- analog audio section
	- color mixer
