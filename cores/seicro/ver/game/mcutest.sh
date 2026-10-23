#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 23-10-2026

set -euo pipefail
seicro_repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd -P)
case "${1:-all}" in
    -h|--help)
        printf 'Usage: %s [decode|compare|bus|compat|board|nsc|mr|all]\n' "$0"
        exit 0 ;;
    decode) seicro_cases=TEST_MCU_DECODE ;;
    compare) seicro_cases=TEST_COMPARE_6802,TEST_COMPARE_NSC ;;
    bus) seicro_cases=TEST_BUS,TEST_BUS_0_0,TEST_BUS_0_1,TEST_BUS_0_2,TEST_BUS_0_3,TEST_BUS_0_4,TEST_BUS_0_5,TEST_BUS_0_6,TEST_BUS_0_7,TEST_BUS_1_0,TEST_BUS_1_1,TEST_BUS_1_2,TEST_BUS_1_3,TEST_BUS_1_4,TEST_BUS_1_5,TEST_BUS_1_6,TEST_BUS_1_7 ;;
    compat) seicro_cases=TEST_MCU_COMPAT ;;
    board) seicro_cases=TEST_MCU ;;
    nsc) seicro_cases=TEST_NSC ;;
    mr) seicro_cases=TEST_MR_6802,TEST_MR_NSC ;;
    all) seicro_cases=TEST_MCU_DECODE,TEST_COMPARE_6802,TEST_COMPARE_NSC,TEST_BUS,TEST_BUS_0_0,TEST_BUS_0_1,TEST_BUS_0_2,TEST_BUS_0_3,TEST_BUS_0_4,TEST_BUS_0_5,TEST_BUS_0_6,TEST_BUS_0_7,TEST_BUS_1_0,TEST_BUS_1_1,TEST_BUS_1_2,TEST_BUS_1_3,TEST_BUS_1_4,TEST_BUS_1_5,TEST_BUS_1_6,TEST_BUS_1_7,TEST_MCU_COMPAT,TEST_MCU,TEST_NSC,TEST_MR_6802,TEST_MR_NSC ;;
    *) printf 'Unsupported MCU suite: %s\n' "$1" >&2; exit 2 ;;
esac
exec "$seicro_repo/cores/seicro/ver/hdl/test.sh" --macros "$seicro_cases"
