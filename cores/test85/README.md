# TEST85

`test85` is a small bring-up core for checking the CPS3-style 85.909 MHz clocking and SDRAM cache path on MiSTer without the full CPS3 core.

The core is intentionally ROM-less. Firmware and screen text storage are FPGA BRAM contents, and `cfg/mem.yaml` defines one writable SDRAM cache lane with flush support for later CPU-side tests.

Current stage:

- Uses `jtframe_pll5369`, `JTFRAME_SDRAM96`, and a 1 kB burst cache lane.
- Instantiates `jt65c02` with a fixed boot ROM image.
- Displays a 256x224 text screen through `jtframe_vtimer` and `jtframe_tilemap`.
- Keeps the cache lane idle until the Stage 3 CPU register map is added.
