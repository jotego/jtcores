#!/bin/bash

REGRESSION_FILE="reg.yaml"
# change default frames in $JTFRAME/bin/reg.yaml

main() {
    if [[ -z $JTROOT ]]; then
        echo "[ERROR] JTROOT environment variable not defined."
        echo "Execute 'source setprj.sh' first"
        exit 12
    fi

    shopt -s nullglob

    parse_args "$@"

    print_title "Launching regression for $setname"

    local ec=0

    if ! cd_ver_folder; then exit 2; fi

    exec 3> $setname-sim.log

    print_step "Simulating $setname"
    local simulate_ec=0
    simulate
    simulate_ec=$?
    case $simulate_ec in
        0) echo "[INFO] Simulation succeed" ;;
        1)
            echo "[ERROR] Cannot get required zips"
            ec=11
        ;;
        2)
            echo "[ERROR] Simulation failed"
            ec=1
        ;;
    esac

    local check_video_ec=0
    local check_audio_ec=0

    if ( $check || $local_check ) && [[ $simulate_ec == 0 ]]; then
        check_video
        check_video_ec=$?

        check_audio
        check_audio_ec=$?
        if [[ $? > check_result ]]; then check_result=$?; fi

        case $check_video_ec in
            0)
                echo "[INFO] Frames validation succeed"
                case $check_audio_ec in
                    0)
                        echo "[INFO] Audio validation succeed"
                        ec=0
                    ;;
                    1)
                        echo "[WARNING] Cannot perform audio validation"
                        ec=3
                    ;;
                    2)
                        echo "[ERROR] Audio validation failed"
                        ec=4
                    ;;
                esac
            ;;
            1)
                echo "[WARNING] Not enough frames to perform validation"
                case $check_audio_ec in
                    0)
                        echo "[INFO] Audio validation succeed"
                        ec=5
                    ;;
                    1)
                        echo "[WARNING] Cannot perform audio validation"
                        ec=6
                    ;;
                    2)
                        echo "[ERROR] Audio validation failed"
                        ec=7
                    ;;
                esac
            ;;
            2)
                echo "[ERROR] Frames validation failed"
                case $check_audio_ec in
                    0)
                        echo "[INFO] Audio validation succeed"
                        ec=8
                    ;;
                    1)
                        echo "[WARNING] Cannot perform audio validation"
                        ec=9
                    ;;
                    2)
                        echo "[ERROR] Audio validation failed"
                        ec=10
                    ;;
                esac
            ;;
        esac
    fi

    if $push; then
        if [[ $ec == 0 ]]; then
            echo "[INFO] Regression succeed! Skiping upload"
        else
            print_step "Uploading simulation results for $setname"
            upload_results $ec
        fi
    fi

    return $ec
}

parse_args() {
    REMOTE_DIR=domains/jotego.es
    LOCAL_DIR=""
    check=false
    local_check=false
    local_rom=false
    push=false

    if [[ $1 == --help || $1 == -h ]]; then
        print_help
        exit 0
    fi
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 <core> <setname> [other args]"
        exit 1
    fi
    core=$1; shift
    setname=$1; shift

    while [[ $# -gt 0 ]]; do case $1 in
        --path) shift; REMOTE_DIR="$1" ;;
        --check) check=true ;;
        --local-check) shift; local_check=true; LOCAL_DIR="$1" ;;
        --local-rom) local_rom=true ;;
        --push) push=true ;;
        -h|--help)
            print_help
            exit 0
            ;;
        --port)
            shift
            if [[ "$1" =~ ^[0-9]+$ ]]; then
                SSH_PORT="$1"
            else
                echo "[ERROR] --port requires a numeric argument"
                exit 1
            fi
            ;;
        --host) shift; SFTP_HOST=$1 ;;
        --user) shift; SFTP_USER=$1 ;;
        *)
            echo "[ERROR] Unknown option: $1"
            exit 1
            ;;
    esac; shift; done
    if [[ "$1" == '--' ]]; then shift; fi

    if $check || $push || ! $local_rom; then
        if [[ -z $SFTP_HOST || -z $SFTP_USER || -z $SSH_PORT ]]; then
            echo "[ERROR] If you are going to use SFTP server, you need to specify --port, --host and --user flags"
            exit 1
        fi
    fi
}

print_help() {
    cat << EOF
Run a simulation for the specified setname.
If the corresponding folder doesn't exist it will be created.

Usage: run_regression.sh <core> <setname> [--port <ssh_port>] [--user <sftp_user>] [--host <server_ip>] [--path REMOTE_DIR] [--check] [--local-check LOCAL_DIR] [--local-rom] [--push] [-h|--help]

Options:
  --path REMOTE_DIR         Specify the REMOTE_DIR path (default: domains/jotego.es).
                            Be sure to have the right permissions on the directory you specify.
  --check                   Validate extracted simulation against reference results stored
                            in REMOTE_DIR on the remote server. Can be used with --local-check.
  --local-check LOCAL_DIR   Validate extracted simulation against reference results
                            stored in LOCAL_DIR in your machine. Can be used with --check.
  --local-rom               Will use your ROM files stored on ~/.mame/roms, Instead of
                            downloading them from the remote server.
  --push                    Upload extracted simulation to the remote server.
                            If it is not used with --check or --local-check, only uploads
                            simulations to the folder NOT CHECKED. WARNING. Otherwise, it will
                            upload to the folders VALID (if check was successfull), FAIL (if
                            check was failed) or NOT CHECKED (if there weren't enough references
                            to check)
  --port                    Specify the SSH port to connect to the SFTP server. Mandatory if you
                            are going to use the remote server.
  --host                    Specify the IP/hostname of the SFTP server. Mandatory if you are
                            going to use the remote server.
  --user                    Specify the user to connect to the SFTP server. Mandatory if you are
                            going to use the remote server.

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

cd_ver_folder() {
    if [[ ! -d "$JTROOT/cores/$core" ]]; then
        echo "[ERROR] Folder for core $core doesn't exist"
        return 1
    fi

    local ver_folder="$JTROOT/cores/$core/ver/$setname"
    mkdir --parents $ver_folder
    cd $ver_folder
}

simulate() {
    if ! $local_rom; then
        local roms_dir
        if ! get_zips roms_dir; then return 1; fi
        jtframe mra --path $roms_dir --setname $setname
        rm -rf $roms_dir
    else
        jtframe mra --setname $setname
    fi

    declare -a sim_opts
    get_opts sim_opts

    jtsim -batch -load -skipROM -setname $setname "${sim_opts[@]}" >&3 2>&3
    if [[ $? != 0 ]]; then return 2; fi

    if [[ ! -f "test.mp4" ]]; then
        echo "[WARNING] Generated video not found"
    else
        mv "test.mp4" "$setname.mp4"
    fi
}

get_zips() {
    declare -n roms_dir_ref=$1

    declare -a zip_names
    if ! get_zip_names zip_names; then return 1; fi
    
    roms_dir_ref=$(mktemp -d)
    trap "rm -rf $roms_dir_ref" EXIT

    for zip in "${zip_names[@]}"; do
        sftp -P $SSH_PORT $SFTP_USER@$SFTP_HOST:$REMOTE_DIR >/dev/null 2>&1 <<EOF
get mame/$zip $roms_dir_ref
bye
EOF
    done
}

get_zip_names() {
    declare -n zip_names_ref=$1

    jtframe mra --skipROM

    zip_names_ref=$(
        JTBIN="$JTROOT/release" jtutil mra -c -z |
        awk -F'|' -v setname="$setname" '
            {
                name = $4; zips = $5
                gsub(/^[ \t]+|[ \t]+$/, "", name)
                gsub(/^[ \t]+|[ \t]+$/, "", zips)
            }
            name == setname {
                split(zips, a, /[ \t]+/)
                for (i in a) print a[i]
            }
        '
    )
    readarray -t zip_names_ref <<< "$zip_names_ref"

    if [[ "${#zip_names_ref[@]}" == 0 ]]; then return 1; fi
}

get_opts() {
    declare -n opts_ref=$1

    local global_cfg_file="$JTROOT/modules/jtframe/bin/$REGRESSION_FILE"
    local local_cfg_file="$JTROOT/cores/$core/cfg/$REGRESSION_FILE"

    local frames_found=false

    # --- Parse global config ---
    if [[ ! -f $global_cfg_file ]]; then
        echo "[WARNING] Cannot find global configuration file for regressions. Searched in $global_cfg_file"
    else
        readarray raw_opts < <(yq -o=j -I=0 "to_entries[]" $global_cfg_file)
        for item in "${raw_opts[@]}"; do
            key=$(echo $item | yq '.key' -)
            value=$(echo $item | yq '.value' -)
            if [[ $key == "video" ]]; then
                frames_found=true
            fi
            opts_ref+=(-$key $value)
        done
    fi

    # --- Parse core config ---
    if [[ ! -f $local_cfg_file ]]; then
        echo "[WARNING] Cannot find local configuration file for $core regressions. Searched in $local_cfg_file"
    elif [[ $(yq ".$setname" $local_cfg_file) == "null" ]]; then
        echo "[WARNING] $setname is not meant to execute a regression. You shouldn't be requesting it"
    else
        readarray raw_opts < <(yq -o=j -I=0 ".$setname | to_entries[]" $local_cfg_file)
        for item in "${raw_opts[@]}"; do
            key=$(echo $item | yq '.key' -)
            value=$(echo $item | yq '.value' -)
            if [[ $key == "video" ]]; then
                frames_found=true
            fi
            opts_ref+=(-$key $value)
        done
    fi

    if ! $frames_found; then
        echo "[ERROR] frames not defined neither in global config or core config."
        exit 1
    fi

    echo "[INFO] Simulation options are ${opts_ref[@]}"
}

check_video() {
    print_step "Checking frames"

    if $check; then
        local frames_dir
        if ! get_remote_frames frames_dir; then return 1; fi
        check_frames $frames_dir/frames
        return $?
    fi

    if $local_check; then
        check_frames $LOCAL_DIR/$core/$setname/frames
        return $?
    fi
}

get_remote_frames() {
    declare -n dir=$1
    dir=$(mktemp -d)
    trap "rm -rf $dir" EXIT

    echo "[INFO] Downloading remote frames for $setname"
    sftp -P $SSH_PORT $SFTP_USER@$SFTP_HOST:$REMOTE_DIR >/dev/null 2>&1 <<EOF
get regression/$core/$setname/valid/frames.zip $dir
bye
EOF
    if [[ ! -f "$dir/frames.zip" ]]; then
        echo "[WARNING] There are no valid frames yet"
        return 1
    fi
    unzip -q -d $dir $dir/frames.zip
}

check_frames() {
    local ref_dir=$1

    local frames=(frames/*.jpg)
    local n_frames="${#frames[@]}"
    local ref_frames=($ref_dir/*.jpg)
    local n_ref_frames="${#ref_frames[@]}"

    if [[ $n_frames -gt $n_ref_frames ]]; then
        echo " [WARNING] There are $n_ref_frames frames available for comparison, when it is needed a minimum of $n_frames"
        return 1
    fi

    for ((i = 0 ; i < n_frames ; i++)); do
        local frame="${frames[$i]}"
        local ref_frame="${ref_frames[$i]}"

        local failed=false
        if perceptualdiff "$ref_frame" "$frame"; then
            echo "[INFO] $(basename $frame): match"
        else
            echo "[WARNING] $(basename $frame): difference detected"
            local failed=true
        fi
    done

    if $failed; then return 2; fi
}

check_audio() {
    local ref_audio="audio.wav"
    local ref_spectro="audio.png"
    local test_audio="test.wav"
    local test_spectro="test.png"

    print_step "Checking audio"

    if [[ ! -f "$test_audio" ]]; then
        echo "[ERROR] Missing audio file for $core"
        return 2
    fi

    if $check; then
        if ! get_remote_audio; then
            echo "[WARNING] Cannot get remote audio"
            return 1;
        fi
    elif $local_check; then
        if [[ ! -f $LOCAL_DIR/$core/$setname/audio.wav ]]; then
            echo "[ERROR] Local audio doesn't exist"
            return 2
        fi
        mv $LOCAL_DIR/$core/$setname/audio.wav .
    fi

    len_ref=$(soxi -D $ref_audio)
    len_test=$(soxi -D $test_audio)

    if (( $(echo "$len_ref < $len_test" | bc -l) )); then
        echo "[WARNING] The reference audio is not long enough to validate"
        exit 1
    fi

    sox $ref_audio -n trim 0 $len_test spectrogram -r -o $ref_spectro
    sox $test_audio -n spectrogram -r -o $test_spectro

    if perceptualdiff "$ref_spectro" "$test_spectro"; then
        echo "[INFO] Audio match"
        return 0
    else
        echo "[ERROR] Audio doesn't match"
        sox $ref_audio -n trim 0 $len_test spectrogram -o reference-spectro.png
        sox $test_audio -n spectrogram -o test-spectro.png
        return 2
    fi
}

get_remote_audio() {
    echo "[INFO] Downloading remote audio for $setname"
    sftp -P $SSH_PORT $SFTP_USER@$SFTP_HOST:$REMOTE_DIR >/dev/null 2>&1 <<EOF
get regression/$core/$setname/valid/audio.zip
bye
EOF
    if [[ ! -f "audio.zip" ]]; then return 1; fi

    unzip audio.zip
    rm -f audio.zip
    trap "rm -f audio.wav" EXIT
}

upload_results() {
    local ec=$1
    local folder=""
    declare -a files
    files=(frames.zip audio.zip $setname.mp4)

    case $ec in
        1)
            folder="fail"
            files=("$setname-sim.log")
        ;;
        3|5|6) folder="not_checked" ;;
        4|7|10)
            folder="fail"
            files+=(test-spectro.png reference-spectro.png)
        ;;
        8|9) folder="fail" ;;
        *) return ;;
    esac

    zip -q frames.zip frames/*
    mv --force --no-copy test.wav audio.wav
    zip -q audio.zip audio.wav

    echo "[INFO] Starting upload"
    sftp -P $SSH_PORT $SFTP_USER@$SFTP_HOST:$REMOTE_DIR >/dev/null 2>&1 <<EOF
mkdir regression
mkdir regression/$core
mkdir regression/$core/$setname
mkdir regression/$core/$setname/$folder
cd regression/$core/$setname/$folder
$(for f in "${files[@]}"; do echo "put $f"; done)
bye
EOF
    echo "[INFO] Upload finished"
}

main "$@"
