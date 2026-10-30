# SiDi128 video regression

`jtutil regression` collects PNG video frames from a connected SiDi128 using
local RBF files for manual captures, or a successful GitHub `compile_all`
build for a full campaign. Collection does
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

## Manual captures

After host setup, capture one core's main games or select one game:

```sh
jtutil regression --core shouse
jtutil regression --core shouse --setname splatter
jtutil regression --core shouse --setname splatter --jtbin
```

The default uses the working project's `release/sidi128` RBF and normal
`jtframe mra` generation. `--jtbin` reads existing MRA/RBF files from `$JTBIN`.
Profiles and CAB inputs still come from the working project. Each invocation
creates a fresh local session under `log/`, compares approved `ref` images
when available, and replaces the game's `new` images when review is needed.
Manual captures do not need a manifest or run ID and do not publish GitHub
reports. Existing campaign captures remain resumable through the batch API.

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

## Capture results

A fresh attempt clears the selected game's previous `new` and `fail` images.
A completed result uses one slot: `new` when no reference exists, or `fail`
when comparison or capture quality fails. A passing comparison removes both
slots. Designer-managed `ref` images are preserved. Resuming a verified
finalized result keeps its images and does not start another capture.

Quality checks use only checkpoints after `start-up`. A recording fails when
all those images are fully black, or when at least two images are present and
every decoded pixel is identical across all of them. These checks apply even
without an approved reference or when a reference contains the same images.
A single nonblack image is insufficient to establish a static recording.
Quality failures retain the captured PNGs in `fail` and their receipts and
metadata in the session log for review.

## Profile settings

Global defaults come from `$JTFRAME/bin/reg.yaml`:

```yaml
video: 4000
start-up: 500
```

Entries in the working project's `cores/<core>/cfg/reg.yaml` override those
defaults. `inputs` selects a CAB relative to the game's `ver` directory;
without it the runner uses neutral inputs. `video` sets the total number of
CAB frames. `start-up` selects the first capture checkpoint, rounded up to
100 frames (zero starts at frame 100). It also excludes checkpoints at or
below that frame from comparison. Thus `start-up: 300` captures frames 300,
400, and onward; comparisons begin at frame 400. Historical captures made
before delayed capture support remain valid for resume and comparison.
For example:

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

## Loading games

Each core uses one unique, run-owned FTP directory. Its RBF is uploaded once
and reused for the remaining games in that core; each game still uploads its
ARC and ROM files and performs `SITE LOAD`. That command configures the FPGA
again, so this change saves network transfer without changing game startup.
The in-memory cache is bound to the RBF basename and SHA256. A new process
starts with a fresh directory and upload rather than trusting existing SD files.

Game cleanup removes its ARC and ROM files. At the core boundary the runner
releases the shared RBF and queues directory removal until a later successful
load moves the firmware's current directory. Exact owned paths are recorded
in the log's cleanup ledger before transfer, so an interrupted process can
clean its files without deleting unrelated SD content. Load events include
per-file payload bytes, transfer duration, upload/reuse status, and the
separate `SITE LOAD` duration. Failed transfers retain their attempted payload
size; reused RBFs report zero transferred bytes.

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

## Continuing after an approved firmware change

A firmware change normally invalidates a resumed test definition. To preserve
already collected images while continuing pending games, an operator can place
an explicit `firmware-transition.json` in this campaign's `log/<run-id>/`
folder. It contains schema `1`, the exact `run_id` and `build` object from the
manifest, and `from`/`to` objects with `firmware` and `sha256` fields. The `to`
pair must match the verified installed firmware and current configuration.

With `--retry-errors`, the runner verifies finalized historical results against
the approved `from` pair and unchanged build, fixtures, profile, capture tools,
and image hashes. It preserves their original metadata, PNGs and per-game
identities. Pending and retried games use the `to` pair. This authorization does
not approve image content or promote any reference; an absent or mismatched
transition retains the normal firmware-identity rejection.
