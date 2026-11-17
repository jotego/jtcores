MiSTer CAB bridge test. Uses the real MiSTer `hps_io` transport, asynchronous
`clk_rom`/`clk_sys`, and the shared frame-driven CAB stream. Checks normal UIO
and FPGA file-transfer coexistence, bridge CAPS/status/cache response framing,
command validation/fault recovery, and frame-zero/reset/terminal tick behavior.
V2 ARM totals are checked at 255, 256, and 512 events, followed by a native
300-event end-to-end playback that verifies all events and frames complete.
The V2 DIP override is also checked to clear on STOP and natural DONE.
It also verifies that a read which starts without a snapshot remains all-zero
when the asynchronous STATUS response arrives during that read.
