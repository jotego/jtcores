#!/bin/bash
# Run a 500-frame Verilator simulation for a jtcores core via Docker.
#
# Usage: ./sim-core.sh <core> [setname] [extra jtsim args...]
#   <core>     folder under cores/ (e.g. kicker, 1942, gng)
#   [setname]  MAME setname (e.g. kicker, shaolinb). Defaults to <core>.
#
# Requirements:
#   - Docker Desktop running
#   - MAME romset zips at ~/.mame/roms/<setname>.zip
#   - jotego/simulator image (auto-pulled on first run)

set -euo pipefail

FRAMES=${FRAMES:-500}

JTROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Pick the container arch from the host. On Apple Silicon the native
# linux/arm64 simulator image runs ~5-10x faster than the emulated
# linux/amd64 one. amd64 stays the default everywhere else (incl. CI). Both
# PLATFORM and IMAGE can be overridden from the environment; IMAGE and the
# jtframe binary arch follow the resolved PLATFORM (so forcing
# PLATFORM=linux/amd64 on an arm64 host also picks the amd64 image+binary).
case "$(uname -m)" in
    arm64|aarch64) PLATFORM=${PLATFORM:-linux/arm64} ;;
    *)             PLATFORM=${PLATFORM:-linux/amd64} ;;
esac
case "$PLATFORM" in
    *arm64) IMAGE=${IMAGE:-jotego/simulator:arm64}; JTFRAME_BIN_ARCH=linux-arm64 ;;
    *)      IMAGE=${IMAGE:-jotego/simulator};       JTFRAME_BIN_ARCH=linux-amd64 ;;
esac

# The jtframe Go binary is arch-specific and shared via the mounted repo, so
# make the canonical copy match the container arch (a wrong-arch binary just
# fails to exec inside the container). The suffixed binaries are gitignored.
JTFRAME_BIN="$JTROOT/modules/jtframe/src/jtframe/jtframe"
if [ -f "$JTFRAME_BIN.$JTFRAME_BIN_ARCH" ] && \
   ! cmp -s "$JTFRAME_BIN.$JTFRAME_BIN_ARCH" "$JTFRAME_BIN"; then
    cp -f "$JTFRAME_BIN.$JTFRAME_BIN_ARCH" "$JTFRAME_BIN"
fi
# Romset dir mounted into the container. Defaults to the usual ~/.mame/roms
# (a symlink to the network share); override with ROMS_HOST when the share is
# offline and you want the local copy, e.g. ROMS_HOST=~/.mame/roms-local
ROMS_HOST="${ROMS_HOST:-$HOME/.mame/roms}"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <core> [setname] [extra jtsim args...]" >&2
    exit 1
fi

CORE=$1
shift
SETNAME=${1:-$CORE}
if [ $# -ge 1 ]; then shift; fi
EXTRA_ARGS="$*"

if [ ! -d "$JTROOT/cores/$CORE" ]; then
    echo "Error: cores/$CORE does not exist under $JTROOT" >&2
    exit 1
fi

if [ ! -d "$ROMS_HOST" ]; then
    echo "Error: ROM directory $ROMS_HOST not found" >&2
    echo "Symlink it to your romset, e.g.:" >&2
    echo "  ln -s '/Volumes/.../MAME ROMs (split)' ~/.mame/roms" >&2
    exit 1
fi

if [ ! -e "$ROMS_HOST/$SETNAME.zip" ]; then
    echo "Error: $ROMS_HOST/$SETNAME.zip not found" >&2
    exit 1
fi

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "Pulling $IMAGE ($PLATFORM)..."
    docker pull --platform "$PLATFORM" "$IMAGE"
fi

echo "Simulating core=$CORE setname=$SETNAME frames=$FRAMES"

docker run --platform "$PLATFORM" --rm \
    -e FRAME_PNG="${FRAME_PNG:-}" \
    -v "$JTROOT:/jtcores" \
    -v "$ROMS_HOST:/root/.mame/roms:ro" \
    -w /jtcores "$IMAGE" -c "
unset VERILATOR_ROOT
source modules/jtframe/bin/setprj.sh --quiet
cd cores/$CORE/ver/game
jtsim -setname $SETNAME -video $FRAMES $EXTRA_ARGS
"

FRAMES_DIR="$JTROOT/cores/$CORE/ver/game/frames"
MP4_OUT="$JTROOT/cores/$CORE/ver/game/${CORE}_sim.mp4"
CONCAT_LIST="$FRAMES_DIR/.concat.txt"

if [ -d "$FRAMES_DIR" ] && ls "$FRAMES_DIR"/frame_*.jpg >/dev/null 2>&1; then
    echo
    echo "Encoding $MP4_OUT (with gap-filling to 60 Hz) ..."

    # The simulator only writes a JPEG when the screen changes, so frame
    # numbering has gaps (e.g. 0, 1, 15, 16, 18). To produce a real-time
    # 60 Hz video we use ffmpeg's concat demuxer and tell it to hold each
    # frame for (next_frame_number - this_frame_number) / 60 seconds.
    python3 - "$FRAMES_DIR" "$CONCAT_LIST" <<'PY'
import os, re, sys
frames_dir, list_path = sys.argv[1], sys.argv[2]
pattern = re.compile(r'frame_(\d+)\.jpg$')
frames = []
for name in sorted(os.listdir(frames_dir)):
    m = pattern.match(name)
    if m:
        frames.append((int(m.group(1)), os.path.join(frames_dir, name)))
with open(list_path, 'w') as f:
    for i, (n, path) in enumerate(frames):
        f.write(f"file '{path}'\n")
        nxt = frames[i+1][0] if i+1 < len(frames) else n+1
        dur = max(nxt - n, 1) / 60.0
        f.write(f"duration {dur:.6f}\n")
    # concat demuxer requires the final file to be repeated without duration
    f.write(f"file '{frames[-1][1]}'\n")
PY

    WAV_IN="$JTROOT/cores/$CORE/ver/game/test.wav"
    if [ -f "$WAV_IN" ]; then
        # Mux the simulator's audio dump into the same mp4 alongside the
        # gap-filled video. -shortest stops the file at whichever stream
        # ends first (usually video, since the sim picks a frame count).
        ffmpeg -y -f concat -safe 0 -i "$CONCAT_LIST" \
               -i "$WAV_IN" \
               -vf "fps=60,scale=trunc(iw/2)*2:trunc(ih/2)*2" \
               -c:v libx264 -pix_fmt yuv420p -preset veryfast \
               -c:a aac -b:a 192k \
               -shortest \
               "$MP4_OUT" 2>&1 | tail -3
        echo "MP4 (with audio): $MP4_OUT"
    else
        ffmpeg -y -f concat -safe 0 -i "$CONCAT_LIST" \
               -vf "fps=60,scale=trunc(iw/2)*2:trunc(ih/2)*2" \
               -c:v libx264 -pix_fmt yuv420p -preset veryfast \
               "$MP4_OUT" 2>&1 | tail -3
        echo "MP4 (video only — no test.wav found): $MP4_OUT"
    fi
    rm -f "$CONCAT_LIST"
fi

echo
echo "Done. Frames: cores/$CORE/ver/game/frames/"
