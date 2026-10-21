# Longer Yamaha acquisition

Protocol 0x960104 adds a stereo-frame stride to mode 3. PERIOD is 1..1024;
all other modes retain their former behavior. ARM initializes frame selection,
retains the first qualified latch 0/latch 1 pair, skips N−1 complete pairs and
repeats. Framing errors are counted throughout, including skipped words.
The finite buffer still never wraps. An odd word limit can end on latch 0;
measurement campaigns request even counts.

The mode 3 file is C96CAP04/version 4, 80-byte header. Offset 28 is frame stride;
offset 68 remains the latest native stereo-frame interval in 100 MHz clocks.
Recorded rate is 100 MHz/(native_interval*stride). The interval is quantized,
so nominal clock-derived rates are used for model comparison. v3 files remain
native: their PERIOD was ignored and must not scale the old sample rate.
Raw/PRNG/PCM formats are unchanged.

There is no anti-alias filter. Select a known carrier below the recorded
Nyquist frequency; retain native sampling for noise/shape comparisons. For
slow AR measurements KC4A/MUL0 keeps key scaling unchanged and lowers carrier
to about 220 Hz, below the stride 64 Nyquist limit 437 Hz. Physical native fitting
independently returns increment 4124 (fit 4123.9998759,radian residual 0.00204).
The generator's `-carrier divided -pretrigger 8192` preserves the default
fixtures when omitted. Window 32 at stride 64 spans 36.61 ms. Absolute onset time
is not calibrated; the actual silent pretrigger is checked per recording.

## Tool qualification

- Independent synthetic input words encode serial index. Strides 1/2/3/1024
  select the expected complete pairs. Odd limits, reset/ARM, STOP and framing
  errors during skipped frames pass. PRNG/raw/PCM regression also passes.
- Both model wrappers simulate every internal clock while emitting native
  indices 0,N,2N,... . Strides 2/3/1024 match exact subsampling of unstrided
  outputs in every CSV column. Default stride 1 output and event sidecars stay
  byte-identical; later EVENT instructions execute after the recording limit.
  The maximum model budget is 16,777,216 native frames; full-budget execution
  has not been qualified merely by parser acceptance.
- Offline Go tests preserve v3 PERIOD semantics and verify v4 rate/pair order,
  bounds, version identity and malformed metadata rejection.
- Quartus 20.1.1, 5CSEBA6U19C8: 357 ALMs, 557 registers, 64 M10Ks. Worst setup +1.884 ns,
  hold +0.124 ns at 100 MHz; zero unconstrained clock/input/output paths. Only
  warning is the unavailable Lite LogicLock feature.
- New isolated firmware `c96-yamaha104.{rbf,dtbo}` and loader preserve the
  previous yamaha image, prior recorder executable and all SD boot files.
  Runtime loading retains Linux boot ID 3e876240-d0e5-41cf-b52d-9c2d2a303a0c.
  RBF SHA256 1d5840424c3d13203ad8adb27be3279952f653d91e152a0332d639b6e896028b;
  DTBO 6002dc209db7170c263dcb2de7864eb808964abfaa4963a6879874f1611081e6.
- Full 32768-word PRNG after runtime load passes every word and transfer SHA.
  Native before/after captures remain nonzero with correct amplitude. Physical
  strides 2/3/1024 pass header, transfer, framing and exponent checks. Stride 1024
  records 2048 stereo frames over 37.5 seconds, with a separately qualified 8.64 Hz
  carrier (KC00/MUL0,native increment 162) and stable projected amplitude.
- The HPS `capture` timeout now uses the serial duration, accounting for old
  protocols ignoring PERIOD. A seven-second early-stop run at stride 1024
  returns 766 words, status 10, zero framing errors and matching transfer SHA.
  This explicitly exceeds the old five-second timeout. Neither this stopped
  run nor the 37.5-second complete run claims a full 300-second recording.

Artifacts: `stride-qualification`, `stride-model-check`, `c96-yamaha104-build`.
The live resident CPU monitor is unchanged. Production jt51 remains frozen;
this is acquisition tooling, not an RTL implementation fix.
