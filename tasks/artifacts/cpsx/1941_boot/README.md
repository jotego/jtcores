1941 boot verification from `cores/cps1/ver/1941/`

Run:

```bash
source setprj.sh
cd cores/cps1/ver/1941
jtsim -setname 1941 -load -q -video 520 -d SKIP_RAMCLR -d JTFRAME_SIM_ROMRQ_NOCHECK -d VIDEO_START=2
```

Result:

- The simulation completed in `12'39"` and produced frames in `cores/cps1/ver/1941/frames/`.
- The first late-boot image frames from this run appeared at `516/519/520`.
- The reference regression frames in `/nobackup/regression/cps1/1941/valid/frames.zip` appear at `502/505/506`.
- The image content is byte-identical across these pairs:
  - `ref_frame_00502.jpg` == `sim_frame_00516.jpg`
  - `ref_frame_00505.jpg` == `sim_frame_00519.jpg`
  - `ref_frame_00506.jpg` == `sim_frame_00520.jpg`

SHA-256:

```text
949f3034f787fa58ced4fca837536cb2421eef0dead4fb0de92e15679cabd5c9  ref_frame_00502.jpg
949f3034f787fa58ced4fca837536cb2421eef0dead4fb0de92e15679cabd5c9  sim_frame_00516.jpg
7d895096db8cd8ac6e533bed474d48638927a449c31b803081ca789265e02b07  ref_frame_00505.jpg
7d895096db8cd8ac6e533bed474d48638927a449c31b803081ca789265e02b07  sim_frame_00519.jpg
ac572d486e3d02a7c62f869125f3e4e52f2b9e884ec7541f322dd2d923de9a95  ref_frame_00506.jpg
ac572d486e3d02a7c62f869125f3e4e52f2b9e884ec7541f322dd2d923de9a95  sim_frame_00520.jpg
```

Conclusion:

`1941` does boot correctly in the `cores/cps1/ver/1941/` workdir. The video output reaches the same known-good boot state as the stored regression reference.
