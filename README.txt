JT_GNG
======

This work has two separate parts:

1. A verilog model of the original hardware, replicated from original schematics. This is found in the hdl folder. Some test benches are available in the "ver" (for verification) folder. Data sheets of parts used in the original design are located in the "doc" folder. This is interesting to understand how it worked. It can be used to repair broken boards too.

2. A modern clone written in Verilog. It has been made with the MiST board in mind but the game itself (jtgng_game module) is highly portable. All components used aim to be cycle exact -some even sub-cycle exact- so the recreation is the most similar thing to having the original PCB you can get.

The FPGA clone uses the following modules:

JT12: For YM2203 sound synthesis. From the same author.
MC6809 from Greg Miller