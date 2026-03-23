---
name: write a verilog module
description: you are asked to write a new verilog module or edit an old one
---

# Signal names

- prefix `nx_` to mark the next signal, like a combinational nx_a assigned to a register in `a <= nx_a`
- sufix `_l` to mark the last (_latched_) value of a signal

# Optimization

Because the target hardware is FPGA, registering signals after a combinational function comes for free, as the flip flop is part of the logic element of the FPGA. When it does not affect the signal flow, register signals to ease timing.

For example, if you have to make a calculation from input signals that should be static, you can register the result, instead of leaving it as wire assignments.

# File references

When instantiating modules in a core, you may need to add the path to the file in the core cfg/files.yaml files

# Linting

For isolated files use `verilator --lint-only --timescale 1ns/1ps` for linting.

For linting a core, use `lint-one.sh <core-name>`
