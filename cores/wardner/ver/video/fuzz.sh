#!/usr/bin/env bash
# Random-snapshot fuzz: ./fuzz.sh [count] [first seed]
# Seeds 1000+ are dense (512 overlapping sprites), the rest sparse.
set -u
cd "$(dirname "$0")"
N=${1:-10}; S=${2:-1}; fail=0
for ((i=0; i<N; i++)); do
    seed=$((S+i)); d=fuzz/s$seed; extra=""
    [ $seed -ge 1000 ] && extra=--dense
    python3 gen_snap.py "$d" "$seed" $extra > "$d.log" 2>&1 || { cat "$d.log"; exit 1; }
    if ./run.sh "$d" +lat=$((seed % 5)) >> "$d.log" 2>&1; then
        echo "seed $seed: match ($(grep -o 'overflow=[01]' "$d.log"))"
    else
        echo "seed $seed: MISMATCH"; tail -4 "$d.log"; fail=$((fail+1))
    fi
done
echo "$fail failures in $N runs"
[ $fail -eq 0 ]
