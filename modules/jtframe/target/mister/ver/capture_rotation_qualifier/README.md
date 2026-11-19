# Native capture rotation qualifier

`run.sh` builds the real `jtframe_mister` wrapper and real `arcade_video.v` / `screen_rotate` with only unrelated board and MiSTer mixer blocks stubbed. The test settles three qualified VS rises for each case, then checks `CAP_VIDEO_OK`, the real framebuffer-enable output, and its rotation write request.

The truth table accepts `rotate=00` and `10` only when flip is off; it rejects `01` and `11` (rotation enabled), and rejects flip, scan FX, forced scandoubler, and gamma. `capture_wrapper_disabled/run.sh` covers full-HDMI macro-off and explicit-NOHDMI guard behavior; `sys_top_platform/sim.sh` covers downstream direct-video, low-latency, framebuffer, build-exclusion, and reset paths.

Run with:

```sh
bash modules/jtframe/target/mister/ver/capture_rotation_qualifier/run.sh
```
