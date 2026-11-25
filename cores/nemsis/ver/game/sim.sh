#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 25-11-2026

set -e

setname=${1:-konamigt}
case "$setname" in
    konamigt|nemesis|nemesisuk) ;;
    *) printf 'Unknown set: %s\n' "$setname" >&2; exit 2 ;;
esac
frames=${2:-560}
if (( $# > 1 )); then shift 2; elif (( $# > 0 )); then shift; fi

cd "$(dirname "$0")/.."
mkdir -p "$setname"
cd "$setname"
exec jtsim -setname "$setname" -skipROM -mister -load -video "$frames" "$@"
