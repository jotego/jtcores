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
`$JTROOT/rom`. They are not stored in `$JOTEGO/regression`.
Generated MRAs for unrelated cores must be preserved.

Regression uses the standard files directly: RBFs in `release/sidi128`, MRAs
in `release/mra`, and ROM/ARC/default RAM files in `rom`.
With `--jtbin`, the RBF and MRA inputs come directly from the selected `$JTBIN`
tree; generated ROM/ARC/RAM files still go into the working project's `rom`.
The checkout is used for one operation at a time. Prepared input hashes are
recorded and checked before execution; changed files require fresh preparation.

## Automatic build archives

Automatic regression first selects a completed, successful `compile_all` run.
It looks for that run's commit-named ZIP (for example `a405f1b.zip`) in
`/gdrive/jotego/core-builds`. If present, the ZIP is reused without downloading
it. Otherwise, the exact GitHub artifact is downloaded into that directory.
An optional `builds-dir` configuration entry overrides the archive directory
when operating on another machine.

The entire ZIP's `release/` tree is unpacked into `$JTROOT/release`, including
all platform binaries and MRAs. Existing files with the same paths are
replaced. SiDi128 `jt*.rbf` files absent from the selected archive are removed
so another build's binaries cannot enter the inventory. Other unrelated local
files are preserved. The ZIP is validated in temporary staging before local
release files are replaced; staging and incomplete downloads are removed.

ZIPs remain only in the shared archive directory, and extracted binaries remain only in
the local `release` tree. Other preparation work uses unique `/tmp` directories
and is removed when preparation finishes, including on errors. Text/JSON
errors are recorded in the commit log. Interrupts cancel preparation or stop
the batch after the active game cleans up, leaving subsequent games pending.
Build identity, archive and RBF
hashes are recorded in the commit progress JSON under `$JOTEGO/regression/log/`.

A reused local ZIP is identified by its selected artifact filename and its
measured SHA256; a changed ZIP is rejected when a prior run record exists.
Downloads additionally verify the GitHub service archive digest when supplied.
The logs distinguish local reuse from a verified service download: the service
archive wraps the build ZIP, so their SHA256 values are not interchangeable.
An invalid existing ZIP produces an error rather than being overwritten.

## Scheduled polling

Use `jtutil regression --poll` for one scheduler invocation. An active regression
or no eligible build is a successful no-op. Every invocation acquires the same
`$JOTEGO/regression/log/lock` before preparation or board access. The cron wrapper
only invokes the command; it creates no logs or separate locks.

Optional `builds-since` in the machine YAML sets an inclusive RFC3339 workflow
creation-time boundary for discovery. Within this window, successful builds are
considered oldest first. Completion is tracked by the **jtcores source commit**,
so another workflow attempt or build of that commit does not repeat a completed
regression. Failed/incomplete workflows are reconsidered after successful retries;
unchanged-source workflows with skipped jobs/no artifact do not start captures.

Example user crontab (adapt paths for the machine):

```cron
*/15 * * * * /usr/bin/env PATH=/usr/local/go/bin:/usr/local/bin:/usr/bin:/bin JOTEGO=/gdrive/jotego /bin/bash -c 'cd /home/jtejada/jtcores && source ./setprj.sh && exec "$JTFRAME/bin/regression-cron.sh" --no-publish'
```

Use `--no-publish` while GitHub reports require review. Completed local campaigns
are still remembered. With publishing enabled, a pending report can be retried
without running games again. Before other work in the shared checkout, disable
its cron line and let the active game finish cleanup.

Eligibility uses both `doc/mame.xml` and `doc/custom.xml`, matching `jtframe mra`.
Titles present only in an artifact remain per-game preparation errors when the
current project cannot prepare them; they cannot execute or stop unrelated games.

## Compact execution logs

`regression/log` belongs exclusively to `jtutil regression`. Its generated
`README.md` tells AI agents to keep experiments, plans and investigation artifacts
in `/nobackup/tasks/<task-name>/`, outside this directory.

Each full **RBF source commit** has two flat files:

```text
log/
  README.md
  lock
  upload-directories.json
  <jtcores-commit>.json
  <jtcores-commit>.log
```

The JSON holds current status, current game, timestamps, archive/RBF hashes and one
compact result/input fingerprint per game. It is saved atomically after each
game. Filenames use the seven-character commit prefix, matching the shared build
ZIP (for example `f848902.json` and `f848902.log`); the JSON retains the full commit
hash. Existing full-hash filenames are shortened under the common lock. A prefix
collision is rejected rather than overwriting another commit's records.
An interrupted run resumes pending games; completed games with unchanged
inputs are skipped. Changed inputs are explicitly logged and rerun. Individual
errors do not stop the other games. `--retry-errors` with an explicit workflow
selection retries terminal errors. Completed batches with game failures are still
completed batches.

The text log records game starts, results, warnings and useful bounded error
messages in fixed-width date (10), time (8), core/setname (32), runtime (10) and
verdict (11) columns, followed by optional details. Runtime is in seconds; a dash
means it is not yet available. Mismatches use `19/40 frames differ`, where the
denominator counts only the frames actually compared, excluding startup frames.
Timestamps use local time as `YYYY-MM-DD HH:MM:SS`; JSON progress also
retains the UTC offset and fractional seconds. Older UTC progress files remain
readable. `poll.log`, when present, holds the latest discovery/setup error before
a commit could be selected. No run files are created for an idle poll. There are
no persistent manifests, per-core state folders, per-frame receipts, helper dumps
or duplicate JSON/JUnit reports. Detailed working files stay in `/tmp` and are
removed. The board cleanup ledger retains only owned remote paths still needing
cleanup. Reference/new/fail PNGs stay in the existing per-game result folders.

Each `<core>/<setname>/log` is an append-only check history, separate from the
per-commit logs. It contains one fixed-width row per completed game check:

```text
2026-10-31 13:21:05 f848902       PASS        a1b2c3d4
```

Columns are completion date (10, `YYYY-MM-DD`), local time (8), short commit
(13, allowing `-dirty`), verdict (11), and reference CRC (8 hexadecimal digits).
The CRC32/IEEE is measured from `ref/` at check completion. It covers every
regular file recursively in sorted relative-path order, including names and raw
contents; modification times are ignored. Hash records are `d<path>\0` for
directories and `f<path>\0<size>\0<bytes>` for files, with decimal byte sizes and
slash-separated relative paths. Symlinks and special files are rejected.
`--------` means no reference folder exists; an empty reference has CRC `00000000`.

PASS, FAIL, NEW, ERROR and UNSUPPORTED checks are recorded. Resumed games that
are skipped add no row; fresh manual checks and retries append another row.
History is saved before the game is marked complete, so a history write failure
leaves it resumable. The common NFS board lock serializes history writes too.
Existing history survives replacement of `new`/`fail` and promotion to `ref`.
History starts with new checks; past checks are not backfilled with today's CRC.

Manual local runs use the current jtcores HEAD. Uncommitted changes, including
untracked files, produce a visible warning and the filename label `-dirty`, for
example `<commit>-dirty.json` and `<commit>-dirty.log`. Clean state is recommended;
dirty development runs are allowed. `--jtbin` obtains the jtcores source SHA from
the JTBIN commit message that last changed the selected SiDi128 RBF. It uses the
source SHA in the release message, not JTBIN's own commit SHA. Manual captures
always run selected games fresh, update their entries and do not falsely mark an
entire automatic campaign complete.

Repeated manual runs reuse the corresponding commit's pair of files. Records are
retained until removed by the operator; deleting a commit JSON forgets its resume
and completed-build state. Never remove the active progress file or lock.

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
runs fresh and updates its commit log, compares approved `ref` images
when available, and replaces the game's `new` images when review is needed.
Inventory and local MRA generation use `jtframe mra --nodbg`: games marked
as debug in the working project's `mame2mra.toml` are excluded. The same
selection applies to `--jtbin` inputs and older build artifacts; those inputs
do not reintroduce intentionally excluded games. Selecting a debug game
explicitly reports that it is excluded. An explicit `--manifest` containing
such games is rejected before logs or resume state are changed; regenerate
its inventory rather than silently removing entries from a historical run.

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
firmware: ATH261028
firmware-sha256: <64-digit digest of verified flashed firmware>
```

Use a private netrc file readable only by its owner. Credentials are not
written to configuration examples or logs.

Omitting `netrc` uses `~/.netrc`. Omitting `rom-source` uses `~/.mame/roms`
for the input ZIP archives. Generated ROM files always use `$JTROOT/rom`.

Omitting `mra-converter` resolves `mra` through `PATH`; an explicit value selects
that executable. Use an up-to-date mra-tools-c converter that preserves the
MRA's index-1 mode byte when creating an ARC with `-s -A`. The older
`1b62e949` build emitted `MOD=0` for Circus Charlie despite its mode byte being
`01`; `651828d0` produces the correct `MOD=1`.

The core-independent CAB exporter is compiled once per regression invocation
from the current checkout into `$JTFRAME/bin/cabinet_pack`, which Git ignores.
All games use that same executable directly. No `cab-packer` setting is needed.
The `jtframe-cab-pack` wrapper also builds into this location; `--build` forces
a fresh build without packing a script. The measured exporter/capture-tool
hashes are recorded automatically. Optional `cab-exporter-sha256` and
`capture-tool-sha256` pins still reject a mismatch when explicitly configured.

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
Quality failures retain the captured PNGs in `fail` and a concise reason in the
commit log for review.

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
before delayed capture support remain readable. Changing the first pause can
change game initialization and later images; a designer may need to review
and replace the reference when adopting a new capture schedule.
For example:

```yaml
1942:
  inputs: reg.cab
  video: 1000
  start-up: 500
  dipsw: ef77
```

CAB input changes, including scripted reset, follow rising native `LVBL`, as in
simulation. With updated FPGA and MCU firmware, CAB START also waits for that
boundary before applying the first entry and releasing the ARM reset request.
The starting edge begins frame zero; later eligible edges complete CAB frames.
Deploy MCU firmware with bounded START acknowledgement before these RBFs;
legacy firmware expects an immediate start. Older RBFs retain their original
immediate-start behavior even with updated MCU firmware.

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
Per-process RBF reuse is bound to its basename and SHA256. A new process
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
      log
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

Progress and readable results are stored in the commit's JSON/text log pair
under `$JOTEGO/regression/log/`. Frame receipts and helper reports are temporary
working data, removed after the game.
Each game gets a private, unique `/tmp/jtutil-regression-capture-*` workspace
for its effective CAB, RAW downloads, intermediate images and helper reports.
It is removed after the game on success or failure, after publishing complete
results and recording useful errors in the commit log. Reference receipt
checks also use short-lived `/tmp/jtutil-regression-receipt-*` directories.
RAW capture files are not published to the results directory. ROMs, source checkouts,
executables and machine configuration do not belong there.

The outer capture deadline allows for execution, capture pauses and retrieval:
120 seconds plus one tenth of a second per configured frame, capped by
`timeout-seconds` (900 seconds by default). Independent progress checks still
bound stalled playback and capture operations. Failed helper diagnostics are summarized in the commit log before temporary
files are removed.

Technical checks establish that a capture is complete and decodable. They
cannot establish that the game's graphics or behavior are correct. Reports
must keep that distinction explicit. No images are uploaded by the report
publisher.

## Changed test inputs

Resume compares one input fingerprint per game, covering fixtures, profile,
firmware and capture tools. A completed game with changed inputs is rerun and
this is noted in the text log. Historical per-frame receipts and special firmware
transition files are no longer required. Designer reference approval remains
separate from resume bookkeeping.
