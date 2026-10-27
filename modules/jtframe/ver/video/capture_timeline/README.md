Connects the actual acquisition controller to the actual CAB FIFO. Sweeps native
raster periods255..260 system clocks to put pause confirmation before, at, and
after the native LVBL edge and the CAB tick two clocks later. Logical game and
CAB frame counts must agree through entry, held rasters and abort/resume. This
catches freezing CAB according to a later pause decision than the native tick.
