#!/bin/bash

# change default frames in $JTFRAME/bin/reg.yaml
TODELETE=()

main() {
    if [[ -z $JTROOT ]]; then
        echo "[ERROR] JTROOT environment variable not defined."
        echo "Execute 'source setprj.sh' first"
        exit 12
    fi

    shopt -s nullglob
    trap clean_up INT EXIT

    parse_args "$@"

    print_title "Launching regression for $setname"

    local ec=0

    if ! cd_ver_folder; then exit 2; fi

    exec 3> $fullname-sim.log

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

clean_up() {
    rm -rf "${TODELETE[@]}"
}

parse_args() {
    REMOTE_DIR=domains/jotego.es
    LOCAL_DIR=""
    check=false
    local_check=false
    local_rom=false
    push=false
    SFTP_CONNECT_TIMEOUT=${SFTP_CONNECT_TIMEOUT:-120}

    if [[ $1 == --help || $1 == -h ]]; then
        print_help
        exit 0
    fi
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 <core> <setname> [other args]"
        exit 1
    fi
    core=$1; shift
    parse_setname $1; shift

    while [[ $# -gt 0 ]]; do case $1 in
        --path)
            if [[ $# -lt 2 ]]; then
                echo "[ERROR] --path requires an argument"
                exit 1
            fi
            REMOTE_DIR="$2"
            shift 2
            ;;
        --check)
            check=true
            shift
            ;;
        --local-check)
            if [[ $# -lt 2 ]]; then
                echo "[ERROR] --local-check requires an argument"
                exit 1
            fi
            local_check=true
            LOCAL_DIR="$2"
            shift 2
            ;;
        --local-rom)
            local_rom=true
            shift
            ;;
        --push)
            push=true
            shift
            ;;
        -h|--help)
            print_help
            exit 0
            ;;
        --port)
            if [[ $# -lt 2 || ! "$2" =~ ^[0-9]+$ ]]; then
                echo "[ERROR] --port requires a numeric argument"
                exit 1
            fi
            SSH_PORT="$2"
            shift 2
            ;;
        --host)
            if [[ $# -lt 2 ]]; then
                echo "[ERROR] --host requires an argument"
                exit 1
            fi
            SFTP_HOST="$2"
            shift 2
            ;;
        --user)
            if [[ $# -lt 2 ]]; then
                echo "[ERROR] --user requires an argument"
                exit 1
            fi
            SFTP_USER="$2"
            shift 2
            ;;
        *)
            echo "[ERROR] Unknown option: $1"
            exit 1
            ;;
    esac; done

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

parse_setname() {
    fullname="$1"
    local rest
    IFS="-" read setname rest <<< "$fullname"
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

    local ver_folder="$JTROOT/cores/$core/ver/$fullname"
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

    create_nvram_files
    jtsim -batch -load -skipROM -setname $setname "${sim_opts[@]}" >&3 2>&3
    if [[ $? != 0 ]]; then
        if $local_rom; then
            cat $fullname-sim.log
        fi
        return 2;
    fi

    if [[ ! -f "test.mp4" ]]; then
        echo "[WARNING] Generated video not found"
    else
        mv "test.mp4" "$setname.mp4"
    fi
}

create_nvram_files() {
    jtutil sdram $setname
}

get_zips() {
    local target_name="$1"
    local -n roms_dir_ref="$target_name"

    declare -a zip_names
    declare -a missing_zips
    if ! get_zip_names zip_names; then return 1; fi
    
    roms_dir_ref=$(mktemp -d)
    TODELETE+=("$roms_dir_ref")

    local sftp_log
    sftp_log=$(mktemp)
    TODELETE+=("$sftp_log")

    get_many_via_ftp "$roms_dir_ref" "$sftp_log" "${zip_names[@]}" || true
    collect_missing_zips missing_zips "$roms_dir_ref" "${zip_names[@]}"

    if [[ "${#missing_zips[@]}" -gt 0 ]]; then
        get_with_retry missing_zips "$roms_dir_ref" "$sftp_log"
        collect_missing_zips missing_zips "$roms_dir_ref" "${zip_names[@]}"
    fi

    if [[ "${#missing_zips[@]}" -gt 0 ]]; then
        echo "[WARNING] Missing zip files after SFTP retries: ${missing_zips[*]}" >&2
        echo "[WARNING] SFTP log follows:" >&2
        cat "$sftp_log" >&2
    fi

    if [[ "${#missing_zips[@]}" == "${#zip_names[@]}" ]]; then
        return 1
    fi
}

get_zip_names() {
    local target_name="$1"
    local -n zip_names_ref="$target_name"
    local zip_names_raw
    local -a sanitized_zips
    local zip

    jtframe mra --skipROM

    zip_names_raw=$(
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
    readarray -t zip_names_ref <<< "$zip_names_raw"

    sanitized_zips=()
    for zip in "${zip_names_ref[@]}"; do
        zip="${zip#${zip%%[![:space:]]*}}"
        zip="${zip%${zip##*[![:space:]]}}"
        [[ -n "$zip" ]] && sanitized_zips+=("$zip")
    done
    zip_names_ref=("${sanitized_zips[@]}")

    if [[ "${#zip_names_ref[@]}" == 0 ]]; then return 1; fi
}

collect_missing_zips() {
    local target_name="$1"
    local -n missing_zips_ref="$target_name"
    local roms_dir_ref="$2"
    shift 2

    missing_zips_ref=()
    local zip
    for zip in "$@"; do
        [[ -n "$zip" ]] || continue
        if ! zip_file_ready "$roms_dir_ref/$zip"; then
            missing_zips_ref+=("$zip")
        fi
    done
}

zip_file_ready() {
    local zip_path="$1"

    if [[ ! -s "$zip_path" ]]; then
        return 1
    fi

    if unzip -t "$zip_path" >/dev/null 2>&1; then
        return 0
    fi

    echo "[WARNING] Invalid zip file detected, removing before retry: $zip_path" >&2
    rm -f "$zip_path"
    return 1
}

get_with_retry() {
    local target_name="$1"
    local -n missing_zips_ref="$target_name"
    local roms_dir_ref="$2"
    local sftp_log="$3"
    local attempts=7

    while [[ $attempts -gt 0 && "${#missing_zips_ref[@]}" -gt 0 ]]; do
        get_many_via_ftp "$roms_dir_ref" "$sftp_log" "${missing_zips_ref[@]}" || true
        collect_missing_zips "$target_name" "$roms_dir_ref" "${missing_zips_ref[@]}"
        attempts=$((attempts-1))
        if [[ $attempts -gt 0 && "${#missing_zips_ref[@]}" -gt 0 ]]; then
            random_wait
        fi
    done

    if [[ "${#missing_zips_ref[@]}" -gt 0 ]]; then
        return 1
    fi

    return 0
}

run_sftp() {
    sftp -o ConnectTimeout="$SFTP_CONNECT_TIMEOUT" -P "$SSH_PORT" "$@" \
        "$SFTP_USER@$SFTP_HOST:$REMOTE_DIR"
}

get_many_via_ftp() {
    local roms_dir_ref="$1"
    local sftp_log="$2"
    shift 2

    {
        printf '[INFO] SFTP get: %s\n' "$*"
    } >>"$sftp_log"

    {
        printf 'lcd %s\n' "$roms_dir_ref"
        local zip
        for zip in "$@"; do
            printf -- '-get mame/%s %s\n' "$zip" "$zip"
        done
        printf 'bye\n'
    } | run_sftp -b - >>"$sftp_log" 2>&1
}

random_wait() {
    sleep $((RANDOM%30+10))
}

add_sim_option() {
    local _add_opts_name="$1"
    local _add_pos_name="$2"
    local -n _add_opts="$_add_opts_name"
    local -n _add_pos="$_add_pos_name"
    local key=$3
    local value=$4

    if [[ -n ${_add_pos[$key]+x} ]]; then
        _add_opts[${_add_pos[$key]}]=-$key
        _add_opts[$((_add_pos[$key]+1))]=$value
    else
        _add_pos[$key]=${#_add_opts[@]}
        _add_opts+=( -$key $value )
    fi
}

parse_opts() {
    local selector=$1
    local cfg_file=$2
    local _parse_opts_name="$3"
    local _parse_pos_name="$4"
    local _parse_frames_name="$5"
    local -n _parse_opts="$_parse_opts_name"
    local -n _parse_pos="$_parse_pos_name"
    local -n _parse_frames="$_parse_frames_name"

    local -a raw_opts=()
    if [[ -z $selector ]]; then
        readarray raw_opts < <(yq -o=j -I=0 "to_entries[]" "$cfg_file")
    else
        readarray raw_opts < <(yq -o=j -I=0 "$selector | to_entries[]" "$cfg_file")
    fi

    local item
    local key
    local value
    for item in "${raw_opts[@]}"; do
        key=$(echo "$item" | yq '.key' -)
        value=$(echo "$item" | yq '.value' -)
        if [[ $key == "video" ]]; then
            _parse_frames=true
        fi
        add_sim_option _parse_opts _parse_pos "$key" "$value"
    done
}

get_opts() {
    declare -n opts_ref=$1

    local global_cfg_file="$JTROOT/modules/jtframe/bin/reg.yaml"
    local local_cfg_file="$JTROOT/cores/$core/cfg/reg.yaml"

    local frames_found=false
    local -A opt_pos

    if [[ ! -f $global_cfg_file ]]; then
        echo "[WARNING] Cannot find global configuration file for regressions. Searched in $global_cfg_file"
    else
        parse_opts "" "$global_cfg_file" opts_ref opt_pos frames_found
    fi

    if [[ ! -f $local_cfg_file ]]; then
        echo "[WARNING] Cannot find local configuration file for $core regressions. Searched in $local_cfg_file"
    elif [[ $(yq ".$fullname" $local_cfg_file) == "null" ]]; then
        echo "[WARNING] $fullname is not meant to execute a regression. You shouldn't be requesting it"
    else
        parse_opts ".$fullname" "$local_cfg_file" opts_ref opt_pos frames_found
    fi

    if ! $frames_found; then
        echo "[ERROR] frames not defined neither in global config or core config."
        exit 1
    fi

    echo "[INFO] Simulation options are ${opts_ref[*]}"
}

check_video() {
    print_step "Checking frames"
    delete_duplicated_frames

    if $check; then
        local frames_dir
        if ! get_remote_frames frames_dir; then return 1; fi
        check_frames "$frames_dir/frames"
        return $?
    fi

    if $local_check; then
        check_frames $LOCAL_DIR/$core/$setname/frames
        return $?
    fi
}

get_remote_frames() {
    declare -n dir="$1"
    dir=$(mktemp -d)
    TODELETE+=("$dir")

    echo "[INFO] Downloading remote frames for $setname"
    run_sftp >/dev/null 2>&1 <<EOF
get regression/$core/$setname/valid/frames.zip $dir
bye
EOF
    if [[ ! -f "$dir/frames.zip" ]]; then
        echo "[WARNING] There are no valid frames yet"
        return 1
    fi
    if ! unzip -q -d "$dir" "$dir/frames.zip"; then
        echo "[WARNING] Cannot unpack frames.zip"
        rm -f "$dir/frames.zip"
        return 1
    fi
}

check_frames() {
    local ref_dir=$1

    local failed=false

    local frames=(frames/*.jpg)
    local n_frames="${#frames[@]}"
    local ref_frames=($ref_dir/*.jpg)
    local n_ref_frames="${#ref_frames[@]}"

    if [[ $n_frames -eq 0 ]]; then
        echo "[WARNING] No frames were produced by this simulation"
        return 1
    fi

    if [[ $n_frames -gt $n_ref_frames ]]; then
        echo "[WARNING] The valid folder contains $n_ref_frames frames but the new simulation has $n_frames"
        return 1
    fi
    if [[ $n_frames -lt $n_ref_frames ]]; then
        echo "[WARNING] The simulation has $n_frames frames but the reference has $n_ref_frames"
        return 1
    fi

    for ((i = 0 ; i < n_frames ; i++)); do
        local frame="${frames[$i]}"
        local ref_frame="${ref_frames[$i]}"

        if ! perceptualdiff "$ref_frame" "$frame"; then
            echo "[WARNING] $(basename $frame): difference detected"
            local failed=true
            break
        fi
    done

    if $failed; then
        return 2
    else
        echo "[INFO] All frames matched the reference"
    fi
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
        cp "$LOCAL_DIR/$core/$setname/audio.wav" .
        TODELETE+=("$(realpath audio.wav)")
    fi

    len_ref=$(soxi -D $ref_audio)
    len_test=$(soxi -D $test_audio)

    if (( $(echo "$len_ref < $len_test" | bc -l) )); then
        echo "[WARNING] The reference audio is not long enough to validate"
        return 1
    fi

    sox $ref_audio -n trim 0 $len_test spectrogram -r -o $ref_spectro
    sox $test_audio -n spectrogram -r -o $test_spectro

    if perceptualdiff "$ref_spectro" "$test_spectro"; then
        echo "[INFO] Audio match"
        return 0
    else
        echo "[ERROR] Audio doesn't match"
        sox $ref_audio -n trim 0 $len_test spectrogram -o reference-spectrum.png
        sox $test_audio -n spectrogram -o test-spectrum.png
        return 2
    fi
}

get_remote_audio() {
    echo "[INFO] Downloading remote audio for $setname"
    run_sftp >/dev/null 2>&1 <<EOF
get regression/$core/$setname/valid/audio.zip
bye
EOF
    if [[ ! -f "audio.zip" ]]; then return 1; fi

    if ! unzip -q -o -d . audio.zip; then
        echo "[WARNING] Cannot unpack audio.zip"
        rm -f audio.zip
        return 1
    fi
    rm -f audio.zip
    TODELETE+=(`realpath audio.wav`)
}

upload_results() {
    local ec=$1
    local folder=""
    declare -a files
    files=(frames.zip audio.zip $setname.mp4)

    case $ec in
        0) files=();;
        1|2)
            folder="fail"
            files=("$fullname-sim.log")
        ;;
        11)
            folder="fail"
            files=("$fullname-sim.log")
        ;;
        3|5|6) folder="not_checked" ;;
        4|7|10)
            folder="fail"
            files+=(test-spectrum.png reference-spectrum.png)
        ;;
        8|9) folder="fail" ;;
        *) return ;;
    esac

    if [ "$ec" != 0 ]; then prepare_zip_files; fi

    echo "[INFO] Starting upload"
    run_sftp >/dev/null 2>&1 <<EOF
mkdir regression
mkdir regression/$core
mkdir regression/$core/$fullname
mkdir regression/$core/$fullname/$folder
cd regression/$core/$fullname/$folder
rm -rf not_checked fail
$(for f in "${files[@]}"; do echo "put $f"; done)
bye
EOF
    echo "[INFO] Upload finished"
}

prepare_zip_files() {
    zip -q frames.zip frames/*
    mv --force --no-copy test.wav audio.wav
    zip -q audio.zip audio.wav
}

delete_duplicated_frames() {
    local first=true
    local last
    for i in frames/frame*jpg; do
        if $first; then
            first=false
            last=$i
            continue
        fi
        if diff -q $last $i > /dev/null; then
            rm $i
            continue
        fi
        last=$i
    done
}

main "$@"
