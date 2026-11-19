# Native capture rotation qualifier

`run.sh` builds the real `jtframe_mister` wrapper and real `arcade_video.v` / `screen_rotate` with only unrelated board and MiSTer mixer blocks stubbed. The test settles three qualified VS rises for each case, then checks the wrapper's capture `cap_video_ok` qualifier, the real framebuffer-enable output, and its rotation write request.

The truth table accepts `rotate=00` and `10` only when flip is off; it rejects `01` and `11` (rotation enabled), and rejects flip, scan FX, forced scandoubler, and gamma. `capture_wrapper_disabled/run.sh` covers full-HDMI macro-off and explicit-NOHDMI guard behavior; The capture writer taps native video before the scaler, so scaler modes (direct video, low latency, framebuffer) do not affect it.

Run with:

```sh
bash modules/jtframe/target/mister/ver/capture_rotation_qualifier/run.sh
```
