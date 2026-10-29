# SiDi128 video regression

`jtutil regression` collects PNG video frames from a connected SiDi128 using
the RBF files from a successful GitHub `compile_all` build. Collection does
not approve a game's video content. A designer must inspect and approve the
images before they become references. Audio is not part of this workflow.

## Working project

Run the command in the JTCORES project after sourcing `setprj.sh`. The working
project is `$JTROOT`, or the current project directory when `JTROOT` is unset.
The command uses that project's core configuration, CAB inputs and tools; it
does not clone or check out another source tree. The selected RBF build's SHA
and the working project's source identity are recorded separately.

ROM files are produced by the normal `jtframe mra` workflow in
`$JTROOT/rom`. They are not stored in `$JOTEGO/regression`. Project-local work
files and downloaded RBF artifacts belong in the project's ignored cache.
Generated MRAs for unrelated cores must be preserved.

## Host setup

Set `JOTEGO` to the private support-files directory. Keep machine-specific
configuration outside the results directory, for example in
`~/.config/jtutil/regression.yaml`, and select it with `--config`. Without that
flag, configuration is read from `$JTROOT/.jtutil-regression.yaml`:

```yaml
host: 192.0.2.10
netrc: /home/regression/.netrc
control-helper: /path/to/firmware/tools/ftp-control.py
cab-packer: /path/to/jtcores/.cache/jtutil-regression/cab-pack/cabinet_pack
firmware: ATH261028
firmware-sha256: <64-digit digest of verified flashed firmware>
cab-exporter-sha256: <64-digit digest of the cabinet_pack binary>
capture-tool-sha256: <composite digest of ftp-control.py and cabinet_pack>
```

Use a private netrc file readable only by its owner. Credentials are not
written to configuration examples or logs.

## Profile settings

Global defaults come from `$JTFRAME/bin/reg.yaml`:

```yaml
video: 4000
start-up: 500
```

Entries in the working project's `cores/<core>/cfg/reg.yaml` override those
defaults. `inputs` selects a CAB relative to the game's `ver` directory;
without it the runner uses neutral inputs. `video` sets the total number of
CAB frames. `start-up` excludes checkpoints at or below that frame from
comparison, while keeping their PNGs for inspection. For example:

```yaml
1942:
  inputs: reg.cab
  video: 1000
  start-up: 500
  dipsw: ef77
```

Captures are requested every 100 CAB frames. The CAB exporter clips or pads
the input script to the configured frame budget and records the original
input identity in the run log. Unsupported profile settings become preparation
errors instead of being silently ignored.

An on-time frame is named `frame_00000100.png`. A startup capture requested
at frame 100 but taken at frame 112 is named
`frame_00000100_actual_00000112.png`; both identities are retained. Late
captures after the startup cutoff are execution errors.

## Collection and designer approval

```sh
jtutil regression --config ~/.config/jtutil/regression.yaml --run-id 676 --no-publish
```

`--run-id` pins a workflow run ID or run number. Without it, the command
discovers an eligible successful build. Interrupted runs retain their progress
under `log/`; `--retry-errors` retries terminal per-game errors.

The results directory contains logs and one directory per core:

```text
$JOTEGO/regression/
  log/
  <core>/
    <setname>/
      new/
        <frame>.png
```

`new/` contains only collected PNG frames awaiting designer review, including
black or uniform frames when the capture itself is complete and decodable. The
collector never creates or approves `ref/`. After inspecting the images, a
designer may promote the PNG folder to `ref/`. Existing designer references
are read-only inputs to later exact-pixel comparisons and do not require a
tool-generated approval marker. A mismatch is retained in `fail/` as PNGs;
comparison details belong in the run log.

Logs, summaries, capture metadata and JSON resume receipts are stored below
`$JOTEGO/regression/log/`. Resume receipts contain decoded-pixel hashes,
geometry and checkpoint identities, without a second set of PNG images.
RAW capture files are temporary project work files;
they are not published to the results directory. ROMs, source checkouts,
executables, build caches and machine configuration do not belong there.

The outer capture deadline allows for execution, capture pauses and retrieval:
120 seconds plus one tenth of a second per configured frame, capped by
`timeout-seconds` (900 seconds by default). Independent progress checks still
bound stalled playback and capture operations. Failed helper text and JSON
diagnostics are retained in the run log before temporary files are removed.

Technical checks establish that a capture is complete and decodable. They
cannot establish that the game's graphics or behavior are correct. Reports
must keep that distinction explicit. No images are uploaded by the report
publisher.
