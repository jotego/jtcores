#!/bin/bash
set -euo pipefail

main() {
    [[ $# == 1 ]] || { echo "Usage: $0 BUILD_DIRECTORY" >&2; exit 2; }
    local src out
    src=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
    out=$(realpath -m "$1")
    [[ $out != "$src" && $out != "$src/board" && $out != "$src/rtl" ]]
    mkdir -p "$out"
    cd "$out"
    quartus_sh -t "$src/board/build.tcl" > project.log 2>&1
    quartus_sh --flow compile c96 > compile.log 2>&1
    quartus_cpf -c output_files/c96.sof output_files/c96-yamaha104.rbf > cpf.log 2>&1
    dtc -@ -I dts -O dtb -o output_files/c96-yamaha104.dtbo "$src/board/c96.dts"
    sha256sum output_files/c96-yamaha104.rbf output_files/c96-yamaha104.dtbo
}

main "$@"
