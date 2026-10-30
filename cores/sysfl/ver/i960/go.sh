#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 18-9-2026
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
docker run --rm --pull=never -v "$repo":/jtcores --entrypoint bash jotego/simulator:arm64 \
    -c 'source /jtcores/setprj.sh >/dev/null 2>&1; set -e; for bench in muldiv icache cpu; do simunit.sh --run "/jtcores/cores/sysfl/ver/hdl/$bench"; done'
