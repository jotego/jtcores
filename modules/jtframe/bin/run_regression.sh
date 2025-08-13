#!/bin/bash

REGRESSION_FILE=.regression
DEFAULT_FRAMES=100

main() {
    if [[ -z $JTROOT ]]; then
        echo "[ERROR] JTROOT environment variable not defined."
        echo "Execute 'source setprj.sh' first"
        exit 1
    fi

    shopt -s nullglob

    parse_args "$@"

    print_title "Launching regression for $setname"

    if ! cd_ver_folder; then exit 1; fi

    print_step "Simulating $setname"
    if ! simulate; then 
        echo -e "\n[ERROR] Couldn't simulate\n"
        return 1
    fi

    local check_result=1
    if $check || $local_check; then
        print_step "Checking simulation for $setname"
        check_video
        check_result=$?
        case $check_result in
            0) echo -e "\n[INFO] Validation succeed\n" ;;
            1) echo -e "\n[WARNING] Cannot perform validation\n" ;;
            2) echo -e "\n[ERROR] Validation failed\n" ;;
        esac
    fi

    if $push; then
        print_step "Uploading simulation results $setname"
        upload_results $check_result
    fi
}

parse_args() {
    REMOTE_DIR=regression # Relative to ~/domains/jotego.es
    LOCAL_DIR=""
    check=false
    local_check=false
    local_rom=false
    push=false

    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 <core> <setname> [--frames <number_of_frames>] [--port <ssh_port>] [--user <sftp_user>] [--host <server_ip>] [--path REMOTE_DIR] [--check] [--local-check LOCAL_DIR] [--local-rom] [--push] [-h|--help]"
        exit 1
    fi
    if [[ $1 == --help ]]; then
        echo "Usage: $0 <core> <setname> [--frames <number_of_frames>] [--port <ssh_port>] [--user <sftp_user>] [--host <server_ip>] [--path REMOTE_DIR] [--check] [--local-check LOCAL_DIR] [--local-rom] [--push] [-h|--help]"
        echo ""
        print_help
        exit 0
    fi
    core=$1; shift
    setname=$1; shift

    while [[ "$1" =~ ^- && ! "$1" == "--" ]]; do case $1 in
        --path) shift; REMOTE_DIR="$1" ;;
        --check) check=true ;;
        --local-check) shift; local_check=true; LOCAL_DIR="$1" ;;
        --local-rom) local_rom=true ;;
        --push) push=true ;;
        --help)
            echo "Usage: $0 <core> <setname> [--frames <number_of_frames>] [--port <ssh_port>] [--user <sftp_user>] [--host <server_ip>] [--path REMOTE_DIR] [--check] [--local-check LOCAL_DIR] [--local-rom] [--push] [-h|--help]"
            echo ""
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
            echo "Usage: $0 <core> <setname> [--frames <number_of_frames>] [--port <ssh_port>] [--user <sftp_user>] [--host <server_ip>] [--path REMOTE_DIR] [--check] [--local-check LOCAL_DIR] [--local-rom] [--push] [-h|--help]"
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
    cat <<'EOF'
Run a simulation for the specified setname.
If the corresponding folder doesn't exist it will be created.

Options:
  --frames N                Run simulations with N frames (default: 100).
  --path REMOTE_DIR         Specify the REMOTE_DIR path (default: ./regression).
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
    if [[ ! -d "$ver_folder" ]]; then
        echo "[WARNING] Verification folder for setname $setname doesn't exist. It will be created"
    fi

    mkdir -p $ver_folder
    cd $ver_folder
}

simulate() {
    if ! $local_rom; then
        local zipfile
        if ! get_zipfile zipfile; then
            echo "[ERROR] Unable to find zip for $setname"
            return 1
        fi

        local roms_dir=$(mktemp -d)
        trap "rm -rf $roms_dir" EXIT
        sftp -P $SSH_PORT $SFTP_USER@$SFTP_HOST:domains/jotego.es <<EOF
get mame/$zipfile $roms_dir
bye
EOF
        if [[ ! -f "$roms_dir/$zipfile" ]]; then
            echo "[ERROR] Cannot download ROM for $setname"
            return 1
        fi

        jtframe mra --path $roms_dir
    fi

    declare -a sim_opts
    get_opts sim_opts
    
    jtsim -batch -load -setname $setname "${sim_opts[@]}"
}

get_opts() {
    declare -n opts_ref=$1
    local frames
    local inputs
    local dipsw

    local cfg_file="$JTROOT/cores/$core/cfg/regression.yaml"

    frames=$(yq ".$core.$setname.frames" $cfg_file)
    inputs=$(yq ".$core.$setname.inputs" $cfg_file)
    dipsw=$(yq ".$core.$setname.dipsw" $cfg_file)

    if [[ $frames != "null" ]]; then
        opts_ref+=(-video $frames)
    else
        opts_ref+=(-video $DEFAULT_FRAMES)
    fi

    if [[ $inputs != "null" ]]; then
        opts_ref+=(-inputs $inputs)
    fi

    if [[ $dipsw != "null" ]]; then
        opts_ref+=(-dipsw $dipsw)
    fi
}

get_zipfile() {
    pwd # DEBUG
    declare -n zipfile_ref=$1
    echo "I should reach here" # DEBUG

    jtframe mra --skipROM >&1 2>&1 # DEBUG
    
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
                print last;
            }
        '
    )
    
    if [[ -z $zipfile_ref ]]; then return 1; fi
}

check_video() {
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

    echo "[INFO] Downloading remote frames for setname $setname"
    sftp -P $SSH_PORT $SFTP_USER@$SFTP_HOST:domains/jotego.es <<EOF
get regression/$core/$setname/VALID/frames.zip $dir
bye
EOF
    if [[ ! -f "$dir/frames.zip" ]]; then
        echo "[WARNING] There are no valid frames yet"
        return 1
    fi
    unzip -d $dir $dir/frames.zip
}

check_frames() {
    local ref_dir=$1

    local frames=(frames/*.jpg)
    local n_frames="${#frames[@]}"
    local ref_frames=($ref_dir/*.jpg)
    local n_ref_frames="${#ref_frames[@]}"

    if [[ $n_frames -gt $n_ref_frames ]]; then
        echo " [WARNING] There are $n_ref_frames frames available for comparison, when it is needed a minium of $n_frames"
        return 1
    fi

    for ((i = 0 ; i < n_frames ; i++)); do
        local frame="${frames[$i]}"
        local ref_frame="${ref_frames[$i]}"

        echo "Comparing $(basename $frame)..."
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
    local dest=$1
    case $dest in
        0)
            echo "[INFO] Results are valid. Skipping upload"
            return 0
        ;;
        1) local folder="NOT_CHECKED" ;;
        2) local folder="FAIL" ;;
    esac

    zip frames.zip frames/*

    sftp -P $SSH_PORT $SFTP_USER@$SFTP_HOST:domains/jotego.es <<EOF
mkdir regression
mkdir regression/$core
mkdir regression/$core/$setname
mkdir regression/$core/$setname/$folder
cd regression/$core/$setname/$folder
put frames.zip
bye
EOF

    return $dest
}

main "$@"
