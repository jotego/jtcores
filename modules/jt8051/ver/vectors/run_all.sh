#!/bin/bash
# SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
# SPDX-License-Identifier: GPL-3.0-or-later

main() {
    local group
    while IFS= read -r group; do
        run_group "$group"
    done < <(list_groups)
}

list_groups() {
    ruby -ryaml -e 'YAML.load_file("tests.yaml").each_key { |name| puts name }'
}

run_group() {
    local group="$1"
    echo "=== JT8051 vector: $group ==="
    JT8051_VECTOR="$group" simunit.sh --run .
}

main "$@"
