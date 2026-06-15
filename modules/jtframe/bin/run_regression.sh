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
            echo "[ERROR] Cannot prepare ROM data"
            ec=11
        ;;
        2)
            echo "[ERROR] Simulation failed"
            ec=1
        ;;
    esac

    local check_video_ec=0
    local check_audio_ec=0

    if $check && [[ $simulate_ec == 0 ]]; then
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
            if ! upload_results $ec; then
                echo "[ERROR] Upload failed"
                ec=13
            fi
        fi
    fi

    return $ec
}

clean_up() {
    rm -rf "${TODELETE[@]}"
}

parse_args() {
    check=false
    local_rom=false
    push=false
    MAME=${MAME:-}
    REGRUNS=${REGRUNS:-}

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
        --check)
            check=true
            shift
            ;;
        --local-check)
            if [[ $# -lt 2 ]]; then
                echo "[ERROR] --local-check requires an argument"
                exit 1
            fi
            check=true
            REGRUNS="$2"
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
        *)
            echo "[ERROR] Unknown option: $1"
            exit 1
            ;;
    esac; done

    if ! $local_rom; then
        if [[ -z $MAME ]]; then
            echo "[ERROR] MAME must point to the folder containing MAME zip files"
            exit 1
        fi
        if [[ ! -d $MAME ]]; then
            echo "[ERROR] MAME folder does not exist: $MAME"
            exit 1
        fi
    fi

    if $check || $push; then
        if [[ -z $REGRUNS ]]; then
            echo "[ERROR] REGRUNS must point to the regression reference/results folder"
            exit 1
        fi
        if [[ ! -d $REGRUNS ]]; then
            echo "[ERROR] REGRUNS folder does not exist: $REGRUNS"
            exit 1
        fi
    fi
}

print_help() {
    cat << EOF
Run a simulation for the specified setname.
If the corresponding folder doesn't exist it will be created.

Usage: run_regression.sh <core> <setname> [--check] [--local-check LOCAL_DIR] [--local-rom] [--push] [-h|--help]

Options:
  --check                   Validate extracted simulation against reference results
                            stored under REGRUNS.
  --local-check LOCAL_DIR   Validate extracted simulation against reference results
                            stored in LOCAL_DIR. This is an alias for REGRUNS=LOCAL_DIR --check.
  --local-rom               Use jtframe's default local ROM lookup instead of MAME.
  --push                    Store failed or incomplete simulation results under REGRUNS.

Environment:
  MAME                      Folder containing MAME zip files. Required unless --local-rom is used.
  REGRUNS                   Regression reference/results folder. Required with --check or --push.

Reference files are read from REGRUNS/<core>/<setname>/valid. Results are written
to REGRUNS/<core>/<setname-or-variant>/{fail,not_checked}.

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
        jtframe mra --path "$MAME" --setname "$setname"
    else
        jtframe mra --setname "$setname"
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
        if ! get_reference_frames frames_dir; then return 1; fi
        check_frames "$frames_dir/frames"
        return $?
    fi
}

regression_root() {
    printf '%s' "${REGRUNS%/}"
}

reference_dir() {
    printf '%s/%s/%s/valid' "$(regression_root)" "$core" "$setname"
}

result_dir() {
    local folder="$1"
    printf '%s/%s/%s/%s' "$(regression_root)" "$core" "$fullname" "$folder"
}

get_reference_frames() {
    declare -n dir="$1"
    local ref_dir
    ref_dir="$(reference_dir)"

    if [[ -d "$ref_dir/frames" ]]; then
        dir="$ref_dir"
        return 0
    fi

    if [[ ! -f "$ref_dir/frames.zip" ]]; then
        echo "[WARNING] Reference frames not found in $ref_dir"
        return 1
    fi

    dir=$(mktemp -d)
    TODELETE+=("$dir")

    if ! unzip -q -d "$dir" "$ref_dir/frames.zip"; then
        echo "[WARNING] Cannot unpack $ref_dir/frames.zip"
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
        if ! get_reference_audio; then
            echo "[WARNING] Cannot get reference audio"
            return 1;
        fi
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

get_reference_audio() {
    local ref_dir
    ref_dir="$(reference_dir)"

    if [[ -f "$ref_dir/audio.wav" ]]; then
        cp "$ref_dir/audio.wav" .
        TODELETE+=("$(realpath audio.wav)")
        return 0
    fi

    if [[ ! -f "$ref_dir/audio.zip" ]]; then
        echo "[WARNING] Reference audio not found in $ref_dir"
        return 1
    fi

    if ! unzip -q -o -d . "$ref_dir/audio.zip"; then
        echo "[WARNING] Cannot unpack $ref_dir/audio.zip"
        rm -f audio.wav
        return 1
    fi
    TODELETE+=("$(realpath audio.wav)")
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

    local target_dir
    target_dir="$(result_dir "$folder")"
    mkdir -p "$target_dir"

    echo "[INFO] Storing regression results in $target_dir"
    local f
    for f in "${files[@]}"; do
        [[ -n "$f" ]] || continue
        if [[ ! -f "$f" ]]; then
            echo "[WARNING] Skipping missing result file $f"
            continue
        fi
        cp -f "$f" "$target_dir/"
    done
    echo "[INFO] Result storage finished"
}

prepare_zip_files() {
    if compgen -G "frames/*" >/dev/null; then
        zip -q -r frames.zip frames
    fi
    if [[ -f test.wav ]]; then
        cp --force test.wav audio.wav
        zip -q audio.zip audio.wav
    fi
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
