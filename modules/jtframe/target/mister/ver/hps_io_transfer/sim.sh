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
	mode=${1:-local}
	case "$mode" in
		local|baseline) ;;
		*) echo "Usage: $0 [local|baseline]" >&2; exit 2 ;;
	esac
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
	build_dir="$artifact_dir/obj_$mode"
	build_log="$artifact_dir/hps_io_transfer_$mode.build.log"
	run_log="$artifact_dir/hps_io_transfer_$mode.run.log"
	gather_file="$artifact_dir/hps_io_transfer_$mode.gather"
}

prepare_sources() {
	if [[ $mode == baseline ]]; then
		hps_source="$artifact_dir/hps_io_baseline.sv"
		git -C "$repo_root" show 9cb695ac1:modules/jtframe/target/mister/hdl/sys/hps_io.sv > "$hps_source"
		expect_failure=1
		defines=(-DBASELINE_CONTROL)
	else
		hps_source="$JTFRAME/target/mister/hdl/sys/hps_io.sv"
		expect_failure=0
		defines=()
	fi
	printf '%s\n%s\n%s\n%s\n' \
		"$hps_source" \
		"$JTFRAME/target/mister/hdl/jtframe_mister_dwnld.v" \
		"$JTFRAME/hdl/ram/jtframe_rpwp_ram.v" \
		"$JTFRAME/hdl/ram/jtframe_ram.v" > "$gather_file"
}

build_test() {
	verilator --binary --timing -j 2 -Wno-fatal --top-module test \
		"${defines[@]}" --Mdir "$build_dir" "$script_dir/test.sv" -f "$gather_file" > "$build_log" 2>&1
}

run_test() {
	local status=0
	set +e
	"$build_dir/Vtest" > "$run_log" 2>&1
	status=$?
	set -e
	cat "$run_log"
	printf 'build_log=%s\nrun_log=%s\nexit_status=%s\n' "$build_log" "$run_log" "$status"
	if (( expect_failure )); then
		if (( status == 0 )); then
			echo "ERROR: baseline unexpectedly passed" >&2
			exit 1
		fi
		grep -F 'first upload read must pulse at the requested address' "$run_log" >/dev/null || {
			echo "ERROR: baseline failed for a reason other than the upload-address regression" >&2
			exit 1
		}
		echo "EXPECTED BASELINE FAILURE: upload start address is incorrect"
	elif (( status != 0 )); then
		exit "$status"
	fi
}

main "$@"
