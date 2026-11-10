# Nemesis switched audio RC test

Regenerates the current `jtnemsis_game_sdram.v` from `audio.yaml`, extracts the emitted p0–p3 coefficient/control expressions into a Verilog include, and tests those actual expressions with the `jtframe_pole` DUT. It checks the one-hot AY7E bank and all three identical common-pole mappings. Signed nonzero sine waves at Fs=192 kHz measure AC RMS attenuation at 10/20/40 Hz for C23 and 1/4/8 kHz for 33 nF; both-cap AY7E responses are checked against the product of the two quantized digital transfer functions. It also checks each output sample during state transitions for bounded values.

Run from the repository root after sourcing `setprj.sh`:

```sh
simunit.sh --run cores/nemsis/ver/audiorc
```

The test discards at least 16,000 samples before low-pole measurement (over ten time constants for the 20.52 Hz pole), then captures three or more coherent full periods. Measured gain must be within 2.5% of the quantized digital response or 0.002 absolute, whichever is larger. This tolerance covers fixed-point rounding and finite waveform quantization; it does not cover the separate ideal-circuit approximation bounds documented in the audio design note.
