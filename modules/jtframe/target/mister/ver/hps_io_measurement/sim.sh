#!/bin/bash
set -euo pipefail

main() {
	parse_args "$@"
	check_environment
	prepare_sources
	build_test
	run_test
}

parse_args() {
	if (( $# > 1 )) || [[ ${1:-local} != local ]]; then
		echo "Usage: $0 [local]" >&2
		exit 2
	fi
	mode=${1:-local}
}

check_environment() {
	script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
	repo_root=$(cd -- "$script_dir/../../../../../../" && pwd -P)
	if [[ "${JTROOT:-}" != "$repo_root" || "${JTFRAME:-}" != "$repo_root/modules/jtframe" ||
	      "${CORES:-}" != "$repo_root/cores" || "${MODULES:-}" != "$repo_root/modules" ||
	      "${JTBIN:-}" != "$repo_root/release" || "${RLS:-}" != "$repo_root/release" ||
	      "${MRA:-}" != "$repo_root/release/mra" || "${ROM:-}" != "$repo_root/rom" ]]; then
		echo "Source setprj.sh and pin JTROOT/JTFRAME/CORES/MODULES/JTBIN/RLS/MRA/ROM to this worktree before running." >&2
		exit 2
	fi
	artifact_dir=/nobackup/tasks/jtcores-201/artifacts/hps
	mkdir -p "$artifact_dir"
	build_dir="$artifact_dir/obj_measurement_$mode"
	build_log="$artifact_dir/hps_io_measurement_$mode.build.log"
	run_log="$artifact_dir/hps_io_measurement_$mode.run.log"
	gather_file="$artifact_dir/hps_io_measurement_$mode.gather"
}

prepare_sources() {
	printf '%s\n' "$JTFRAME/target/mister/hdl/sys/hps_io.sv" > "$gather_file"
}

build_test() {
	verilator --binary --timing -j 2 -Wno-fatal --top-module test \
		--Mdir "$build_dir" "$script_dir/test.sv" -f "$gather_file" > "$build_log" 2>&1
}

run_test() {
	"$build_dir/Vtest" > "$run_log" 2>&1
	cat "$run_log"
	printf 'build_log=%s\nrun_log=%s\nexit_status=0\n' "$build_log" "$run_log"
}

main "$@"
