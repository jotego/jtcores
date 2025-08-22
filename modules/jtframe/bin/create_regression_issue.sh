#!/bin/bash

main() {
    parse_args "$@"

    title="Regression [$core, $setname]"

    declare -A args
    args[assignee]="jorgesg82"
    args[label]="regression"

    case $regression_code in
        0)
            # Regression successfull
            return 0
        ;;

        1)
            # Simulation failed
            args[title]="$title Simulation failed"
            args[body]="You can check the simulation log on the SFTP server"
            issue args
        ;;

        2)
            # Cannot find core's folder
            args[title]="$title Core folder not found"
            args[body]="The core directory could not be located. Please verify the core name and the expected path on the repository, and ensure the folder exists and is accessible."
            issue args
        ;;

        3)
            # Frames validation successfull, cannot get audio to validate
            args[title]="$title Unable to get audio to validate"
            args[body]="Audio could not be retrieved for validation. It can be possible if it is the first time you generate audio for this setname and/or you still don't move it to the 'valid' folder. Please check if the audio is fine in the SFTP server and move it to 'valid' folder."
            issue args
        ;;

        4)
            # Frames validation successfull, audio validation failed
            args[title]="$title Audio validation failed"
            args[body]="Audio validation failed. Please review the audio files on the SFTP server and the validation logs to fix format, duration, or content issues."
            issue args
        ;;

        5)
            # Not enough frames to simulate, audio validation successfull
            args[title]="$title Not enough uploaded frames to validate"
            args[body]="Frames could not be retrieved for validation. It can be possible if it is the first time you generate frames for this setname and/or you still don't move them to the 'valid' folder. Please check if the frames are fine in the SFTP server and move them to 'valid' folder."
            issue args
        ;;

        6)
            # Not enough frames to simulate, cannot get audio to validate
            args[title]="$title Not enough uploaded frames to validate"
            args[body]="Frames could not be retrieved for validation. It can be possible if it is the first time you generate frames for this setname and/or you still don't move them to the 'valid' folder. Please check if the frames are fine in the SFTP server and move them to 'valid' folder."
            issue args

            args[title]="$title Unable to get audio to validate"
            args[body]="Audio could not be retrieved for validation. Please check the SFTP server upload and audio file naming/paths."
            issue args
        ;;

        7)
            # Not enough frames to simulate, audio validation failed
            args[title]="$title Not enough uploaded frames to validate"
            args[body]="Frames could not be retrieved for validation. It can be possible if it is the first time you generate frames for this setname and/or you still don't move them to the 'valid' folder. Please check if the frames are fine in the SFTP server and move them to 'valid' folder."
            issue args

            args[title]="$title Audio validation failed"
            args[body]="Audio validation failed. Please review the audio on the SFTP server"
            issue args
        ;;

        8)
            # Frames validation failed, audio validation successfull
            args[title]="$title Frames validation failed"
            args[body]="Frames validation failed. Please review the frames or the video on the SFTP server"
            issue args
        ;;

        9)
            # Frames validation failed, cannot get audio to validate
            args[title]="$title Frames validation failed"
            args[body]="Frames validation failed. Please review the frames or the video on the SFTP server"
            issue args

            args[title]="$title Unable to get audio to validate"
            args[body]="Frames could not be retrieved for validation. It can be possible if it is the first time you generate frames for this setname and/or you still don't move them to the 'valid' folder. Please check if the frames are fine in the SFTP server and move them to 'valid' folder."
            issue args
        ;;

        10)
            # Frames validation failed, audio validation failed
            args[title]="$title Frames validation failed"
            args[body]="Frames validation failed. Please review the frames or the video on the SFTP server"
            issue args

            args[title]="$title Audio validation failed"
            args[body]="Audio validation failed. Please review the audio on the SFTP server"
            issue args
        ;;

        11)
            # Unable to get required zips
            args[title]="$title Required packages not found"
            args[body]="The required zip packages could not be obtained. Please verify that the zips are present on the SFTP server with the expected names and paths."
            issue args
        ;;

        12)
            # There was an error executing the script
            args[title]="$title Script execution error"
            args[body]="There was an unexpected error executing the regression script. Please check the action logs and any generated error output to diagnose the failure."
            issue args
        ;;

        *)
            # Unknown code
            args[title]="$title Unknown regression code ($regression_code)"
            args[body]="An unknown regression result code was returned. Please review logs to determine the cause."
            issue args
            return 1
        ;;
    esac
}

issue() {
    declare -n args_ref=$1
    declare -a gh_args

    # echo "${!args_ref[@]}" #DEBUG

    for arg in "${!args_ref[@]}"; do
        value="${args_ref[$arg]}"
        gh_args+=(--$arg "$value")
    done

    gh issue create "${gh_args[@]}"
    # echo "${gh_args[@]}" #DEBUG
}

parse_args() {
    if [[ $# -lt 3 ]]; then
        echo "Usage: $0 <regression_exit_code> <core> <setname>"
        exit 1
    fi

    if [[ "$1" =~ ^[0-9]+$ ]]; then
        regression_code="$1"
    else
        echo "[ERROR] regression exit code should be a number"
        exit 1
    fi

    core="$2"
    setname="$3"
}

main "$@"