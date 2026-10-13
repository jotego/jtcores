#!/bin/bash
# Attract battery: free-run each set (no inputs) for $FRAMES frames, archive
# frames (every 10th + last) + frames.crc under ver/<set>/sim_results/attract/,
# report distinct-CRC count and the first frame where the screen changes.
# Usage: ./attract_run.sh [set ...]
set -uo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
JTROOT=$(cd "$HERE/../../.." && pwd)
ROMS_HOST="${ROMS_HOST:-$HOME/.mame/roms-local}"
IMAGE=${IMAGE:-jotego/simulator:arm64}
FRAMES=${FRAMES:-1000}

SETS=("$@")
[ ${#SETS[@]} -eq 0 ] && SETS=(charlien hvysmsh candance joemacra chainrec magdrop magdropp prtytime gangonta hvysmsha hvysmshj)

for set in "${SETS[@]}"; do
    bash "$HERE/prepare_nvram.sh" "$set" "$HERE/game/nvram.seed" || exit 1
    docker run --platform linux/arm64 --rm -v "$JTROOT:/jtcores" \
        -v "$ROMS_HOST:/root/.mame/roms:ro" -w /jtcores --entrypoint bash "$IMAGE" -c "
unset VERILATOR_ROOT
source modules/jtframe/bin/setprj.sh --quiet
cd cores/osman/ver/game
jtsim -setname $set -load -video $FRAMES
" > /tmp/osman_attract_$set.log 2>&1
    if ! grep -q "JTSIM finished" /tmp/osman_attract_$set.log; then
        echo "$set: FAIL (see /tmp/osman_attract_$set.log)"
        continue
    fi
    dest="$HERE/$set/sim_results/attract"
    rm -rf "$dest"; mkdir -p "$dest"
    cp "$HERE/game/frames/frames.crc" "$dest/" 2>/dev/null
    cp /tmp/osman_attract_$set.log "$dest/sim.log"
    files=$(ls "$HERE/game/frames" | grep '^frame_.*\.png$' | sort)
    n=$(echo "$files" | wc -l | tr -d ' ')
    i=0
    while IFS= read -r f; do
        i=$((i+1))
        if [ $((i % 10)) -eq 1 ] || [ $i -eq $n ]; then
            mv "$HERE/game/frames/$f" "$dest/"
        fi
    done <<< "$files"
    total=$(wc -l < "$dest/frames.crc" | tr -d ' ')
    uniq=$(sort -u "$dest/frames.crc" | wc -l | tr -d ' ')
    first=$(awk 'NR==1{a=$1} $1!=a{print NR; exit}' "$dest/frames.crc")
    last=$(ls "$dest" | grep '^frame_' | sort | tail -1)
    echo "$set: frames=$total distinct=$uniq first_change=${first:-never} shot=$dest/$last"
done
