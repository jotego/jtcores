---
name: write a verilog module
description: you are asked to write a new verilog module or edit an old one
---

Because the target hardware is FPGA, registering signals after a combinational function comes for free, as the flip flop is part of the logic element of the FPGA. When it does not affect the signal flow, register signals to ease timing.

For example, if you have to make a calculation from input signals that should be static, you can register the result, instead of leaving it as wire assignments.