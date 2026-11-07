# Rungun object IOCTL dump test

This test restores an 8 KiB binary scene fixture, writes selected words through
the object RAM's CPU port, then reads the byte port using the four-clock cadence
of the Verilator IOCTL dump harness. It confirms the exact little-endian byte
order used by `dump.bin` for both restoration and capture.
