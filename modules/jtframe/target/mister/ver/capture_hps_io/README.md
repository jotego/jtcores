# Capture UIO through real hps_io

This simunit drives the real MiSTer `hps_io` host bus and routes its actual
EXT_BUS to the CAB bridge and `jtframe_mister_capture`. It checks CAP_CAPS and
RESULT_READ dummy counts, full 16-bit command isolation, payload high-byte
faults, an ARM rejected without a CAB session, and that ordinary UIO / FPGA
transfer traffic does not claim the capture response driver. The capture
protocol and frame contents are covered by the `capture` simunit.
