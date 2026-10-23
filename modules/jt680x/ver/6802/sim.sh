#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 23-10-2026

set -euo pipefail
jt6802_repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd -P)
if [ "${1:-}" != --inside ]; then
    case $(uname -m) in arm64|aarch64) jt6802_default=arm64 ;; *) jt6802_default=latest ;; esac
    jt6802_image=${JTFRAME_SIM_IMAGE:-jotego/linter:$jt6802_default}
    docker image inspect "$jt6802_image" >/dev/null
    exec docker run --rm --pull=never -v "$jt6802_repo:/jtcores" \
        -w /jtcores "$jt6802_image" -lc \
        'exec bash /jtcores/modules/jt680x/ver/6802/sim.sh --inside'
fi
unset VERILATOR_ROOT
exec "$jt6802_repo/modules/jtframe/devops/xsimunit.sh" "$jt6802_repo/modules/jt680x/ver/6802"
