# JT8051 opcode smoke test

This simunit test resets the CPU for every opcode byte, verifies that the
synchronous code path fetches it, enters its generated microcode address, and
reaches the following instruction boundary.  Detailed instruction results and
flag matrices are kept in `../vectors/tests.yaml`.
