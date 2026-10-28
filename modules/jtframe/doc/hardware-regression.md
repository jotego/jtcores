# SiDi128 video regression

`jtutil regression` runs the main-game inventory from a successful GitHub
`compile_all` artifact on a permanently connected SiDi128. It loads each game
through its generated ARC, plays the profile CAB (or neutral inputs), captures
native RGB444/RGB555 video every 100 CAB frames, compares exact pixels after
the startup cutoff, and saves the result and report under `$JOTEGO/regression`.
Audio is not part of this workflow.

## Host setup

Set `JOTEGO` to the persistent private data directory. Create
`$JOTEGO/regression/config.yaml` with machine-specific settings:

```yaml
host: 192.0.2.10
netrc: /home/regression/.netrc
control-helper: /path/to/regression/tools/ftp-control.py
cab-packer: /path/to/regression/cache/cab-pack/cabinet_pack
source: /path/to/jtcores
firmware: ATH261028
firmware-sha256: <64-digit digest of verified flashed firmware>
cab-exporter-sha256: <64-digit digest of the pinned cabinet_pack binary>
capture-tool-sha256: <composite digest of ftp-control.py and cabinet_pack>
mra-converter: mra
rom-source: /path/to/mame/roms
rom-source-extra:
  - /path/to/extra/rom/archives
```

Use a private netrc file readable only by the regression account. The host,
paths, firmware identity and credential file belong in configuration, not in
source code. The CAB packer and its cache should live under the regression data
directory. The command checks the configured exporter digest before using the
board. A source worktree for each build is checked out at the tested SHA.

## Profile settings

The global defaults are kept in `$JOTEGO/regression/reg.yaml` and initially
contain:

```yaml
video: 4000
start-up: 500
```

Per-game entries in the exact source SHA's `cores/<core>/cfg/reg.yaml` override
the defaults. `inputs` selects a CAB path relative to that game's `ver` folder;
without it the runner creates an idle CAB. `video` sets total CAB frames and
`start-up` excludes checkpoints at or below that frame from comparison. For
example:

```yaml
1942:
  inputs: reg.cab
  video: 4000
  start-up: 500
  dipsw: ef77
```

The only extra setting currently mapped to CAB playback is `dipsw`. Other
simulation-only or unsupported keys become per-game preparation errors rather
than being silently ignored. Captures are requested at 100, 200, ... through
`floor(video/100)*100`. Startup images are retained but excluded from exact
comparison; late startup actual frames are kept with their actual identity.
The CAB exporter uses an explicit profile-prefix budget for regression runs:
it clips a longer source CAB at the profile frame count, pads a shorter script
with idle frames, and records the original CAB hash, prefix mode, and budget in
the result identity. Direct exporter calls keep their existing strict default.

## Running and stored outcomes

Run `jtutil regression` to discover the oldest eligible successful build,
prepare its exact-source main-game inventory and fixtures, then process or
resume that build. `--once` is implicit: an external scheduler can invoke the
command every 15 minutes. `--run-id <id>` pins a specific workflow run. A
prebuilt JSON manifest can be supplied with `--manifest <path>` for controlled
pilots. The first baseline run uses `--initial-baseline`; it requires automatic
artifact and complete-inventory preparation and only fills missing references.
The option is restricted to the explicitly authorized build.
Ordinary runs never modify `ref/` automatically.

Each game has exactly these result slots:

```text
$JOTEGO/regression/<core>/<setname>/{ref,fail,new}/
```

`new` means a complete capture needs a developer-approved reference. `fail`
contains a complete exact-pixel mismatch and `comparison.json`. A matching run
removes stale `fail/`. Invalid/incomplete executions are recorded as `error`
without publishing captures as evidence. Known target exclusions are recorded
as `unsupported` and do not require attention.

Batch events, summary and JUnit output are stored under
`$JOTEGO/regression/log/<run-id>/`. Interrupted batches retain pending games;
finished games are verified from their stored identity before a resume skips
them. `--retry-errors` reruns terminal per-game errors from a fresh ARC launch.
The runner deletes each run-owned ARC file set after use and defers removal of
its loaded ARC directory until a later `SITE LOAD` moves the firmware's current
directory. Any final pending upload directories remain listed in
`$JOTEGO/regression/state/upload-directories.json` for the next invocation.
Master builds create a GitHub issue and PR builds comment on the source PR.
Reports do not upload images; they point to the retained Drive result folders.
