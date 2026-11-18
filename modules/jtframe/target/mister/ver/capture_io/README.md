# MiSTer capture UIO transport

This simunit drives full 16-bit HPS UIO words and post-transaction enable
deassertion. It checks the eight-word CAPS layout and native v3 capability bit, the native 15-bit
checkpoint/11-bit hold request, persistent ownership through READY, stable
JTC2 descriptor reads, clean release evidence, and rejection of checkpoint
overflow. It also checks that a rejected ABORT ACK clears transport busy while
retaining a non-IDLE owner for retry, and that IDLE cleanup permits a fresh ARM
to clear the sticky CAP fault. Its recovery case composes the real CAB stream,
capture tags and capture I/O transport around the testbench ascal status/ACK
contract. The actual ascal VHDL reject and watchdog cases run separately in
`ascal_capture` because the local simulator does not mix VHDL and Verilog.
The result bus stays stable until the matching release, so no second descriptor
cache is needed in the SPI reader.
