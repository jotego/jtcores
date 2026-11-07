# Mega Zone unit simulations

Run the automated checks through the repository's standard runner, from the
repository root after sourcing `setprj.sh`:

```sh
simunit.sh --run cores/mzone/ver/video_width
simunit.sh --run cores/mzone/ver/scene_restore
simunit.sh --run cores/mzone/ver/tilemap_equiv
simunit.sh --run cores/mzone/ver/obj_equiv
```

Each directory contains `.simunit`, `test.v`, and `gather.f`, so CI discovers it
without a separate launcher. The `init.go` hooks prepare fixtures and generated
RTL; they do not run a simulator. Simulation and PASS evaluation belong to
`simunit.sh`.

- `video_width` checks all four width/flip combinations and unchanged HS/VS,
  using generated renderer interface stubs to isolate video timing.
- `scene_restore` checks a deterministic synthetic dump, including every RAM
  port, IOCTL readback, video MMR restoration, CPU writes, ROM address decoding,
  and reset reload. It runs with `NOMAIN` and with the main CPU enabled.
- `tilemap_equiv` compares FIX/SCROLL against the frozen custom renderers;
  see its [coverage notes](tilemap_equiv/README.md).

- `obj_equiv` checks the object scanner/DMA/drawer against frozen originals
  and an independent logical sprite compositor, including transparency,
  wrapping, overlaps, delayed responses, and HS boundaries. See its
  [coverage and helper experiment notes](obj_equiv/README.md).

The restoration fixtures are prepared in each test directory. Memory and MMR
configuration is generated from an isolated temporary core tree so parallel
simunits do not rewrite another test's inputs or the core's generated HDL.

These checks require no MAME installation, game ROMs, or `JOTEGO` directory.
MAME is only an optional tool for creating new captures with
`game/scenes/capture.sh`. Full scene playback remains the standard
`game/sim.sh -s <scene>` / `jtsim -s` workflow, described in
[game/README.md](game/README.md).

No `.bin` or `.hex` fixture is committed. `init.go` generates the restoration
fixture at runtime. To check a locally available capture instead, provide its
absolute path:

```sh
MZONE_SCENE_DUMP="$JOTEGO/scenes/mzone/megazone/989/dump.bin" \
    simunit.sh --run cores/mzone/ver/scene_restore
```

The external dump must follow the same 7172-byte format. The default CI run
always uses generated synthetic data.
