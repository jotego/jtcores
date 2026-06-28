#!/bin/bash
# Build a native-res (1:1) H.264 mp4 from the sparse on-change sim frames + audio.
# Usage: build_sim_mp4.sh <out.mp4>
# A/V sync is derived from the data: video span is stretched to match test.wav's
# duration, so the two always line up regardless of the exact refresh rate.
set -e
OUT="$1"
G="$(cd "$(dirname "$0")/game" && pwd)"
WAV="$G/test.wav"
LIST="$G/.concat.txt"

ADUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$WAV")
echo "audio duration: ${ADUR}s"

python3 - "$G/frames" "$LIST" "$ADUR" <<'PY'
import os,re,sys
fdir,listp,adur=sys.argv[1],sys.argv[2],float(sys.argv[3])
fr=[]
for n in os.listdir(fdir):
    m=re.match(r'frame_(\d+)\.png$',n)
    if m: fr.append((int(m.group(1)),os.path.join(fdir,n)))
fr.sort()
span=fr[-1][0]-fr[0][0] or 1
R=span/adur                      # effective frames/sec so video==audio length
with open(listp,'w') as f:
    for i,(num,p) in enumerate(fr):
        nxt=fr[i+1][0] if i+1<len(fr) else num+1
        f.write("file '%s'\nduration %.6f\n"%(os.path.abspath(p),(nxt-num)/R))
    f.write("file '%s'\n"%os.path.abspath(fr[-1][1]))
print("frames=%d span=%d eff_fps=%.3f"%(len(fr),span,R))
PY

# 1:1 native pixels (no scaling), constant 60fps for clean playback, decent crf.
ffmpeg -y -f concat -safe 0 -i "$LIST" -i "$WAV" \
    -vf "fps=60" -c:v libx264 -pix_fmt yuv420p -crf 18 -preset slow \
    -c:a aac -b:a 192k -shortest -movflags +faststart "$OUT"
echo "wrote $OUT ($(du -h "$OUT" | cut -f1))"
