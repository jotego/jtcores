# MCP mode-read filter

Runs the real `mcp23009` control logic against a minimal I2C transaction stub. It checks that a single changed mode-bit sample is rejected, two consecutive successful matching samples are accepted, and a failed transaction neither changes the accepted mode nor updates card/button state.

The target module uses a SystemVerilog unpacked array assignment pattern that Icarus does not parse. Run this focused regression with `./sim.sh` from any directory. The runner uses Verilator, a temporary object directory, and tool-only warning suppressions for pre-existing initializer/style warnings.
