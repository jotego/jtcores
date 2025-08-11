#!/bin/bash -e

REGRESSION_FILE=.regression
SFTP_HOST=109.106.246.118
SFTP_PORT=65002
SFTP_USER=u693100196

main() {
    parse_args "$@"
    shopt -s nullglob

    print_title "Simulation for core $core"

    if ! get_regression_folders; then
        exit 1
    fi

    declare -A pids
    for folder in "${regression_folders[@]}"; do
        print_step "Launching regression for $(basename $folder)"
        run_regression $folder &
        pids[$!]="$folder"
    done

    n_fail=0
    for pid in "${!pids[@]}"; do
        local folder="${pids[$pid]}"
        local setname=$(basename $folder)
        if wait "$pid"; then
            echo "OK: $setname"
        else
            echo "FAILED: $setname"
            ((n_fail++))
        fi
    done

    if (( n_fail > 0 )); then exit 1; fi
}

run_regression() {
    local regression_folder=$1
    local setname=$(basename $regression_folder)

    print_step "Simulating $setname"
    if ! simulate $regression_folder; then 
        echo -e "\nERROR: Couldn't simulate\n"
        return 1
    fi
    if $check || $local_check; then
        print_step "Checking simulation for $setname"
        if check_video $regression_folder; then
            echo -e "\nValidation succeed\n"
        else
            echo -e "\nValidation failed\n"
            return 1
        fi
    fi

    if $push; then
        print_step "Uploading simulation results $setname"
        upload_results $regression_folder
    fi
}

parse_args() {
    FRAMES=100
    REMOTE_DIR=regression # Relative to ~/domains/jotego.es
    LOCAL_DIR=""
    check=false
    local_check=false
    local_rom=false
    push=false

    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <core> [--frames <number_of_frames>] [--path REMOTE_DIR] [--check] [--local-check LOCAL_DIR] [--local-rom] [--push] [-h|--help]"
        exit 1
    fi
    if [[ $1 == --help ]]; then
        echo "Usage: $0 <core> [--frames <number_of_frames>] [--path REMOTE_DIR] [--check] [--local-check LOCAL_DIR] [--local-rom] [--push] [-h|--help]"
        echo ""
        print_help
        exit 0
    fi
    core=$1; shift

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --frames)
                shift
                if [[ "$1" =~ ^[0-9]+$ ]]; then
                    FRAMES="$1"
                else
                    echo "[ERROR] --frames requires a numeric argument"
                    exit 1
                fi
                ;;
            --path) shift; REMOTE_DIR="$1" ;;
            --check) check=true ;;
            --local-check) shift; local_check=true; LOCAL_DIR="$1" ;;
            --local-rom) local_rom=true ;;
            --push) push=true ;;
            -h|--help)
                echo "Usage: $0 <core> [--frames <number_of_frames>] [--path REMOTE_DIR] [--check] [--local-check LOCAL_DIR] [--local-rom] [--push] [-h|--help]"
                echo ""
                print_help
                exit 0
                ;;
            *)
                echo "[ERROR] Unknown option: $1"
                echo "Usage: $0 <core> [--frames <number_of_frames>] [--path REMOTE_DIR] [--check] [--local-check LOCAL_DIR] [--local-rom] [--push] [-h|--help]"
                exit 1
                ;;
        esac
        shift
    done
}

print_help() {
    cat <<'EOF'
Run all simulations for the specified core found in the `ver` directory.
Only subdirectories containing a `.regression` file will be processed.

Options:
  --frames N                Run simulations with N frames (default: 100).
  --path REMOTE_DIR         Specify the REMOTE_DIR path (default: ./regression).
                            Be sure to have the right permissions on the directory you specify.
  --check                   Validate extracted simulations against reference results stored
                            in REMOTE_DIR on the remote server. Can be used with --local-check.
  --local-check LOCAL_DIR   Validate extracted simulations against reference results
                            stored in LOCAL_DIR in your machine. Can be used with --check.
  --local-rom               Will use your ROM files stored on ~/.mame/roms, Instead of
                            downloading them from the remote server.
  --push                    Upload extracted simulations to the remote server.
                            If used with --check or --local-check, only uploads simulations
                            that pass validation. WARNING. If you don't use --check,
                            you may upload wrong simulations.

By default, simulations are extracted without validation or upload.
EOF
}

print_title() {
    local title="$1"
    local border_char="*"
    local padding=4
    local total_width=$(( ${#title} + padding * 2 + 2))

    local border_line
    border_line=$(printf "%${total_width}s" | tr ' ' "$border_char")

    echo ""
    echo "$border_line"
    printf "%s%*s%s%*s%s\n" "$border_char" $padding "" "$title" $padding "" "$border_char"
    echo "$border_line"
    echo ""
}

print_step() {
    echo ""
    echo "------------ $1 ------------"
    echo ""
}

simulate() {
    local folder=$1
    local setname=$(basename $folder)

    cd $folder
    if ! $local_rom; then
        local zipfile
        if ! get_zipfile zipfile $setname; then
            echo "[ERROR] Unable to find zip for $setname"
            return 1
        fi

        local roms_dir=$(mktemp -d)
        trap "rm -rf $roms_dir" EXIT
        cd $roms_dir
        sftp -P $SFTP_PORT $SFTP_USER@$SFTP_HOST:domains/jotego.es <<EOF
get mame/$zipfile
bye
EOF
        if [[ ! -f "$zipfile" ]]; then
            echo "[ERROR] Cannot download ROM for $setname"
            return 1
        fi

        cd $folder
        jtframe mra --path $roms_dir
    fi

    jtsim -batch -load -video $FRAMES -setname $setname
}

get_zipfile() {
    declare -n zipfile_ref=$1
    local setname=$2

    jtframe mra --skipROM
    zipfile_ref=$(
        JTBIN="$JTROOT/release" jtutil mra -c -z |
        awk -F'|' -v setname="$setname" '
            # Erase whitespaces
            {
            name = $4; zips = $5
            gsub(/^[ \t]+|[ \t]+$/, "", name)
            gsub(/^[ \t]+|[ \t]+$/, "", zips)
            }

            # Match setname and get zip
            name == setname {
            n = split(zips, a, /[ \t]+/)
            last = a[n]
            }

            END {
            if (last != "") print last;
            else exit 1
            }
        '
    )
    
    if [[ -z $zipfile_ref ]]; then return 1; fi
}

get_regression_folders() {
    local ver_folder="$JTROOT/cores/$core/ver"

    regression_folders=()

    for dir in $ver_folder/*/; do
        if [[ -f "$dir/$REGRESSION_FILE" ]]; then
            regression_folders+=$dir            
        fi
    done

    if [[ "${#regression_folders[@]}" == 0 ]]; then
        echo " [ERROR] Cannot find regression folders for core $core"
        return 1
    fi
}

check_video() {
    local folder=$1
    local setname=$(basename $folder)
    local failed=false

    if $check; then
        local frames_dir
        get_remote_frames $setname frames_dir
        if ! check_frames $folder/frames $frames_dir $setname; then local failed=true; fi
    fi

    if $local_check; then
        if ! check_frames $folder/frames $LOCAL_DIR/$core/$setname/frames $$etname; then local failed=true; fi
    fi

    if $failed; then return 1; fi
}

get_remote_frames() {
    local setname=$1
    declare -n dir=$2
    dir=$(mktemp -d)
    trap "rm -rf $dir" EXIT

    echo "Downloading remote frames for setname $setname"
    cd $dir
    sftp -P $SFTP_PORT $SFTP_USER@$SFTP_HOST:domains/jotego.es <<EOF
get regression/$core/$setname/frames/*
bye
EOF
}

check_frames() {
    local local_dir=$1
    local ref_dir=$2

    local frames=($local_dir/*.jpg)
    local n_frames="${#frames[@]}"
    local ref_frames=($ref_dir/*.jpg)
    local n_ref_frames="${#ref_frames[@]}"

    if [[ $n_frames -gt $n_ref_frames ]]; then
        echo " [ERROR] There are $n_ref_frames frames available for comparison, when it is needed a minium of $n_frames"
        return 1
    fi

    for ((i = 0 ; i < n_frames ; i++)); do
        local frame="${frames[$i]}"
        local ref_frame="${ref_frames[$i]}"

        echo "Comparing $(basename $frame)..."
        local failed=false
        if perceptualdiff "$ref_frame" "$frame"; then
            echo "$(basename $frame): match"
        else
            echo "$(basename $frame): difference detected"
            local failed=true
        fi
    done

    if $failed; then return 1; fi
}

# check_audio() {
#     local core=$1
#     local ref_audio="$REFERENCE_DIR/$core/test.wav"
#     local test_audio="test.wav"
#     local diff_audio="__diff_audio.wav"

#     print_step "Checking audio"

#     if [[ ! -f "$ref_audio" || ! -f "$test_audio" ]]; then
#         echo "Missing audio file for $core"
#         return 1
#     fi

#     sox -m -v 1 "$ref_audio" -v -1 "$test_audio" "$diff_audio" silence 1 0.1 0.1%

#     local rms=$(sox "$diff_audio" -n stat 2>&1 | tee /dev/stderr | awk '/RMS.*amplitude/ { print $3 }')
    
#     rm -f "$diff_audio"

#     local threshold=0.001

#     if (( $(echo "$rms < $threshold" | bc -l) )); then
#         echo "Audio for $core matches (RMS = $rms)"
#         return 0
#     else
#         echo "Audio for $core differs (RMS = $rms)"
#         return 1
#     fi
# }

upload_results() {
    local folder=$1
    local setname=$(basename $folder)

    sftp -P $SFTP_PORT $SFTP_USER@$SFTP_HOST:domains/jotego.es <<EOF
mkdir regression
mkdir regression/$core
mkdir regression/$core/$setname
rm regression/$core/$setname/frames/*
mkdir regression/$core/$setname/frames
cd regression/$core/$setname/frames
put $folder/frames/*
bye
EOF
}

main "$@"
