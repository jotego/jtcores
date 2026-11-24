#!/bin/bash
# SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
# SPDX-License-Identifier: GPL-3.0-or-later

main() {
    local setname=${1:-slapfigh}
    if [[ $# -gt 0 ]]; then shift; fi
    case "$setname" in
        alcon|slapfigh|slapfigha|tigerh|tigerhj) ;;
        *) echo "Usage: $0 [alcon|slapfigh|slapfigha|tigerh|tigerhj] [jtsim arguments]" >&2; return 1;;
    esac
    cd "${JTROOT:?Source setprj.sh first}/cores/slap/ver/$setname" || return 1
    prepare_roms || return 1
    jtsim "$@"
}

prepare_roms() {
    jtutil sdram || return 1
}

main "$@"
