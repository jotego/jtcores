#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 30-10-2026
set -euo pipefail
if [[ "${1:-}" == --delete && -s nvram.bin ]]; then
    cp nvram.bin backup.bin
fi
