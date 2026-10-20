#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Configure and inspect the explicit CPU incremental partition."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re


CPU_ROOT = (
    "QSYS_test_board:inst|jttms10_fpga_runner:jttms10_runner|"
    "jttms10_system:u_cpu"
)
PARTITION_FILE = "incremental_db/jttms10_system_u_cpu"
PARTITION = "CPU"
PRESERVATION = "PLACEMENT_AND_ROUTING"
RESULT_FORMAT = "jttms10-explicit-cpu-partition-result-v1"


def _assignment_section(line: str, assignment: str) -> str | None:
    if "-name " + assignment not in line:
        return None
    match = re.search(r"(?:-section_id\s+)(?:\"([^\"]+)\"|([^\s]+))", line)
    return (match.group(1) or match.group(2)) if match else None


def configure_qsf(qsf_path: Path, mode: str) -> dict:
    """Set exact Top/CPU partition assignments without touching other QSF data."""
    if mode not in {"seed", "update"}:
        raise ValueError(f"unsupported partition mode: {mode}")
    qsf_path = Path(qsf_path)
    original = qsf_path.read_text()
    lines = original.splitlines()

    # Keep the existing root partition assignment. It must be unique and name |.
    roots = [line for line in lines if _assignment_section(line, "PARTITION_HIERARCHY") == "Top"]
    if roots != [line for line in roots if re.search(
            r"-name\s+PARTITION_HIERARCHY\s+root_partition\s+-to\s+\|(?:\s|$)", line)]:
        raise ValueError("QSF must retain exactly one Top root_partition assignment to |")
    if len(roots) != 1:
        raise ValueError(f"QSF needs exactly one Top root partition; found {len(roots)}")

    filtered = []
    for line in lines:
        section = _assignment_section(line, "PARTITION_NETLIST_TYPE")
        preserve_section = _assignment_section(line, "PARTITION_FITTER_PRESERVATION_LEVEL")
        hierarchy_section = _assignment_section(line, "PARTITION_HIERARCHY")
        if section in {"Top", "CPU"} or preserve_section in {"Top", "CPU"}:
            continue
        if hierarchy_section == "CPU":
            continue
        if "-name INCREMENTAL_COMPILATION" in line:
            continue
        filtered.append(line)

    top_type = "SOURCE" if mode == "seed" else "POST_FIT"
    filtered.extend([
        "set_global_assignment -name INCREMENTAL_COMPILATION FULL_INCREMENTAL_COMPILATION",
        f'set_instance_assignment -name PARTITION_HIERARCHY {PARTITION_FILE} -to "{CPU_ROOT}" -section_id "CPU"',
        f'set_global_assignment -name PARTITION_NETLIST_TYPE {top_type} -section_id "Top"',
        f'set_global_assignment -name PARTITION_FITTER_PRESERVATION_LEVEL {PRESERVATION} -section_id "Top"',
        'set_global_assignment -name PARTITION_NETLIST_TYPE SOURCE -section_id "CPU"',
        f'set_global_assignment -name PARTITION_FITTER_PRESERVATION_LEVEL {PRESERVATION} -section_id "CPU"',
    ])
    qsf_path.write_text("\n".join(filtered) + "\n")
    return {
        "mode": mode,
        "cpu_partition": PARTITION,
        "cpu_root": CPU_ROOT,
        "cpu_netlist": "SOURCE",
        "top_netlist": top_type,
        "preservation": "PLACEMENT_AND_ROUTING",
        "qsf": str(qsf_path.resolve()),
    }


def query_tcl(mode: str) -> str:
    """Create a project-open gate that errors unless Quartus sees the exact plan."""
    top_netlist = "Source File" if mode == "seed" else "Post-Fit"
    expected = {
        "seed": ("Source File", "Source File"),
        "update": ("Post-Fit", "Source File"),
    }
    if mode not in expected:
        raise ValueError(f"unsupported partition mode: {mode}")
    top_netlist, cpu_netlist = expected[mode]
    return f'''package require ::quartus::project
package require ::quartus::incremental_compilation
project_open -revision test_board test_board
set parts [get_partition]
puts "PARTITIONS=$parts"
if {{[lsearch -exact $parts Top] < 0 || [lsearch -exact $parts CPU] < 0 || [llength $parts] != 2}} {{
  project_close -dont_export_assignments
  error "expected exactly Top and CPU partitions, got: $parts"
}}
set expected_root {{{CPU_ROOT}}}
foreach {{part expected_netlist expected_preserve}} [list \
  Top {{{top_netlist}}} {{Placement and Routing}} \
  CPU {{{cpu_netlist}}} {{Placement and Routing}}] {{
  set root [get_partition -partition $part -roots]
  set netlist [get_partition -partition $part -netlist_type]
  set preserve [get_partition -partition $part -preservation_level]
  puts "PARTITION=$part ROOTS=$root NETLIST=$netlist PRESERVATION=$preserve"
  if {{$part eq "Top" && $root ne "|"}} {{
    project_close -dont_export_assignments
    error "Top partition root mismatch: $root"
  }}
  if {{$part eq "CPU" && $root ne $expected_root}} {{
    project_close -dont_export_assignments
    error "CPU partition root mismatch: $root"
  }}
  if {{$netlist ne $expected_netlist || $preserve ne $expected_preserve}} {{
    project_close -dont_export_assignments
    error "partition $part settings mismatch: netlist=$netlist preserve=$preserve"
  }}
}}
set ic [get_global_assignment -name INCREMENTAL_COMPILATION]
puts "INCREMENTAL_COMPILATION=$ic"
if {{$ic ne "FULL_INCREMENTAL_COMPILATION"}} {{
  project_close -dont_export_assignments
  error "full incremental compilation is not enabled: $ic"
}}
project_close -dont_export_assignments
'''


def validate_query_output(text: str, mode: str) -> None:
    """Fail closed on missing/ignored Quartus partition assignments."""
    top_netlist = "Source File" if mode == "seed" else "Post-Fit"
    expected = (
        "PARTITIONS=Top CPU",
        f"PARTITION=Top ROOTS=| NETLIST={top_netlist} PRESERVATION=Placement and Routing",
        f"PARTITION=CPU ROOTS={CPU_ROOT} NETLIST=Source File PRESERVATION=Placement and Routing",
        "INCREMENTAL_COMPILATION=FULL_INCREMENTAL_COMPILATION",
        "Quartus Prime Shell was successful",
    )
    missing = [line for line in expected if line not in text]
    if missing:
        raise ValueError(f"Quartus partition query missing expected results: {missing}")


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def source_hashes_relative(manifest: dict) -> dict[str, str]:
    """Normalize frozen source paths so separate worktrees can be compared."""
    if manifest.get("source_root"):
        root = Path(manifest["source_root"]).resolve()
    else:
        # Older frozen V2 manifests predate the explicit source_root field. The
        # source set spans modules/jtframe and modules/jttms10, so its common
        # path must be the repository's modules directory.
        common = Path(os.path.commonpath(list(manifest["source_hashes"]))).resolve()
        if common.name != "modules":
            raise ValueError("cannot safely infer source root from legacy source hashes")
        root = common.parent
    relative = {}
    for name, digest in manifest["source_hashes"].items():
        path = Path(name).resolve()
        try:
            key = path.relative_to(root).as_posix()
        except ValueError as error:
            raise ValueError(f"frozen source lies outside source root: {path}") from error
        if key in relative:
            raise ValueError(f"duplicate relative source path: {key}")
        relative[key] = digest
    return relative


def compute_cpu_source_delta(parent_manifest: dict, candidate_manifest: dict) -> list[str]:
    """Require a real update whose only frozen-source changes are CPU HDL files."""
    before = source_hashes_relative(parent_manifest)
    after = source_hashes_relative(candidate_manifest)
    delta = sorted(name for name in set(before) | set(after)
                   if before.get(name) != after.get(name))
    if not delta:
        raise ValueError("partition update must contain an actual CPU RTL source change")
    bad = [name for name in delta if not name.startswith("modules/jttms10/hdl/") or
           Path(name).suffix != ".v"]
    if bad:
        raise ValueError(f"partition update changed source outside CPU HDL: {bad}")
    return delta


PARTITION_METADATA_INPUTS = {
    "v2-partition-parent.json",
    "v2-partition-stage-precompile.json",
    "v2-partition-query.tcl",
}

# These exact files are generated while building the CPU's Verilator dispatch
# model. They are captured in both build-input manifests for auditability, but
# are not Quartus compile inputs. Keep this an exact-path allowlist: HDL, ROM,
# QIP, SDC, cache source, and new model files remain authoritative inputs.
TRANSIENT_DISPATCH_MODEL_OUTPUTS = frozenset({
    "Vtest",
    "Vtest__ALL.a",
    "Vtest__ALL.o",
    "Vtest___024root__DepSet_h9b2d61ff__0__Slow.cpp",
    "Vtest___024root__DepSet_hc07518e4__0.cpp",
    "Vtest__ver.d",
    "Vtest__verFiles.dat",
    "build.log",
})


def _is_transient_dispatch_model_output(relative: str) -> bool:
    path = Path(relative)
    return (path.parts[:-1] == ("jttms10-generated", "dispatch-model") and
            path.name in TRANSIENT_DISPATCH_MODEL_OUTPUTS)


def _normalized_qsf(build: Path, relative_name: str, expected_hash: str) -> tuple[str, ...]:
    path = build / relative_name
    if not path.is_file() or sha256(path) != expected_hash:
        raise ValueError(f"frozen QSF is missing or changed: {path}")
    lines = []
    for line in path.read_text().splitlines():
        if any(token in line for token in (
                "-name PARTITION_HIERARCHY", "-name PARTITION_NETLIST_TYPE",
                "-name PARTITION_FITTER_PRESERVATION_LEVEL",
                "-name INCREMENTAL_COMPILATION")):
            continue
        lines.append(line.replace(str(build.resolve()), "$BUILD_DIR"))
    return tuple(lines)


def validate_compiled_input_deltas(
        parent_build: Path, candidate_build: Path, source_delta: list[str]
        ) -> tuple[dict[str, dict[str, str | None]],
                   dict[str, dict[str, str | None]]]:
    """Validate stable inputs and separately report known simulator cache churn.

    The raw input manifests remain complete. Only the exact transient outputs
    listed in TRANSIENT_DISPATCH_MODEL_OUTPUTS are removed from the stable
    compile-input comparison, and their before/after hashes are returned for
    the partition certificate.
    """
    parent_build = Path(parent_build).resolve(strict=True)
    candidate_build = Path(candidate_build).resolve(strict=True)

    def files(build: Path) -> dict[str, str]:
        manifest_path = build / "v2-build-inputs.json"
        manifest = json.loads(manifest_path.read_text())
        answer = {}
        for absolute, digest in manifest.get("files", {}).items():
            path = Path(absolute).resolve()
            try:
                relative = path.relative_to(build).as_posix()
            except ValueError as error:
                raise ValueError(f"compile input outside build tree: {path}") from error
            if relative in answer:
                raise ValueError(f"duplicate compile input path: {relative}")
            answer[relative] = digest
        return answer

    before, after = files(parent_build), files(candidate_build)
    changed = {name for name in before.keys() | after.keys()
               if before.get(name) != after.get(name)}
    ignored_metadata = changed & PARTITION_METADATA_INPUTS
    changed -= ignored_metadata
    transient = {name for name in changed if _is_transient_dispatch_model_output(name)}
    changed -= transient
    qsf_name = "test_board.qsf"
    qsf_changed = qsf_name in changed
    if not qsf_changed:
        raise ValueError("partition update did not change Top from SOURCE to POST_FIT in the QSF")
    before_qsf = _normalized_qsf(parent_build, qsf_name, before[qsf_name])
    after_qsf = _normalized_qsf(candidate_build, qsf_name, after[qsf_name])
    if before_qsf != after_qsf:
        raise ValueError("partition update changed QSF assignments outside the partition configuration")
    changed.remove(qsf_name)
    allowed_cpu_packages = {
        f"ip/jttms10_fpga_runner/{Path(name).name}" for name in source_delta
    }
    unexpected = sorted(name for name in changed if name not in allowed_cpu_packages)
    if unexpected:
        raise ValueError(f"partition update changed stable compiled inputs: {unexpected}")
    expected_cpu_packages = {f"ip/jttms10_fpga_runner/{Path(name).name}" for name in source_delta}
    if changed != expected_cpu_packages:
        raise ValueError(f"partition update did not compile every changed CPU module: expected {sorted(expected_cpu_packages)}, got {sorted(changed)}")
    if any(Path(name).suffix != ".v" or
           not name.startswith("ip/jttms10_fpga_runner/") for name in changed):
        raise ValueError(f"partition update changed a non-CPU packaged input: {sorted(changed)}")
    stable_delta = {
        name: {"parent_sha256": before.get(name), "candidate_sha256": after.get(name)}
        for name in sorted(changed)
    }
    transient_delta = {
        name: {"parent_sha256": before.get(name), "candidate_sha256": after.get(name)}
        for name in sorted(transient)
    }
    return stable_delta, transient_delta


def validate_compiled_input_delta(parent_build: Path, candidate_build: Path,
                                  source_delta: list[str]) -> dict[str, dict[str, str | None]]:
    """Compatibility wrapper returning only changed stable Quartus inputs."""
    stable_delta, _ = validate_compiled_input_deltas(parent_build, candidate_build, source_delta)
    return stable_delta


def extract_partition_observations(build: Path) -> dict[str, list[dict[str, str | int]]]:
    """Retain actual Quartus map/fit/log lines that describe partition handling."""
    build = Path(build)
    inputs = {
        "map": build / "output_files/test_board.map.rpt",
        "fit": build / "output_files/test_board.fit.rpt",
        "flow_log": build / "logs/v2-compile.log",
    }
    observed = {}
    for label, path in inputs.items():
        if not path.is_file():
            raise ValueError(f"partition observation source is missing: {path}")
        observed[label] = [
            {"line": number, "text": line.rstrip()}
            for number, line in enumerate(path.read_text(errors="replace").splitlines(), 1)
            if re.search(r"partition|incremental|preservation", line, re.IGNORECASE)
        ]
    return observed


def validate_partition_result(build: Path, result: dict) -> dict:
    """Validate the explicit partition provenance bound into a build result."""
    build = Path(build).resolve(strict=True)
    cert_path = build / "v2-partition-stage-result.json"
    if not cert_path.is_file() or result.get("partition_stage_sha256") != sha256(cert_path):
        raise ValueError("build result does not bind the explicit partition-stage certificate")
    cert = json.loads(cert_path.read_text())
    if (cert.get("format") != RESULT_FORMAT or cert.get("mode") not in {"seed", "update"} or
            cert.get("flow_exit_code") != 0 or cert.get("inputs_unchanged") is not True or
            cert.get("input_manifest_sha256") != sha256(build / "v2-build-inputs.json") or
            cert.get("compile_inputs_sha256") != sha256(build / "v2-compile-inputs.json") or
            cert.get("partition_config_sha256") != sha256(build / "v2-partition-stage-precompile.json") or
            cert.get("compile_time_sha256") != sha256(build / "logs/v2-compile.time") or
            cert.get("qsf_sha256") != sha256(build / "test_board.qsf") or
            cert.get("rbf_sha256") != sha256(build / "output_files/test_board.rbf") or
            cert.get("flow_log_sha256") != sha256(build / "logs/v2-compile.log")):
        raise ValueError("partition-stage certificate does not match the compiled inputs/image/log")
    config = json.loads((build / "v2-partition-stage-precompile.json").read_text())
    for field in ("parent_build_dir", "parent_build_result_sha256", "parent_inputs_sha256",
                  "parent_image_sha256", "parent_sta_summary_sha256",
                  "parent_partition_stage_sha256"):
        if cert.get(field) != config.get(field):
            raise ValueError(f"partition-stage parent provenance differs from frozen configuration: {field}")
    mode = cert["mode"]
    expected_command = ["/opt/quartus_free/quartus_sh", "--flow", "compile", "test_board"]
    if cert.get("command") != expected_command or cert.get("working_directory") != str(build):
        raise ValueError("partition-stage certificate command/cwd mismatch")
    expected_nets = {"seed": {"Top": "Source File", "CPU": "Source File"},
                     "update": {"Top": "Post-Fit", "CPU": "Source File"}}[mode]
    if cert.get("partitions") != {
            "Top": {"root": "|", "netlist": expected_nets["Top"],
                    "preservation": "Placement and Routing"},
            "CPU": {"root": CPU_ROOT, "netlist": expected_nets["CPU"],
                    "preservation": "Placement and Routing"}}:
        raise ValueError("partition-stage certificate has unexpected roots or netlist settings")
    if (result.get("partition_mode") != mode or result.get("flow_exit_code") != 0 or
            result.get("full_flow_only") is not True or
            result.get("flow_log_sha256") != cert.get("flow_log_sha256") or
            result.get("rbf_sha256") != cert.get("rbf_sha256") or
            result.get("input_manifest_sha256") != cert.get("input_manifest_sha256") or
            result.get("compile_inputs_sha256") != cert.get("compile_inputs_sha256")):
        raise ValueError("partition-stage certificate differs from the common build certificate")
    timing_text = (build / "logs/v2-compile.time").read_text()
    timing_seconds = re.search(r"seconds=([0-9.]+)", timing_text)
    timing_exit = re.search(r"exit_code=(\d+)", timing_text)
    if (not timing_seconds or not timing_exit or int(timing_exit.group(1)) != 0 or
            float(timing_seconds.group(1)) != cert.get("flow_seconds") or
            cert.get("flow_seconds") != result.get("flow_seconds")):
        raise ValueError("partition certificate does not match the actual compile timing record")
    delta_path = build / "v2-partition-source-delta.json"
    if cert.get("source_delta_sha256") != sha256(delta_path):
        raise ValueError("partition source-delta record is missing or changed")
    delta_record = json.loads(delta_path.read_text())
    if (delta_record.get("mode") != mode or
            delta_record.get("source_hashes") != cert.get("source_hashes") or
            delta_record.get("source_delta") != cert.get("source_delta")):
        raise ValueError("partition source-delta record differs from the stage certificate")
    if cert.get("compiled_input_delta") != delta_record.get("compiled_input_delta"):
        raise ValueError("partition compiled-input delta differs from the stage certificate")
    if (cert.get("transient_compiled_input_delta", {}) !=
            delta_record.get("transient_compiled_input_delta", {})):
        raise ValueError("partition transient-input delta differs from the stage certificate")
    if cert.get("partition_query_log_sha256") != sha256(build / "logs/v2-partition-query.log"):
        raise ValueError("partition query log is missing or changed")
    query = (build / "logs/v2-partition-query.log").read_text(errors="replace")
    if "PARTITIONS=Top CPU" not in query or "Quartus Prime Shell was successful" not in query:
        raise ValueError("Quartus project-open partition preflight did not complete successfully")
    if "PARTITION=Top ROOTS=|" not in query or f"PARTITION=CPU ROOTS={CPU_ROOT}" not in query:
        raise ValueError("Quartus partition query did not confirm the exact Top and CPU roots")
    marker = cert.get("terminal_marker")
    log = (build / "logs/v2-compile.log").read_text(errors="replace")
    if not marker or marker not in log or "successful" not in marker.lower():
        raise ValueError("partition compile lacks its actual successful terminal marker")
    reports = cert.get("stage_reports")
    if not isinstance(reports, dict) or set(reports) != {"map", "fit", "asm", "sta"}:
        raise ValueError("partition compile certificate lacks all fresh stage reports")
    freeze_time = (build / "v2-compile-inputs.json").stat().st_mtime_ns
    for stage, digest in reports.items():
        report = build / f"output_files/test_board.{stage}.rpt"
        if (not report.is_file() or sha256(report) != digest or report.stat().st_mtime_ns <= freeze_time):
            raise ValueError(f"partition stage report is missing, stale, or changed: {stage}")
    source_manifest = json.loads((build / "v2-build-inputs.json").read_text())
    current_sources = source_hashes_relative(source_manifest)
    if cert.get("source_hashes") != current_sources:
        raise ValueError("partition certificate source hashes do not match frozen source manifest")
    parent_dir = Path(cert.get("parent_build_dir", "")).resolve(strict=True)
    parent_bindings = {
        "parent_build_result_sha256": parent_dir / "v2-build-result.json",
        "parent_inputs_sha256": parent_dir / "v2-build-inputs.json",
        "parent_image_sha256": parent_dir / "output_files/test_board.rbf",
        "parent_sta_summary_sha256": parent_dir / "output_files/test_board.sta.summary",
    }
    for field, path in parent_bindings.items():
        if not path.is_file() or cert.get(field) != sha256(path):
            raise ValueError(f"partition parent binding is missing or changed: {field}")
    parent_result = json.loads(parent_bindings["parent_build_result_sha256"].read_text())
    if (parent_result.get("format") not in {"jttms10-incremental-build-result-v1",
                                             "jttms10-rapid-build-result-v1"} or
            parent_result.get("flow_exit_code") != 0 or
            parent_result.get("inputs_unchanged") is not True or
            parent_result.get("input_manifest_sha256") != cert.get("parent_inputs_sha256") or
            parent_result.get("rbf_sha256") != cert.get("parent_image_sha256")):
        raise ValueError("partition parent build result does not certify its image/inputs")
    if not parent_result.get("full_flow_only") and parent_result.get("format") != "jttms10-rapid-build-result-v1":
        raise ValueError("partition parent is not a certified full or Rapid compile")
    parent_sta_rows = re.findall(
        r"Type\s*:\s*[^\n]+\nSlack\s*:\s*([-\d.]+)\nTNS\s*:\s*([-\d.]+)",
        parent_bindings["parent_sta_summary_sha256"].read_text())
    if not parent_sta_rows or any(float(slack) <= 0 or float(tns) != 0
                                  for slack, tns in parent_sta_rows):
        raise ValueError("partition stage parent must have positive all-row STA")
    if mode == "seed":
        if (cert.get("parent_partition_stage_sha256") is not None or
                cert.get("source_delta") != [] or cert.get("compiled_input_delta") != {} or
                cert.get("transient_compiled_input_delta", {}) != {} or
                delta_record.get("parent_source_hashes") != {}):
            raise ValueError("partition seed must not claim a prior partition seed or source delta")
    else:
        parent_cert_path = parent_dir / "v2-partition-stage-result.json"
        parent_result_path = parent_dir / "v2-build-result.json"
        if (not parent_cert_path.is_file() or not parent_result_path.is_file() or
                cert.get("parent_partition_stage_sha256") != sha256(parent_cert_path) or
                cert.get("parent_build_result_sha256") != sha256(parent_result_path)):
            raise ValueError("partition update does not bind its exact seed build")
        parent_cert = json.loads(parent_cert_path.read_text())
        if parent_cert.get("mode") != "seed":
            raise ValueError("partition update parent is not a seed build")
        validate_partition_result(parent_dir, parent_result)
        if delta_record.get("parent_source_hashes") != parent_cert.get("source_hashes"):
            raise ValueError("partition source delta does not bind the seed CPU source fingerprints")
        parent_sta = parent_dir / "output_files/test_board.sta.summary"
        sta_rows = re.findall(r"Type\s*:\s*[^\n]+\nSlack\s*:\s*([-\d.]+)\nTNS\s*:\s*([-\d.]+)",
                              parent_sta.read_text())
        if not sta_rows or any(float(slack) <= 0 or float(tns) != 0 for slack, tns in sta_rows):
            raise ValueError("partition update seed must retain positive all-row STA")
        previous = parent_cert.get("source_hashes")
        delta = sorted(name for name in set(previous or {}) | set(current_sources)
                       if (previous or {}).get(name) != current_sources.get(name))
        if cert.get("source_delta") != delta or not delta:
            raise ValueError("partition update source delta is empty or differs from its seed")
        if any(not name.startswith("modules/jttms10/hdl/") or
               Path(name).suffix != ".v" for name in delta):
            raise ValueError(f"partition update changed non-CPU-RTL inputs: {delta}")
        observed_input_delta, observed_transient_delta = validate_compiled_input_deltas(
            parent_dir, build, cert.get("source_delta", []))
        if cert.get("compiled_input_delta") != observed_input_delta:
            raise ValueError("partition update compiled-input delta differs from the seed")
        if cert.get("transient_compiled_input_delta", {}) != observed_transient_delta:
            raise ValueError("partition update transient-input delta differs from the seed")
    if cert.get("partition_observations") != extract_partition_observations(build):
        raise ValueError("partition handling observations differ from fresh map/fit/flow reports")
    return cert


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    configure = sub.add_parser("configure")
    configure.add_argument("--qsf", type=Path, required=True)
    configure.add_argument("--mode", choices=("seed", "update"), required=True)
    configure.add_argument("--metadata", type=Path, required=True)
    query = sub.add_parser("write-query")
    query.add_argument("--mode", choices=("seed", "update"), required=True)
    query.add_argument("--output", type=Path, required=True)
    verify = sub.add_parser("validate-query")
    verify.add_argument("--mode", choices=("seed", "update"), required=True)
    verify.add_argument("--log", type=Path, required=True)
    args = parser.parse_args()
    if args.command == "configure":
        result = configure_qsf(args.qsf, args.mode)
        args.metadata.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    elif args.command == "write-query":
        args.output.write_text(query_tcl(args.mode))
    else:
        try:
            validate_query_output(args.log.read_text(errors="replace"), args.mode)
        except ValueError as error:
            raise SystemExit(str(error)) from error


if __name__ == "__main__":
    main()
