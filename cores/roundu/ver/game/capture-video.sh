#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 19-10-2026

set -euo pipefail
exec "$(dirname -- "${BASH_SOURCE[0]}")/../roundup5/mamedump.sh" "$@"
