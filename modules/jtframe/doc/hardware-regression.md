# Hardware video regression

## MiSTer native capture capability

A core that defines `JTFRAME_REGRESSION` must continue ordinary gameplay with
stock Main, including Main builds that do not implement the regression
commands. This is a compatibility requirement for every regression-enabled
core; PR validation must establish it before claiming qualification. Automated
capture and replay require a matching Main build with the corresponding
regression feature enabled. This requirement is not evidence that stock Main
compatibility has already been qualified.

Normal full-HDMI MiSTer builds enable the CAB replay bridge and exact native
capture support through the target-default `JTFRAME_REGRESSION` macro. MiSTer
builds without HDMI (`-mrq`, `-qq`, or credits mode) remove the macro and leave
the existing hps_io commands unsupported. Standalone `-q` keeps HDMI and the
capability; `-u JTFRAME_REGRESSION` disables it explicitly. A defined value of
`0` is still enabled under the project's macro-presence semantics.
Archive runs skip cores whose MiSTer macros lack `JTFRAME_REGRESSION`, such
as cores that use DDR for video all the time, in the same way as `JTFRAME_SKIP`
cores.

The exact capture transport is unavailable in CRT480I and interlaced builds.
Native vertical capture uses the normal Video Rotate screen option set to No.
Cores that use DDR continuously for video (`JTFRAME_LF_BUFFER` in DDR,
`JTFRAME_MR_GAME_DDR`) have no regression support, because the capture writer
needs the core's video DDR port. A board build containing this capability is
not, by itself, evidence that a core or hardware setup has been qualified. The
configured qualification record must match the generation, convention, Main
executable hash and qualification ID.

The MiSTer route below is separate from the existing SiDi128 screenshot
workflow. It does not change the SiDi128 result folders, history rows, or
historical readers described later in this document.

The capture protocol uses a native checkpoint in the range 1..32767. Checkpoint
N identifies completed native interval N-1; checkpoint 1 therefore identifies
interval 0. There is no FPGA epoch or separate screenshot ordinal in this
protocol. A requested maximum hold, when needed, is 100..2000 ms. One capture
session has a 300-second monotonic wall-clock deadline covering playback,
capture, copy, encode, release and cleanup. The checkpoint range is a protocol
bound, not permission to run a 32767-frame session: at 60 Hz that would exceed
the session deadline.

### Capture block

`jtframe_mister_capture` handles the CAP_* commands, derives the checkpoint
tags from the CAB replay counters and writes the frames. It runs entirely on
`clk_sys`, which is also `clk_rom` and `DDRAM_CLK`, so the only clock crossing
is Intel's f2sdram bridge and ordinary STA covers the capture logic. The HDMI
scaler (`ascal.vhd`) is the unmodified MiSTer version.

It captures the core's native video, the `arcade_video` output before the OSD
and the scaler. While a capture is armed, every native frame is packed as
RGB888, rows padded to a 256-byte pitch, and written through the core's DDR
port to a fixed 2 MB slot at HPS address `0x3FE00000`. Pixels start 256 bytes
into the slot. A frame starts at the first active pixel after the game's LVBL
falling edge; the same edge produces the checkpoint of the interval that just
ended. When the frame with the requested checkpoint has been written, writing
stops and the slot stays frozen while the game keeps running. The block waits
for its last burst to be accepted, then publishes the descriptor (READY).
Capture never pauses or slows the game. There is no hold watchdog: a frozen
slot blocks nothing, and Main enforces its own hold deadline.

The block takes the video DDR client from `screen_rotate` only while it has
data to write; capture requires rotation off, so `screen_rotate` is idle then.
A DDR ROM download (`ioctl_rom`) is an unsupported video mode, and the DDR
port only changes owner between bursts. Faults: bad length (1), bad word (2),
bad state (3), late target (4), lifecycle change (5), unsupported video mode
(6), tag sequence (7), write overrun (8), bad release (0x0C) and geometry
change (0x0E).

The native v3 capture path advertises capability bit 6 in CAP CAPS word 3.
Matching Main reads a 64-byte descriptor over UIO; its IEEE CRC protects the
descriptor. Mode bit 13 marks the core DDR slot (slot 0, 2 MB stride, base
`0x3FE00000`); Main builds that predate it reject the descriptor as an
unsupported mode. Bytes 36..39 hold the number of 256-byte slot blocks,
including the 256-byte offset before the pixels; bytes 40..43 contain the
algorithm tag `GFW1`; bytes 44..47 hold the write-side hash. Starting at zero,
for each little-endian 32-bit payload word (including row padding), GFW1
shifts the 32-bit state left, XORs `0x00400007` when the previous top bit was
set, and XORs the word. It detects reordered DDR payloads but does not
establish that the source game produced the correct frame or independently
detect every possible corruption.

The slot remains owned and protected while Main copies its pixels. READY means
the target writes were accepted by the DDR port; Main verifies the copied
payload against the checksum and retries a mismatch within the hold deadline.
It then checks a fresh CAPS response for the same owned, fault-free READY
result and freshness before releasing the slot. The v3 image receipt records
the descriptor, checksum, and READY and post-copy CAPS witnesses. Ordinary
gameplay with stock Main remains a requirement.

## MiSTer native regression

MiSTer capture uses the normal CAB input stream and the native RGB888
capture writer. It is a qualification-gated, local-only route. The capture
contract supports progressive, non-rotated native video. Scaler settings such
as low latency or framebuffer modes do not affect it. CRT480I and interlaced
builds are unavailable. Do not interpret a completed
board transfer as a qualified result: the host checks session identity,
generation, frame sequence, image receipts and pixel quality before it writes
the selected generation's progress lane.

### Build and artifact requirements

Build the core with normal HDMI output so `JTFRAME_REGRESSION` remains enabled:

```sh
jtcore <core> -mr
```

The MiSTer target enables this macro by default. The reduced `-mrq` route,
`-qq`, credits builds, `MISTER_DEBUG_NOHDMI`, CRT480I and interlaced builds do
not provide the required bridge/capture combination. `-q` only removes optional
build work and retains HDMI; `-u JTFRAME_REGRESSION` explicitly disables the
feature. A defined macro value of `0` is still considered enabled by the
project's macro-presence logic.

MiSTer runs use the selected Compile all workflow commit as the source identity
for the RBF set. The active JTCORES checkout must match that commit before
capture begins. There are no per-RBF build proof files; release qualification
and source selection remain tied to the workflow commit. Inventory verifies the
selected MRA, its effective ROM ZIP candidates and CRCs, default RAM, CAB and
capture plan before assigning a board. The native `.CFG` path follows the MRA
setname override and the config version emitted by the selected core's rendered
MiSTer config string (for example, `set_v52.CFG`). If the source commit or
config string cannot be resolved, preparation stops before board access.

Manual preparation uses the working checkout's generated files; `--jtbin`
selects existing MRA/RBF files from `$JTBIN`. `--commit` selects a local archive
under `$JOTEGO/core-builds`. Automatic discovery accepts successful `Compile
all` builds for MiSTer and validates their artifact identity before extracting
selected assets. MiSTer capture does not publish external GitHub or Gitea
reports.

### Configuration and credentials

Use a separate machine-local YAML file, passed with `--config`. The example
contains no credentials. The qualification file is strict JSON; use a record
created by the reviewed qualification process, not the illustrative digest
below.

```yaml
target: mister
root: /home/regression/jotego/regression
builds-dir: /home/regression/jotego/core-builds
boards:
  - id: regression-a
    host: mister-a.example.net
    user: root
    ssh-config: /home/regression/.ssh/jtframe-mister
    identity-file: /home/regression/.ssh/id_ed25519
    remote-staging-root: /media/fat/_Arcade
capture-contract:
  generation: native-rgb888-v1
  convention: native-non-rotated-rgb888-v1
  qualification-id: board-a-qualification-2026-01
  qualification-evidence: /home/regression/jtcores/mister-qualification.json
  main-sha256: 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
  command-timeout-seconds: 30
  load-timeout-seconds: 120
  capture-timeout-seconds: 900
  cleanup-timeout-seconds: 60
  max-hold-ms: 1000
  expected-bridge-count: 1
```

The `remote-staging-root` is currently fixed to `/media/fat/_Arcade` by the
driver. `ssh-config` and optional `identity-file` must refer to externally
managed absolute paths. Put host aliases, ports and SSH options in the SSH
config file. If password authentication is required, provide
`JTFRAME_MISTER_REGRESSION_A_SSHPASS` through the process environment for this
board ID. Do not put passwords or private keys in YAML, logs, result folders,
or command-line arguments.

The qualification JSON schema is:

```json
{
  "schema": 1,
  "target": "mister",
  "generation": "native-rgb888-v1",
  "convention": "native-non-rotated-rgb888-v1",
  "qualification_id": "board-a-qualification-2026-01",
  "main_sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
  "qualified": true
}
```

The configured values must match the file exactly. `qualified: true` is not a
user-set override; the file must come from an independently reviewed
qualification record for that hardware generation and Main binary.

### Capture and resume

Examples for a manual working-tree selection and a local archived build:

```sh
jtutil regression --config ~/.config/jtutil/mister-regression.yaml \
  --core circus --setname circusc
jtutil regression --config ~/.config/jtutil/mister-regression.yaml \
  --core circus --setname circusc --jtbin
jtutil regression --config ~/.config/jtutil/mister-regression.yaml \
  --commit <40-character-jtcores-sha> --core circus --setname circusc
```

Automatic build discovery can be polled once with `--poll`; an optional
`--run-id` pins a successful build. `--commit` uses the exact local archive
under `builds-dir` (or `$JOTEGO/core-builds` when omitted). Do not combine
automatic selectors with the manual `--mister-run-scope` option. A manual
capture normally creates a fresh scope; to resume that same interrupted manual
scope, pass its exact ID with `--mister-run-scope`.

Boards are never quarantined. When an attempt cannot be cleaned up exactly,
the driver recovers the board by rebooting it: it restores the backed-up files
(MiSTer.ini, NVRAM, CFG), reboots over SSH, waits up to four minutes for the
qualified Main to come back on its original loader, restores the files again
and removes what the attempt left on the SD card. Missing or changed staged
files are reported but do not block recovery. The same recovery runs in the
health check before each capture when a stale board ledger is found or the
board is not running the qualified Main. The failed game is reported for that
run; the board takes the next game. A board whose recovery fails, or that fails
three health checks in a row, sits out the rest of that run only. A resumed run
releases attempts that an earlier run left in flight, unknown or quarantined,
and attempts in other lanes no longer block a run.
MiSTer runs reject `--manifest`, `--retry-errors`, `--migrate-logs`,
`--import-progress` and `--publish-to`; the route prepares and verifies its own
inventory and is local-only.

One worker is assigned to each configured board. Independent boards can capture
in parallel, while one board runs one attempt at a time. The common regression
lock excludes overlapping regression and management operations. Progress is
saved to the existing flat `<build-sha>.json` and `<build-sha>.log` files.
MiSTer data is isolated in the additive `capture_runs` JSON lane, keyed by
target, capture generation, capture convention, qualification ID and run scope.
The lane records selected games, result summaries, attempts and resumable
finalization state; legacy top-level status, error, completion, report and RBF
fields retain their prior meaning. Selected archive SHA256 is stored with the
MiSTer lane, not the legacy archive field. Owned private recovery state lives
under `log/.mister-private/`; it is not a public report tree.

Per-game images continue to use the existing `<core>/<setname>/{ref,new,fail}`
directories. A capture without a reference is `new`; a failed exact comparison
or capture-quality check is `fail`; a successful comparison clears pending
images. Completed MiSTer results append a compatible row to the existing flat
per-game `log` history; earlier rows and historical readers are preserved.

`jtutil regression --status --config <file>` displays lanes matching that
configuration's generation and qualification without contacting a board.
`--busy` is also a local lock query. Explicit curation is:

```sh
jtutil regression --config <file> --accept circus/circusc
jtutil regression --config <file> --reject circus/circusc \
  --reason "Rejected after visual review"
```

Acceptance requires exactly one completed, journaled `new` candidate from the
configured generation, a revalidated private candidate and unchanged published
PNGs. It promotes those PNGs and writes `reference-provenance.json` beside
`ref/`. Existing references without matching qualified provenance are not
automatically promoted, replaced, or rolled over. Resolve an old or unqualified
reference explicitly before accepting a MiSTer result. Rejection is also
explicit; capture itself never approves a reference.

MiSTer images use native RGB888 and must not be passed through the historical
SiDi128 RGB444/RGB555 decoder. `jtutil mame-frames` resolves native precision
from the selected core and target. Current JTFRAME color-width macros support
4..8 bits per channel; the generic comparison quantizer accepts 1..8 bits.
Historical SiDi128 images and flat check history remain readable and unchanged.

The standalone executable-only startup path is not accepted by the MiSTer
driver: loading an RBF/MRA from process arguments does not program the FPGA.
Use a normal loader-mediated `load_core` operation so the FPGA generation and
capture witness can be verified. Do not substitute cached core/RBF names for a
fresh load witness.

The [hardware regression workflow](../../../.gitea/workflows/hardware-regression.yaml)
does not opt into SiDi128 implicitly. Its manual `legacy_sidi128` input defaults
to false; set it true only for a deliberate legacy campaign. A scheduled run
without an explicit opt-in fails closed. MiSTer capture is selected with
`target: mister` and requires a generation and qualification in the config. The
shared archive is claimed by its first writer and cannot mix target results.

`jtutil regression` collects PNG video frames from a connected SiDi128 using
local RBF files for manual captures, or a successful GitHub `Compile all` or `Compile SiDi128`
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

Automatic regression selects a completed, successful run from either
`compile-all.yaml` or `compile-sidi128.yaml`. It looks for that run's ZIP
(`a405f1b.zip` for a full build, `a405f1b-sidi128.zip` for SiDi128 only) in
`/gdrive/jotego/core-builds`. If present, the ZIP is reused without downloading
it. Otherwise, the exact GitHub artifact is downloaded into that directory.
Discovery uses the run's completed success conclusion and finds its matching
unexpired artifact across all artifact pages. GitHub can retain a same-named
artifact from an earlier retry, so discovery selects the newest matching one.
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

## Build only SiDi128

`Compile SiDi128` (`.github/workflows/compile-sidi128.yaml`) is manual-only.
After the workflow is published on GitHub, launch it remotely with:

```sh
gh workflow run compile-sidi128.yaml --repo jotego/jtcores --ref master
```

Use `--ref <branch>` to build another branch containing the workflow. It uses
the same core inventory, release-mode compiler and target exclusions as the
full workflow, but calls `xjtcore.sh <core> sidi128` with no other FPGA target.
The resulting bundle contains `release/sidi128`, matching `release/mra` and
resource statistics. Failed core jobs retain diagnostic logs; the final bundle
is produced only after all matrix jobs succeed. Its `<commit>-sidi128.zip` name
keeps it separate from a full-platform ZIP for the same commit.

No extra cron entry is needed: the existing regression poll checks both build
workflows. A completed source commit is tested only once, regardless of which
workflow produced the selected build. Both workflows remain subject to the
successful-run, artifact, creation-time and resume checks.

Deleting `regression/log` removes completion history. Before discarding an old
capture collection, advance `builds-since` to the new baseline's build window
so polling does not replay the old builds. This is an operational cutoff, not
a test that arbitrary branch builds contain a particular source fix.

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

The Gitea workflow `.gitea/workflows/hardware-regression.yaml` polls nightly
at 03:00 in the Gitea scheduler's timezone and also accepts a manual
`workflow_dispatch`. Jobs run on the native
`regression-host:host` runner with a 1440-minute (24-hour) timeout. Configure the
runner's timeout to `24h` and the Gitea server's `[actions] ENDLESS_TASK_TIMEOUT`
to at least `25h`; Gitea 1.26 has an independent server limit (default `3h`).
Register the runner for this repository, enable its service at boot, and allow
two concurrent jobs so scheduled busy checks can finish while a campaign runs.

Before cloning, an inline `flock` check skips busy polls. The command still
acquires the same lock to cover races. The lock file is never deleted: file
existence does not mean it is held. Cleanup checks availability after execution
and leaves any other process's lock untouched.

Each available job shallow-clones current Gitea `master` (depth 1, without
submodules) into a private temporary directory and sources `setprj.sh`. Required
host tools include Go, Python, Git, `gh`, `flock`, a C++ compiler, `mra`, and the
configured FTP capture helper. The runner account supplies its existing GitHub
credentials, ROM collection and netrc. Do not replace `GH_TOKEN` or `GITHUB_TOKEN`
with a Gitea job token. Validate the workflow manually before scheduled use.

Repository Actions secrets:

- `JOTEGO`: private support-files directory, never a literal workflow path.
- `REGRESSION_CONFIG`: machine YAML, including board/helper/firmware settings.
  Source and results always come from the temporary checkout and `$JOTEGO`.

The workflow requests `contents: read` and `issues: write` for its built-in
Gitea job token. `jtutil regression --publish-to gitea` reads `GITEA_SERVER_URL`,
`GITEA_REPOSITORY`, and `GITEA_TOKEN`. It requires a private destination and
creates one issue per tested commit, updates the same issue on interruption
and completion, and searches all issue pages to recover a lost receipt.
Successful campaigns also get reports; idle and busy polls do not. Gitea and
GitHub publication receipts are independent. GitHub remains the default CLI
report destination; `--no-publish` suppresses external reporting.

Detailed command output stays in private runner diagnostics under
`${XDG_STATE_HOME:-$HOME/.local/state}/jtcores-regression`, with campaign results
in `$JOTEGO/regression/log`. Actions output uses generic status messages to avoid
printing internal paths, configuration or helper errors. Temporary checkout and
configuration files are removed on completion and cancellation. Resume identities
use input names, roles and contents, so a new temporary checkout does not force
recapture. Legacy identities can be upgraded when resumed in their original
checkout; an old interrupted campaign should finish there before switching.

Eligibility uses both `doc/mame.xml` and `doc/custom.xml`, matching `jtframe mra`.
Regression selects native-video MRAs. Additional interlaced CRT variants
(`COREMOD_CRT480I` in the index-1 mode ROM) are omitted from automatic,
local, JTBIN and archived manual inventories, even when they share a main
game's setname. Other duplicate main tuples remain an inventory error.
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
2026-10-31 13:21:05 f848902       PASS        a1b2c3d4 mister.home
```

Columns are completion date (10, `YYYY-MM-DD`), local time (8), short commit
(13, allowing `-dirty`), verdict (11), reference CRC (8 hexadecimal digits),
and the configured SSH host or address of the MiSTer that ran the check.
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

`--core` accepts comma-separated core names; `--cores` is an alias. `--setname`
also accepts comma-separated game names. Multi-core local and JTBIN captures
run serially under the same regression lock. JTBIN selections must identify one
jtcores source commit across all selected RBFs.

To capture against an archived build without downloading or modifying the
working project's release tree, use a local archive in `$JOTEGO/core-builds`:

```sh
jtutil regression --commit 4401da8 --core 1943,gng
jtutil regression --commit 4401da8 --core cps1 --setname 1943,1943a
```

The archive supplies both the SiDi128 RBF and authoritative MRA. Selected
MRAs are converted with the current project's tools and ROM source, while
per-core generated ROM/ARC/RAM inputs are staged separately. A short SHA must
resolve through local Git history or a unique full-SHA archive filename; use a
full 40-character SHA when that information is unavailable. The command does
not contact GitHub or infer the current checkout as the archive identity.

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

## Review and queue commands

The shared lock also protects review actions from running while a capture is
changing the same result tree:

```sh
jtutil regression --busy
jtutil regression --status
jtutil regression --accept splatter
jtutil regression --accept cps1,cps2
jtutil regression --reject splatter --reason "reviewed against MAME"
```

`--busy` (or `-b`) prints `Regression in progress` and exits 0 only while the
shared `log/lock` is held; when idle it prints exactly `no regression in
progress` and exits 1 without Cobra's error or usage text. It checks the live
flock, not the mere presence of the lock file.

`--accept <setname>` accepts one game when its name resolves to exactly one
core folder. `--accept <core>[,<core>...]` accepts every pending game in the
named core folders; a single value matching a core folder uses this form too.
Core names are validated before any promotion, and missing core folders fail
the request. Each game must have exactly one pending `new/` or `fail/` slot
with valid PNG frames; an empty set, all-black set, or a set where more than
half of the frames have identical pixels is rejected. Each accepted slot
becomes `ref/`, replacing any prior reference without keeping a backup. The
per-game `log` gets an ACCEPT row with the resulting reference CRC. Acceptance
validation exits use distinct codes:
2 no frames, 3 invalid PNG, 4 all black, 5 majority-identical frames, 6
missing/ambiguous source slot, and 7 unsafe setname or core name.

`--reject <setname>` removes existing `new/` and/or `fail/` slots and appends a
REJECT row with the current reference CRC. `--reason` adds a single-line reason
to that event and is valid only with `--reject`.

`--status` reports total PASS, FAIL, NEW, ERROR, UNSUPPORTED, ACCEPTED and
REJECTED outcomes from the latest per-game history or review event, then lists
FAIL and ERROR games by core. A later review event replaces the older result
label in the current summary without changing that historical check row. For
older result folders without history, a pending `fail/` or `new/` slot is
reported as FAIL or NEW. A reference folder by itself is not treated as
evidence of a PASS.

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
jtutil regression --config ~/.config/jtutil/regression.yaml --run-id 40831867014 --no-publish
```

`--run-id` pins a GitHub workflow run ID. An unambiguous workflow run number
is also accepted; if both workflows share that number, use the full run ID.
Without it, the command
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

`new/` contains only collected PNG frames awaiting review, including black or
uniform frames when the capture itself is complete and decodable. The collector
never creates or approves `ref/`. A designer may promote inspected captures to
`ref/`; `jtutil mame-frames` may also promote a capture after exact ordered MAME
validation and final progress/digest checks. Existing references remain
read-only inputs to later exact-pixel comparisons. A mismatch is retained in
`fail/` as PNGs; comparison details belong in the run log.

Progress and readable results are stored in the commit's JSON/text log pair
under `$JOTEGO/regression/log/`. Frame receipts and helper reports are temporary
working data, removed after the game.

Each regression game gets a private, unique `/tmp/jtutil-regression-capture-*`
workspace for its effective CAB, RAW downloads, intermediate images and helper
reports. It is removed after the game on success or failure, after publishing
complete results and recording useful errors in the commit log. Reference
receipt checks also use short-lived `/tmp/jtutil-regression-receipt-*`
directories. RAW capture files are not published to the results directory.
ROMs, source checkouts, executables and machine configuration do not belong there.

The outer capture deadline allows for execution, capture pauses and retrieval:
120 seconds plus one tenth of a second per configured frame, capped by
`timeout-seconds` (900 seconds by default). Independent progress checks still
bound stalled playback and capture operations. Failed helper diagnostics are
summarized in the commit log before temporary files are removed.

## MAME frame validation

Use MAME to compare completed `new/` folders across all cores, or select a
single setname:

```sh
jtutil mame-frames
jtutil mame-frames --setname hyperspt --dryrun
jtutil mame-frames --jobs 1
jtutil mame-frames --config ~/.config/jtutil/regression.yaml
jtutil mame-frames --legacy-sidi128
```

Completed games validate concurrently, up to four at a time by default. Use
`--jobs N` to set a positive concurrency limit. Command output is sorted by
core/setname; log rows are appended as games finish.
Cancellation stops pending work, waits for active MAME/OCR
children to exit, and removes their temporary workspaces.

MAME resolves the same global/core/setname profile used by `jtutil regression`.
The default global profile is `modules/jtframe/bin/reg.yaml`; pass the same
`--config` file used for regression when it selects a custom global profile.
Validation uses the current checkout's profile, because `new/` stores PNGs and
does not carry the CAB input script.
Only the profile's explicit `inputs` path is used, resolved under
`cores/<core>/ver/<setname>/`; an unselected `reg.cab` is ignored. A profile
without inputs uses neutral inputs. The CAB exporter clips or pads that script
to the profile's `video` frame budget, and MAME applies each logical input run
at the matching frame before continuing with neutral inputs through the extra
500 comparison frames. Inputs must map to enabled MAME control fields. CAB
reset, test, DIP switch, dump, and unknown controls currently fail validation
with a per-game error rather than being skipped.

MAME captures every emulated frame from startup through 500 frames beyond the
largest requested or actual FPGA checkpoint when that fits the supported
visible-window startup bypass. MAME's unattended startup bypass requires a
finite `-seconds_to_run` value below 300 seconds; the command chooses the
smallest such duration covering all requested frames and the 500-frame search
grace. Longer requests fail before MAME starts rather than truncating the
frame sequence. Its wall-clock timeout is
`min(300, ceil(1.1 * frame_limit / refresh_hz))` seconds, using the selected
machine's MAME screen refresh rate. MAME runs unthrottled with sound disabled
in a visible `-window` using native snapshots and rotation disabled; the host
must have a working graphical display. Configuration, snapshots and NVRAM use
an isolated per-game directory under `/tmp`; ROMs come from `~/.mame/roms`.
Configured JTFRAME NVRAM defaults are loaded into the MAME device path after a
bounded probe identifies it. Ambiguous or unresolved defaults fail validation.
The user's saved `~/.mame/nvram` is not read or changed.
The guarded `simson/simpsons` and `simson/vendetta` mappings verify each full
144-byte JTFRAME seed, then load its first 128 bytes into MAME's 128-byte ER5911
EEPROM. The FPGA's 7-bit address bus and IOCTL dump reach addresses 0–127; the
trailing 16 bytes are unmapped by that hardware.
For shouse games with a 63,552-byte seed, the full JTFRAME default is checked
against generated MRA/RAM files when present before its first 2,048 bytes are loaded into
the probed `<setname>/nvram` device. The FPGA restores only the AW11/DW8 EEROM
at IOCTL order 0; the trailing 61,504 bytes are debug RAM and are not restored
at startup. MAME's namcos1 NVRAM is a RAM share, not a ROM region, so capacity
comes from the isolated probe's actual device file.

The current source's `JTFRAME_COLORW` is resolved for the configured archive
target. MiSTer captures retain the full native per-channel width configured by
`JTFRAME_COLORW` (currently 4..8 bits). The generic quantizer accepts 1..8-bit
images; this does not expand the widths accepted by JTFRAME macros.
SiDi128's capture transport stores RGB444 when `COLORW` is 4 and RGB555 when
`COLORW` is 5 or greater. Both MAME and FPGA PNG pixels are normalized by
keeping the top bits at that target's capture precision. Low RGB888 bits added
by color expansion do not cause a mismatch; the remaining native color codes
and geometry are compared exactly. No one RGB888 bit-replication pattern is
required. A PASS means exact matches at the selected target's native capture
precision rather than full 8-bit RGB. Matches must use strictly
increasing, distinct MAME frame numbers, so one MAME frame cannot satisfy two
FPGA checkpoints. Startup captures are included. A missing match, invalid
capture format, geometry mismatch, incomplete snapshot run, or capture quality
failure leaves `new/` in place. MAME uses its native unrotated view; exact image
geometry must match, so orientation and crop differences fail comparison.
Checkpoint N denotes the completed native interval N-1, and the matching MAME
frame numbers must advance strictly across the capture schedule. PNG slots do
not record their source color depth, so validation infers it from the current
core and target macros. `--dryrun` performs the same comparison and reports
PASS/FAIL without changing result directories or the MAME validation log.

The archive root owns one immutable target in `.capture-target.json`. The first
writer may claim an empty archive; a nonempty unmarked archive is never assigned
a target automatically. Historical readers and dry runs remain available for
unmarked archives. To deliberately adopt an existing legacy archive, run the
same `jtutil regression` entry point with
`--adopt-legacy-sidi128 --legacy-sidi128 --confirm-legacy-sidi128 sidi128`.
This board-free command holds the archive lock, requires an explicit SiDi128
confirmation, rejects MiSTer provenance, and only adds the immutable target
marker; it does not rewrite historical results. Legacy SiDi128 MAME log and
promotion writes still require `--legacy-sidi128`. SiDi128 and MiSTer results
cannot share a writable archive.

The first unmatched checkpoint reports `no matches after frame N`. If a later
MAME frame matches its entire interior and differs only on the outermost top,
bottom, left or right pixel line, it reports `boundary differences at frame N`
instead. This remains a FAIL; the border is excluded only to diagnose the
mismatch, never to qualify a reference.

SiDi128 promotion requires a matching finalized regression progress entry, a
stable PNG digest, no active run for the game, and an absent `ref/` immediately
before rename. MiSTer promotion additionally requires the configured capture
generation and qualification, a completed protocol-v2 or protocol-v3 NEW finalization, and a
matching image receipt/provenance inventory. It records the same
`reference-provenance.json` used by explicit MiSTer curation. Historical MiSTer
captures without supported protocol-v2 or protocol-v3 provenance remain comparable but cannot be
promoted by this command. Games with active, stale or unverifiable progress can
still be compared read-only; an exact pixel PASS stays PASS when promotion is
withheld. Exact-match results and failures are appended to the fixed-width
`$JOTEGO/regression/log/mame-frames.log` only after the archive target guard.
Each game's
temporary MAME workspace is removed after completion or interruption.
The shared NFSv3 filesystem has no atomic no-replace directory rename; the
command checks `ref/` immediately before rename and reports detectable conflicts.

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

With `--commit`, omitting both selectors captures every eligible root/main MRA
in the archive; `--core`/`--cores` and `--setname` filter that inventory by
intersection. Every requested core and game name must match. Current source
`skip:true` and debug exclusions are omitted for an unfiltered run; explicitly
requesting an excluded game fails before its ROM conversion. Local and JTBIN
multi-core captures also run serially under one lock, and a multi-core JTBIN
selection is rejected if its RBF history points to different jtcores commits.
