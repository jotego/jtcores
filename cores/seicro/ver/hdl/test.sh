#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 15-10-2026

set -euo pipefail
seicro_repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd -P)
if [ "${1:-}" != --inside ]; then
    case $(uname -m) in arm64|aarch64) seicro_tag=arm64 ;; *) seicro_tag=latest ;; esac
    seicro_image=${JTFRAME_SIM_IMAGE:-jotego/linter:$seicro_tag}
    docker image inspect "$seicro_image" >/dev/null
    exec docker run --rm --pull=never --ulimit core=0 \
        -v "$seicro_repo:/jtcores" -w /jtcores "$seicro_image" -lc \
        'exec bash /jtcores/cores/seicro/ver/hdl/test.sh --inside "$@"' seicro-unit "$@"
fi
shift
unset VERILATOR_ROOT
exec "$seicro_repo/modules/jtframe/devops/xsimunit.sh" "$seicro_repo/cores/seicro/ver/hdl" "$@"
