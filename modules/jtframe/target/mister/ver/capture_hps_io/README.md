# Capture UIO through real hps_io

This simunit drives the real MiSTer `hps_io` host bus and routes its actual
EXT_BUS to the capture parser. It checks CAP_CAPS and RESULT_READ dummy counts,
full 16-bit command isolation, payload/deassert framing, malformed read length,
and that ordinary UIO / FPGA transfer traffic does not claim the capture
response driver. It supplements the direct module-boundary capture_io test.
