#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Source setprj.sh and set JOTEGO in the scheduler before calling this script.
# jtutil owns the common lock and all durable logs, including polling errors.
main() {
    exec "$JTFRAME/bin/jtutil" regression --poll "$@"
}

main "$@"
