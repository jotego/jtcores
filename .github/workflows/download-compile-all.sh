#!/usr/bin/env bash
# Download the latest complete Compile all bundle into $JTBUILDS.

main() {
    parse_args "$@"
    require_tools
    prepare_destination
    setup_logging

    local repository="jotego/jtcores"
    local bundle
    bundle="$(find_latest_bundle "$repository")"

    local run_id artifact_name
    IFS=$'\t' read -r run_id artifact_name <<< "$bundle"
    download_bundle "$repository" "$run_id" "$artifact_name"
}

set -euo pipefail
TEMPORARY_DIR=
VERBOSE=

parse_args() {
    while (( $# > 0 )); do
        case "$1" in
            -v|--verbose)
                VERBOSE=1;;
            -h|--help)
                cat <<'EOF'
Usage: download-compile-all.sh

Downloads the newest non-expired bundle artifact produced by the Compile all
GitHub Actions workflow into $JTBUILDS.
EOF
                exit 0;;
            *)
                fatal "Unknown argument: $1";;
        esac
        shift
    done
}

require_tools() {
    command -v gh >/dev/null || fatal "GitHub CLI (gh) is required"
    command -v unzip >/dev/null || fatal "unzip is required"
    command -v cmp >/dev/null || fatal "cmp is required"
    gh auth status >/dev/null 2>&1 || fatal "Authenticate GitHub CLI with: gh auth login"
}

prepare_destination() {
    [[ -n "${JTBUILDS:-}" ]] || fatal "JTBUILDS is undefined"
    mkdir -p -- "$JTBUILDS"
    [[ -d "$JTBUILDS" ]] || fatal "JTBUILDS is not a directory: $JTBUILDS"
}

setup_logging() {
    local log_file="$JTBUILDS/download.log"

    if [[ -n "$VERBOSE" ]]; then
        exec > >(tee -a "$log_file") 2>&1
    else
        exec >> "$log_file" 2>&1
    fi

    printf '%s download-compile-all started\n' "$(date --iso-8601=seconds)"
}

find_latest_bundle() {
    local repository="$1"
    local page=1
    local runs run_id head_sha artifact_name artifact_names

    while :; do
        runs="$(gh api "repos/$repository/actions/workflows/compile-all.yaml/runs?status=completed&per_page=100&page=$page" \
            --jq '.workflow_runs[] | [.id, .head_sha] | @tsv')" || return 1
        [[ -n "$runs" ]] || break

        while IFS=$'\t' read -r run_id head_sha; do
            [[ -n "$run_id" && ${#head_sha} -ge 7 ]] || continue
            artifact_name="${head_sha:0:7}.zip"
            artifact_names="$(gh api "repos/$repository/actions/runs/$run_id/artifacts?per_page=100" \
                --jq '.artifacts[] | select(.expired == false) | .name')" || return 1

            if grep -Fxq -- "$artifact_name" <<< "$artifact_names"; then
                printf '%s\t%s\n' "$run_id" "$artifact_name"
                return
            fi
        done <<< "$runs"

        ((++page))
    done

    fatal "No non-expired Compile all bundle artifact was found"
}

download_bundle() {
    local repository="$1"
    local run_id="$2"
    local artifact_name="$3"
    local destination="$JTBUILDS/$artifact_name"

    if [[ -e "$destination" ]]; then
        [[ -f "$destination" ]] || fatal "Build path is not a regular file: $destination"
        if unzip -tq "$destination"; then
            printf 'Build already available: %s\n' "$destination"
            return
        fi
        printf 'Removing corrupt build: %s\n' "$destination" >&2
        rm -f -- "$destination"
    fi

    TEMPORARY_DIR="$(mktemp -d "$JTBUILDS/.compile-all.XXXXXX")" || fatal "Cannot create temporary directory in $JTBUILDS"
    trap cleanup_temporary_dir EXIT

    gh run download "$run_id" --repo "$repository" --name "$artifact_name" --dir "$TEMPORARY_DIR"
    [[ -f "$TEMPORARY_DIR/$artifact_name" ]] || fatal "Artifact did not contain $artifact_name"
    unzip -tq "$TEMPORARY_DIR/$artifact_name"

    if [[ -e "$destination" ]]; then
        if cmp -s "$TEMPORARY_DIR/$artifact_name" "$destination"; then
            printf 'Build already available: %s\n' "$destination"
            return
        fi
        fatal "Refusing to overwrite existing build: $destination"
    fi

    mv -- "$TEMPORARY_DIR/$artifact_name" "$destination"
    cleanup_temporary_dir
    trap - EXIT
    printf 'Downloaded run %s: %s\n' "$run_id" "$destination"
}

cleanup_temporary_dir() {
    if [[ -n "$TEMPORARY_DIR" && -d "$TEMPORARY_DIR" ]]; then
        rm -rf -- "$TEMPORARY_DIR"
    fi
    TEMPORARY_DIR=
}

fatal() {
    printf '%s\n' "Error: $*" >&2
    exit 1
}

main "$@"
