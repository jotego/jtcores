# Hardware video regression

`jtutil regression` runs every game that has a CAB file on MiSTer boards and
compares the captured frames with the approved references. `jtutil mame-frames`
approves new captures that match MAME. A designer reviews the rest. Audio is not
part of this workflow, and a passing comparison only says that the video did
not change.

## Core support

The capture needs the `JTFRAME_REGRESSION` macro, which normal full-HDMI MiSTer
builds (`jtcore <core> -mr`) define by default. Builds without HDMI (`-mrq`,
`-qq`, credits mode, `MISTER_DEBUG_NOHDMI`) remove it; `-u JTFRAME_REGRESSION`
disables it explicitly. Under the project's macro-presence semantics a value of
`0` still enables it. Cores that use DDR for video all the time
(`JTFRAME_LF_BUFFER` in DDR, `JTFRAME_MR_GAME_DDR`) have no regression support,
because the capture writer needs the core's video DDR port. CRT480I and
interlaced builds cannot capture. Vertical games are captured unrotated, with
the Video Rotate option set to No.

A core with `JTFRAME_REGRESSION` must still play normally with a stock Main
that lacks the regression commands. Capture and CAB replay need the matching
Main build.

The checkpoint of a captured frame is in the range 1..32767: checkpoint N is
the frame that ends native interval N-1. A Main capture session has a 300-second
wall-clock deadline, so the checkpoint range does not allow a 32767-frame
session.

## Capture block

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


## Games and CAB files

A game takes part when `cores/<core>/ver/<setname>/reg.cab` exists.
`modules/jtframe/devops/reg-cabs.sh` copies those files to `release/cab/<setname>.cab`;
compile-all runs it, so its zip carries them. The CAB grammar is that of
`jtsim` (see `modules/jtframe/verilator/cabinet.cpp`); the Go reader in
`regression/cab.go` shares its golden vectors. A regression CAB starts with
`capture N` and the hardware captures frames N, N+100, ... up to the last CAB
line, which must be below 32768. The frame files are `frame_%08d.png`, numbered
by CAB line.

## Running

```sh
jtutil regression --commit <hash>   # $JOTEGO/core-builds/<short hash>.zip
jtutil regression --poll            # newest successful compile-all build
jtutil regression --core <core>     # one core from the working tree
```

`--commit` takes any commit name that git resolves and unpacks `release/mister`,
`release/cab` and the top-level MRA files of the compile-all zip named after
its 7-character short hash. `--poll` asks `gh` for the latest successful
compile-all runs and takes the newest one. It stops when that commit was
already tested, downloads the zip when it is missing and goes on to the next
older run only when the local checkout does not know the commit or the zip
cannot be had. It does nothing when another
regression holds the lock. `--core`
builds a release folder from the working tree: the RBF from
`$JTROOT/release/mister` (build it with `jtcore <core> -mr`), the MRA files from
`jtframe mra` and the `reg.cab` files of the core. It needs `JTUTIL` set to the
folder that holds `beta.bin`, so that beta MRA files load. A dirty tree is
allowed and is marked as such.

The release folder goes to `/media/fat/_<short hash>` of each board with `jtbin2mr`.
That needs `MISTERPASSWD` and wipes the core settings of the board; a board
whose copy takes over 10 minutes is left out. The boards are given by
`--boards` (`mister.home`, `mister2.home` and `mister3.home` by default) and
share one SSH connection each. Every board takes the next game from a shared
queue:

1. check SSH, Main and its FIFO `/dev/MiSTer_cmd`
2. clear `/tmp/jtcap` and `/tmp/MiSTer.log` and send `load_core <mra>`
3. wait for the state `loaded` in `/tmp/jtcap/status.json`, at most
   `--load-limit` (30 s)
4. send `cab_session_start <setname> <cab>` and wait for `done`, at most
   1.2*(M+1)/50 seconds for a CAB whose last line is M (50 Hz is the lowest
   refresh rate of the cores)
5. check that the status is protocol 3 for this game, fetch
   `/tmp/jtcap/<setname>/*.png` and check that every capture frame is there

An operational error is retried once, preferably on another board, and is then
recorded as ERROR with the Main logs. The board reboots after each error and
leaves the run if it does not come back. Frame mismatches are not retried.

## Results

Each game has a folder `$JOTEGO/regression/<core>/<setname>/`:

| Folder | Content |
|---|---|
| `ref/` | approved reference frames |
| `new/` | captured frames of a game without `ref/` |
| `fail/` | captured frames that differ from `ref/`, with `MiSTer.log` |
| `error/` | Main logs of the failed attempts |
| `rejected/` | frames rejected in review |
| `log` | one row per result or review action |

A capture identical to `ref/` clears `new/`, `fail/`, `error/` and `rejected/`.
Any other result replaces its own folder and removes the others, except that an
error keeps `new/`, `fail/` and `rejected/`. `ref/` is changed only by the
review commands and by `mame-frames`.

A `log` row has the time, who wrote it (the short commit, `manual` or `mame`),
the verdict and the CRC32 of `ref/`, or `--------` when there is none:

```
2026-11-23 14:01:07 ea28925       NEW         --------
2026-11-24 08:48:51 manual        ACCEPT      a35cb818
```

Each run keeps its progress in `$JOTEGO/regression/log/<short commit>.json`
and a text log beside it; a `--core` run uses `manual-<short commit>[-dirty]`
so it never marks a commit as tested. Running the same commit again resumes it;
`--commit` also reruns its ERROR games and `--core` reruns everything.
`log/lock` is the flock that keeps one regression, review or `mame-frames`
promotion at a time.

A full run publishes a summary with `--publish-to`: `github` (an issue in
jotego/jtcores, through `gh`), `gitea` (an issue in `GITEA_REPOSITORY` at
`GITEA_SERVER_URL`, with `GITEA_TOKEN`; the repository must be private) or
`none`. `--core` runs publish nothing.

## Review commands

```sh
jtutil regression --review
jtutil regression --accept splatter
jtutil regression --accept cps1,cps2
jtutil regression --unaccept bodyslam
jtutil regression --reject splatter
```

They take a setname or a core; a core acts on all of its pending games. They
take the shared `log/lock` and fail while a regression runs. Each appends a
`manual` row to the game's `log`.

`--accept` makes the pending `new/` or `fail/` frames `ref/`, replacing the old
reference, and logs ACCEPT with the CRC of the new `ref/`.

`--unaccept` turns `ref/` back into `new/` and logs UNACCEPT with `--------`.
It refuses a game that already has `new/` or `fail/` frames.

`--reject` moves `new/` or `fail/` to `rejected/`, replacing an older
`rejected/`, and logs REJECT with the CRC of `ref/`. The next capture of the
game removes `rejected/` unless it ends in an error.

`--review[=address]` serves web pages, at `localhost:8090` by default; use
`--review=:8090` to reach them from other computers. The first page lists the
cores with `new`, `fail`, `error` or `rejected` games. A core page shows every
pending game of the core in one page, with all its frames. A `fail` frame that
differs from `ref` shows the reference, the capture and a picture with the
differing pixels in red. Each game has its own accept and reject buttons and an
exclude box. The button at the bottom accepts every game that is not excluded;
`fail` games start excluded, so a bulk accept does not replace a reference by
mistake. Error games list their Main logs, and rejected games their names.

## MAME frame validation

```sh
jtutil mame-frames [--core <core>] [--setname a,b] [--dryrun] [--jobs 4] \
  [--mame mame] [--rompath ~/.mame/roms]
```

`mame-frames` checks every game that has `new/` and no `ref/`, optionally only
those of one core or some setnames. For each game it:

1. copies `new/` to a work folder under `/tmp`
2. refuses frames that are all black or all identical
3. reads `cores/<core>/ver/<setname>/reg.cab` as it was in the commit that
   captured `new/`, the one in the last NEW row of the game's `log`, with
   `git show` in `$JTROOT`. When git does not have that commit, or the run was
   dirty, it uses the working tree file and says so
4. runs MAME in a window with every setting directory inside the work folder
   and `XDG_CONFIG_HOME` pointed there, so the user's MAME setup is not used
5. seeds MAME's NVRAM with the defaults of the game: `cfg/<setname>.nvm` (or
   that of its parent), the NVRAM defaults or NVRAM region of
   `cfg/mame2mra.toml`, or the index-2 data of the generated MRA in
   `$JTROOT/release/mra`. Declared defaults must agree with the generated MRA
   and `rom/<SETNAME>.RAM` when those exist
6. replays the CAB inputs, one CAB line per MAME frame, and saves every frame
   up to 500 frames past the last captured one. The emulated time, which also
   skips MAME's startup screens, may not exceed 299 seconds; the wall-clock
   limit is that time plus 10%, at most five minutes
7. matches each captured frame, in order, with the first MAME frame after the
   previous match that is equal once the colour channels are cut to the bits
   that the MiSTer video keeps. `arcade_video` passes only the top 4 bits of
   each channel unless the video is 24-bit, and `jtframe_mister` sends
   `JTFRAME_COLORW` 5 and 8 as 24-bit video. So COLORW 5 and 8 compare at 5 and
   8 bits and any other width at COLORW bits, at most 4. COLORW comes from the
   core's MiSTer macros, parsed in a separate `jtutil` process, so a broken
   core only fails its own games

The CAB input bits map to MAME's COIN, SERVICE1, START, P1/P2 joystick and
button 1-3 tokens. `test`, `reset`, `dipsw=`, `cheat=` and `dump` cannot be
replayed and fail the game. When a frame does not match, the output says whether
it only differs in its outer pixel border.

A match is PASS: `new/` becomes `ref/`, as with `--accept`, and the game's log
gets an ACCEPT row by `mame`. The promotion takes `log/lock` and checks that
`ref/` is still absent and that `new/` did not change during the comparison.
While a regression run holds the lock, a match is reported as BUSY and the game
is left as it is. A mismatch is FAIL and changes nothing. `--dryrun` compares
and promotes nothing. The output has one line per game and a final count.

## Gitea workflow

`.gitea/workflows/hardware-regression.yaml` runs `jtutil regression --poll
--publish-to gitea` on the `regression-host` runner. It is started by hand for
now. It checks `log/lock` first and skips the run when a regression is going
on, clones master without submodules into a temporary folder, sources
`setprj.sh` and runs `modules/jtframe/bin/regression-action.sh`, which builds
`jtutil` and runs it in the background so that a cancellation reaches it.

The `JOTEGO` repository secret names the private storage. The runner account
needs `MISTERPASSWD` for `jtbin2mr`, SSH access to the boards and its own `gh`
login for the compile-all builds; the Gitea token comes from the job. The job
output stays short: the `jtutil` output goes to
`~/.local/state/jtcores-regression/action-<run>-<attempt>.log` on the runner.
