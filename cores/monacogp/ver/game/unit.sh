#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 08-11-2026
set -euo pipefail

root=$(cd "$(dirname "$0")/../../../.." && pwd)
image=${JT_SIM_IMAGE:-jotego/simulator:latest}
if [ "$#" -eq 0 ]; then
    set -- gtest_trigger panel panel_colour
fi
for test in "$@"; do
    case "$test" in
        gtest_trigger|panel|panel_colour) ;;
        *) printf 'Unknown test: %s\n' "$test" >&2; exit 2 ;;
    esac
done
docker run --rm --pull=never \
    -v "$root:/jtcores" -w /jtcores \
    -e JTROOT=/jtcores -e JTFRAME=/jtcores/modules/jtframe \
    "$image" -c 'export PATH=".:$JTFRAME/bin:$PATH"; for test in "$@"; do simunit.sh --run "cores/monacogp/ver/hdl/$test" || exit; done' bash "$@"
