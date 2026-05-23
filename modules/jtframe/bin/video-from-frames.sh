#!/usr/bin/env bash
set -euo pipefail

main() {
    parse_args "$@"
    check_binaries
    collect_frames
    fill_frames
    trap cleanup EXIT
    compute_fps
    encode_video
}

usage() {
    cat <<'EOF_USAGE'
Usage: video-from-frames.sh <frames_dir>

Create an MP4 from numbered frame images by filling missing frame numbers with the
previous available frame. Audio is muxed and video framerate is derived to match the
audio duration.

Arguments:
  <frames_dir>  Directory with files matching frame_00001.jpg ... frame_06522.jpg
                Output file defaults to: <parent-folder-name>.mp4 (e.g. a/frames -> a.mp4)
                Audio is taken from test.wav inside frames dir, then its parent dir.

Options:
  --frame-ext <ext>      Default: jpg
  --crf <0-51>           Default: 18 (lower for better quality)
  --start <num>          Optional explicit first frame number
  --end <num>            Optional explicit last frame number
  --help                 Show this help
EOF_USAGE
}

parse_args() {
    if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
        usage
        exit 0
    fi

    if [ -z "${1:-}" ]; then
        usage
        exit 1
    fi

    frames_dir="${1%/}"
    if [[ ! -d "$frames_dir" ]]; then
        echo "[ERROR] Frames directory not found: $frames_dir"
        exit 1
    fi
    frames_dir="$(realpath "$frames_dir")"
    shift

    frame_prefix="frame_"
    frame_ext="jpg"
    crf=18
    audio_bitrate="128k"
    start_frame=""
    end_frame=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                usage
                exit 0
                ;;
            --frame-ext)
                frame_ext="$2"
                shift 2
                ;;
            --crf)
                crf="$2"
                shift 2
                ;;
            --start)
                start_frame="$2"
                shift 2
                ;;
            --end)
                end_frame="$2"
                shift 2
                ;;
            *)
                echo "[ERROR] Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    local parent_dir
    parent_dir="$(dirname "$frames_dir")"
    output_file="${parent_dir}/$(basename "$parent_dir").mp4"

    audio_file="$frames_dir/test.wav"
    if [[ ! -f "$audio_file" ]]; then
        audio_file="$parent_dir/test.wav"
    fi
    if [[ ! -f "$audio_file" ]]; then
        echo "[ERROR] Audio file not found: $frames_dir/test.wav or $parent_dir/test.wav"
        exit 1
    fi
}

collect_frames() {
    shopt -s nullglob
    local files
    files=("$frames_dir"/${frame_prefix}*[0-9]*."$frame_ext")
    if [ ${#files[@]} -eq 0 ]; then
        echo "[ERROR] No frames found in $frames_dir with prefix '$frame_prefix' and extension '$frame_ext'"
        exit 1
    fi

    local numbers=()
    width=0
    local f b num
    for f in "${files[@]}"; do
        b=$(basename "$f")
        if [[ "$b" =~ ^${frame_prefix}([0-9]+)\.${frame_ext}$ ]]; then
            num="${BASH_REMATCH[1]}"
            numbers+=("$num")
            if [ ${#num} -gt $width ]; then
                width=${#num}
            fi
        fi
    done

    if [ ${#numbers[@]} -eq 0 ]; then
        echo "[ERROR] Could not parse numbered frame names in $frames_dir"
        exit 1
    fi

    IFS=$'\n' sorted=($(printf '%s\n' "${numbers[@]}" | sort -n))
    unset IFS

    if [ -z "$start_frame" ]; then
        start_frame="${sorted[0]}"
    fi
    if [ -z "$end_frame" ]; then
        end_frame="${sorted[-1]}"
    fi

    if ((10#$start_frame > 10#$end_frame)); then
        echo "[ERROR] --start must be <= --end"
        exit 1
    fi

    if [ "$width" -eq 0 ]; then
        echo "[ERROR] Unable to determine frame number width"
        exit 1
    fi
}

fill_frames() {
    frame_pattern="%0${width}d"
    tmpdir="$(mktemp -d)"

    local first_idx prev i idx src_file
    first_idx="$(printf "%0${width}d" "${sorted[0]}")"
    prev="$frames_dir/${frame_prefix}${first_idx}.${frame_ext}"

    for ((i=10#$start_frame; i<=10#$end_frame; i++)); do
        idx="$(printf "%0${width}d" "$i")"
        src_file="$frames_dir/${frame_prefix}${idx}.${frame_ext}"
        if [ -f "$src_file" ]; then
            prev="$src_file"
        fi
        ln -s "$prev" "$tmpdir/frame_${idx}.${frame_ext}"
    done

    total_frames=$((10#$end_frame - 10#$start_frame + 1))
}

cleanup() {
    if [[ -n "${tmpdir:-}" && -d "$tmpdir" ]]; then
        rm -rf "$tmpdir"
    fi
}

compute_fps() {
    audio_duration=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$audio_file")
    if [ -z "$audio_duration" ]; then
        echo "[ERROR] Could not read audio duration: $audio_file"
        exit 1
    fi

    fps=$(awk -v f="$total_frames" -v d="$audio_duration" 'BEGIN { printf "%.12f", f / d }')
    if ! [[ "$fps" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        echo "[ERROR] Invalid computed framerate: $fps"
        exit 1
    fi
}

encode_video() {
    echo "[INFO] Frames: $total_frames"
    echo "[INFO] Audio duration: $audio_duration s"
    echo "[INFO] Frame rate: $fps"
    echo "[INFO] Output: $output_file"

    ffmpeg -y \
        -start_number "$start_frame" \
        -r "$fps" -i "$tmpdir/frame_${frame_pattern}.${frame_ext}" \
        -i "$audio_file" \
        -c:v libx264 -pix_fmt yuv420p -crf "$crf" -preset medium \
        -c:a aac -b:a "$audio_bitrate" \
        -movflags +faststart \
        "$output_file"
}

check_binaries() {
    command -v ffmpeg >/dev/null || { echo "[ERROR] ffmpeg is required"; exit 1; }
    command -v ffprobe >/dev/null || { echo "[ERROR] ffprobe is required"; exit 1; }
}

main "$@"
