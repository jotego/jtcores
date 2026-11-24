# Capture UIO through real hps_io

This simunit drives the real MiSTer `hps_io` host bus and routes its actual
EXT_BUS to the CAB bridge and `jtframe_mister_capture`. It checks the
CAP_STATUS words, full 16-bit command isolation, that an ARM with a payload
high byte is dropped, the ARM target (low byte first), the eight JTC3 result
words through the shared 128-bit latch, and that ordinary UIO / FPGA transfer
traffic does not claim the capture response driver. The capture protocol and
frame contents are covered by the `capture` simunit.
