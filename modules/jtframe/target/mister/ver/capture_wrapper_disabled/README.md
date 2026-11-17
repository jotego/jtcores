# Disabled regression wrapper test

Builds the real `jtframe_mister` and `hps_io` for two unavailable configurations: full HDMI with `JTFRAME_REGRESSION` absent, and `MISTER_DEBUG_NOHDMI` with the regression macro explicitly defined. Only unrelated board, video, joymux and DDR-mux neighbors are stubbed. The real status, target-info, download and HPS I/O blocks remain connected.

The HPS command driver probes CAB `0x80..0x87` and capture `0x90..0x94`, checks no EXT_BUS ownership/capability magic or CAB/capture side effects, and verifies ordinary status, joystick and FPGA-file transfer bytes/addresses before and after probing.

Run from an initialized JTCORES/JTFRAME environment with `JTFRAME` set to the active tree:

```sh
modules/jtframe/target/mister/ver/capture_wrapper_disabled/run.sh
```
