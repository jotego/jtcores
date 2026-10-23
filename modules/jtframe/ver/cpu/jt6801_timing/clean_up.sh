#!/bin/bash -e
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 24-10-2026

python3 verify_coverage.py sim.log
rm -f jt680x_ctrl_sim.rtl
