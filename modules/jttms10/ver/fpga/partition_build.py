#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Configure and inspect the explicit CPU incremental partition."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile


CPU_ROOT = (
    "QSYS_test_board:inst|jttms10_fpga_runner:jttms10_runner|"
    "jttms10_system:u_cpu"
)
PARTITION_FILE = "incremental_db/jttms10_system_u_cpu"
PARTITION = "CPU"
PRESERVATION = "PLACEMENT_AND_ROUTING"
RESULT_FORMAT = "jttms10-explicit-cpu-partition-result-v1"
MICROCODE_RESULT_FORMAT = "jttms10-explicit-cpu-microcode-partition-result-v1"
SEED_PACKAGE_FORMAT = "jttms10-seed-cpu-package-reconstruction-v1"
GENERATED_PAYLOAD_FORMAT = "jttms10-generated-cpu-payloads-v1"
CPU_MICROCODE_YAML = frozenset({
    "modules/jttms10/cfg/files.yaml",
    "modules/jttms10/ucode/control.yaml",
    "modules/jttms10/ucode/gfx_line.yaml",
    "modules/jttms10/ucode/gfx.yaml",
    "modules/jttms10/ucode/memory.yaml",
    "modules/jttms10/ucode/tms10.yaml",
    "modules/jttms10/ucode/bus_phase.yaml",
})
RUNNER_SOURCES = ("jttms10_fpga_runner.v", "jttms10_fpga_stimulus.v")
GENERATED_CPU_SUFFIXES = frozenset({".uc", ".vh", ".hex"})
GENERATED_CPU_PAYLOADS = frozenset({
    "tms10.uc", "tms10.vh", "tms10_param.vh", "tms10_dispatch.hex",
    "tms10_gfx.uc", "tms10_gfx.vh", "tms10_gfx_param.vh",
    "tms10_bus_phase.uc", "tms10_bus_phase.vh", "tms10_bus_phase_param.vh",
})
DISPATCH_MODEL_OUTPUTS = frozenset({
    "build.log", "verilated.d", "verilated.o", "verilated_threads.d",
    "verilated_threads.o", "Vtest", "Vtest___024root__DepSet_h9b2d61ff__0.cpp",
    "Vtest___024root__DepSet_h9b2d61ff__0__Slow.cpp",
    "Vtest___024root__DepSet_hc07518e4__0.cpp",
    "Vtest___024root__DepSet_hc07518e4__0__Slow.cpp",
    "Vtest___024root.h", "Vtest___024root__Slow.cpp", "Vtest__ALL.a",
    "Vtest__ALL.cpp", "Vtest__ALL.d", "Vtest__ALL.o", "Vtest_classes.mk",
    "Vtest.cpp", "Vtest.h", "Vtest__main.cpp", "Vtest.mk", "Vtest__pch.h",
    "Vtest__Syms.cpp", "Vtest__Syms.h", "Vtest__ver.d", "Vtest__verFiles.dat",
})
NON_COMPILE_GENERATED_OUTPUTS = frozenset({
    "jttms10-generated/tms10.lst",
    "jttms10-generated/tms10_gfx.lst",
    "jttms10-generated/tms10_bus_phase.lst",
    "jttms10-generated/dispatch-build.log",
    *(f"jttms10-generated/dispatch-model/{name}" for name in DISPATCH_MODEL_OUTPUTS),
})
REQUIRED_GENERATED_DIAGNOSTICS = frozenset({
    "jttms10-generated/tms10.lst",
    "jttms10-generated/tms10_gfx.lst",
    "jttms10-generated/tms10_bus_phase.lst",
    "jttms10-generated/dispatch-build.log",
})
CPU_GENERATED_COMPILE_INPUTS = frozenset(
    f"jttms10-generated/{name}" for name in GENERATED_CPU_PAYLOADS)
LEGACY_SAVED_SEED_RESULT_SHA256 = (
    "1965a8243c0b8aa30f6d2db68bbdd13398ab0ace7b61eb3692d27e3522fd07ce")
LEGACY_SAVED_SEED_HELPER_SHA256 = (
    "0a4c9c5d2ffd5b236467d8ee74639b601dc184d83067b30368875cbc08f527a7")
LEGACY_SAVED_SEED_HELPER_REL = "modules/jttms10/ver/fpga/partition_build.py"


def _assignment_section(line: str, assignment: str) -> str | None:
    if "-name " + assignment not in line:
        return None
    match = re.search(r"(?:-section_id\s+)(?:\"([^\"]+)\"|([^\s]+))", line)
    return (match.group(1) or match.group(2)) if match else None


def configure_qsf(qsf_path: Path, mode: str) -> dict:
    """Set exact Top/CPU partition assignments without touching other QSF data."""
    if mode not in {"seed", "update", "microcode-update"}:
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
    if mode == "microcode-update":
        mode = "update"
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


def _qsf_verilog_assignment_path(line: str) -> str | None:
    match = re.match(r"^\s*set_global_assignment\s+-library\s+\S+\s+-name\s+VERILOG_FILE\s+(.+?)\s*$", line)
    if not match:
        return None
    value = match.group(1).strip()
    if value.startswith("\"") and value.endswith("\""):
        value = value[1:-1]
    return value


def _is_cpu_source_filename(name: str) -> bool:
    """Match the CPU top plus its namespaced Verilog modules."""
    return name == "jttms10.v" or (name.startswith("jttms10_") and name.endswith(".v"))


def _is_package_cpu_verilog(line: str, package: Path) -> bool:
    value = _qsf_verilog_assignment_path(line)
    if value is None:
        return False
    path = Path(value)
    return (path.parent == package and
            _is_cpu_source_filename(path.name))


def reconstruct_seed_cpu_package(
        parent_build: Path, candidate_build: Path, source_root: Path) -> dict:
    """Make a SOURCE/SOURCE seed's CPU package match one explicit source tree.

    This seed-only operation records and removes stale parent CPU modules and
    their direct QSF assignments. It refuses unclassified package files and
    any QIP/QSYS/Tcl reference to a stale module. HPS/Qsys/SDC assets are only
    read and hash-compared; they are never edited here.
    """
    parent_build = Path(parent_build).resolve(strict=True)
    candidate_build = Path(candidate_build).resolve(strict=True)
    source_root = Path(source_root).resolve(strict=True)
    source_hdl = source_root / "modules/jttms10/hdl"
    package = candidate_build / "ip/jttms10_fpga_runner"
    parent_package = parent_build / "ip/jttms10_fpga_runner"
    parent_qsf = parent_build / "test_board.qsf"
    qsf = candidate_build / "test_board.qsf"
    if not all(p.is_file() for p in (parent_qsf, qsf)):
        raise ValueError("seed package reconstruction requires parent and candidate QSF files")
    cpu_sources = sorted(source_hdl.glob("*.v"))
    if not cpu_sources:
        raise ValueError("candidate CPU HDL source set is empty")
    if any(not _is_cpu_source_filename(p.name) for p in cpu_sources):
        raise ValueError("candidate CPU HDL contains a source outside the jttms10 module namespace")
    selected = {p.name for p in cpu_sources} | set(RUNNER_SOURCES)
    if any(not (source_root / "modules/jttms10/ver/fpga" / name).is_file()
           for name in RUNNER_SOURCES):
        raise ValueError("candidate FPGA runner sources are incomplete")
    candidate_hw_tcl = source_root / "modules/jttms10/ver/fpga/ip/jttms10_fpga_runner/jttms10_fpga_runner_hw.tcl"
    parent_hw_tcl = parent_package / candidate_hw_tcl.name
    if not candidate_hw_tcl.is_file() or not parent_hw_tcl.is_file() or sha256(candidate_hw_tcl) != sha256(parent_hw_tcl):
        raise ValueError("seed changes the Qsys component interface; regenerate/review Qsys instead of reusing it")

    package_files = sorted(p for p in package.glob("*.v") if p.is_file())
    parent_package_files = sorted(p for p in parent_package.glob("*.v") if p.is_file())
    package_names = {p.name for p in package_files}
    parent_names = {p.name for p in parent_package_files}
    expected_parent_qsf = {p.name for p in parent_package_files}
    parent_qsf_lines = parent_qsf.read_text().splitlines()
    parent_assignments = [line for line in parent_qsf_lines if _is_package_cpu_verilog(line, parent_package)]
    parent_assignment_names = {Path(_qsf_verilog_assignment_path(line)).name for line in parent_assignments}
    if parent_assignment_names != expected_parent_qsf:
        raise ValueError("parent QSF CPU package references do not exactly match packaged Verilog")

    stale_names = sorted(parent_names - selected)
    added_names = sorted(selected - parent_names)
    extra_candidate_names = package_names - selected
    if extra_candidate_names - parent_names:
        raise ValueError(f"copied candidate package contains unclassified Verilog: {sorted(extra_candidate_names - parent_names)}")
    for name in sorted(extra_candidate_names):
        if sha256(package / name) != sha256(parent_package / name):
            raise ValueError(f"candidate's inherited stale module differs from parent: {name}")
    if any(not name.startswith("jttms10_") for name in stale_names):
        raise ValueError(f"parent contains a stale non-CPU Verilog module: {stale_names}")

    infrastructure = [
        "QSYS_test_board/synthesis/QSYS_test_board.qip",
        "QSYS_test_board.tcl", "QSYS_test_board.qsys", "runner_clock.sdc",
    ]
    if any(not (parent_build / rel).is_file() for rel in infrastructure):
        raise ValueError("seed parent lacks a required preserved Qsys/SDC file")
    infrastructure_hashes = {name: sha256(parent_build / name) for name in infrastructure}
    for stale in stale_names:
        for rel in infrastructure:
            if stale in (parent_build / rel).read_text(errors="replace"):
                raise ValueError(f"stale module {stale} is referenced by preserved infrastructure {rel}")

    stale_assignment_lines = [line for line in parent_assignments
                              if Path(_qsf_verilog_assignment_path(line)).name in stale_names]
    if {Path(_qsf_verilog_assignment_path(line)).name for line in stale_assignment_lines} != set(stale_names):
        raise ValueError("every stale parent CPU module must have an audited direct QSF assignment")
    removed_files = []
    for name in stale_names:
        source = parent_package / name
        destination = package / name
        if destination.exists():
            if sha256(destination) != sha256(source):
                raise ValueError(f"stale CPU module differs from parent package: {name}")
            destination.unlink()
        if (package / name).exists():
            raise ValueError(f"failed to remove stale parent CPU module: {name}")
        removed_files.append({"path": name, "sha256": sha256(source), "reason": "absent from candidate CPU HDL manifest"})

    copied = []
    for source in cpu_sources:
        target = package / source.name
        target.write_bytes(source.read_bytes())
        copied.append({"path": source.name, "sha256": sha256(source)})
    for name in RUNNER_SOURCES:
        source = source_root / "modules/jttms10/ver/fpga" / name
        target = package / name
        target.write_bytes(source.read_bytes())
        copied.append({"path": name, "sha256": sha256(source)})

    qsf_lines = qsf.read_text().splitlines()
    qsf_lines = [line for line in qsf_lines if not _is_package_cpu_verilog(line, package)]
    desired = [f'set_global_assignment -library "QSYS_test_board" -name VERILOG_FILE {package/name}'
               for name in sorted(selected)]
    qsf_lines.extend(desired)
    qsf.write_text("\n".join(qsf_lines) + "\n")
    final_qsf = qsf.read_text().splitlines()
    final_assignments = [line for line in final_qsf if _is_package_cpu_verilog(line, package)]
    final_names = {Path(_qsf_verilog_assignment_path(line)).name for line in final_assignments}
    actual_package_names = {p.name for p in package.glob("*.v") if p.is_file()}
    if final_names != selected or actual_package_names != selected:
        raise ValueError("reconstructed seed package and direct QSF references are not the exact candidate manifest")
    after_infrastructure = {name: sha256(candidate_build / name) for name in infrastructure}
    if infrastructure_hashes != after_infrastructure:
        raise ValueError("seed package reconstruction altered preserved Qsys/SDC infrastructure")

    return {
        "format": SEED_PACKAGE_FORMAT,
        "parent_build": str(parent_build),
        "candidate_build": str(candidate_build),
        "candidate_source_root": str(source_root),
        "qsys_component_tcl_sha256": sha256(candidate_hw_tcl),
        "parent_package_verilog": [{"path": p.name, "sha256": sha256(p)} for p in parent_package_files],
        "candidate_selected_verilog": copied,
        "removed_stale_cpu_modules": removed_files,
        "removed_stale_qsf_assignments": stale_assignment_lines,
        "candidate_qsf_cpu_assignments": final_assignments,
        "infrastructure_sha256_before_after": {name: {"before": infrastructure_hashes[name],
                                                         "after": after_infrastructure[name]}
                                                for name in infrastructure},
    }


def clear_inherited_seed_package_audit(build: Path) -> None:
    """Drop the parent's seed-only audit before preparing any candidate stage."""
    (Path(build) / "v2-partition-seed-package-reconstruction.json").unlink(missing_ok=True)


def seed_package_reconstruction_binding(build: Path, mode: str) -> str | None:
    """Return the seed audit hash, rejecting stale seed metadata on updates."""
    path = Path(build) / "v2-partition-seed-package-reconstruction.json"
    if mode == "seed":
        if not path.is_file():
            raise ValueError("partition seed result lacks its package reconstruction audit")
        return sha256(path)
    if mode in {"update", "microcode-update"} and path.exists():
        raise ValueError("partition update inherited a seed-only package reconstruction audit")
    if mode not in {"update", "microcode-update"}:
        raise ValueError(f"unsupported partition mode for seed audit binding: {mode}")
    return None


def compute_cpu_microcode_source_delta(parent_manifest: dict, candidate_manifest: dict) -> list[str]:
    """Allow CPU Verilog, the exact generated dispatch ROM, and named YAMLs."""
    before = source_hashes_relative(parent_manifest)
    after = source_hashes_relative(candidate_manifest)
    delta = sorted(name for name in set(before) | set(after)
                   if before.get(name) != after.get(name))
    if not delta:
        raise ValueError("microcode partition update must contain a CPU source change")
    bad = [name for name in delta
           if not (name.startswith("modules/jttms10/hdl/") and Path(name).suffix == ".v")
           and name != "modules/jttms10/hdl/tms10_dispatch.hex"
           and name not in CPU_MICROCODE_YAML]
    if bad:
        raise ValueError(f"microcode update changed source outside CPU HDL/allowlisted YAML: {bad}")
    if not any(name in CPU_MICROCODE_YAML for name in delta):
        raise ValueError("microcode update requires an explicit CPU microcode YAML delta")
    return delta


def generated_payload_delta(parent_build: Path, candidate_build: Path) -> dict:
    """Compare independently regenerated CPU payloads and every copied package."""
    parent_build = Path(parent_build).resolve(strict=True)
    candidate_build = Path(candidate_build).resolve(strict=True)
    parent_path = parent_build / "v2-generated-payloads.json"
    candidate_path = candidate_build / "v2-generated-payloads.json"
    if not parent_path.is_file() or not candidate_path.is_file():
        raise ValueError("microcode update requires generated-payload manifests in seed and candidate")
    parent = json.loads(parent_path.read_text())
    candidate = json.loads(candidate_path.read_text())
    if parent.get("format") != GENERATED_PAYLOAD_FORMAT or candidate.get("format") != GENERATED_PAYLOAD_FORMAT:
        raise ValueError("unsupported generated-payload manifest format")
    if set(parent.get("payloads", {})) != GENERATED_CPU_PAYLOADS:
        raise ValueError("seed generated-payload set differs from the audited CPU payload inventory")
    if set(candidate.get("payloads", {})) != GENERATED_CPU_PAYLOADS:
        raise ValueError("candidate generated-payload set differs from the audited CPU payload inventory")
    if (not parent.get("generator_sha256") or
            parent.get("generator_sha256") != candidate.get("generator_sha256")):
        raise ValueError("microcode update changed or omitted the frozen payload generator")
    if parent.get("payloads", {}).keys() != candidate.get("payloads", {}).keys():
        raise ValueError("microcode update changed generated-payload file set")
    names = sorted(parent["payloads"])
    changed = {name: {"parent_sha256": parent["payloads"][name],
                      "candidate_sha256": candidate["payloads"][name]}
               for name in names if parent["payloads"][name] != candidate["payloads"][name]}
    if not changed:
        raise ValueError("allowlisted YAML source delta produced no generated CPU payload change")
    for build, manifest in ((parent_build, parent), (candidate_build, candidate)):
        expected_copies = manifest.get("copies", {})
        for name, digest in manifest["payloads"].items():
            for rel in (name, f"jttms10-generated/{name}", f"ip/jttms10_fpga_runner/{name}"):
                path = build / rel
                if not path.is_file() or sha256(path) != digest:
                    raise ValueError(f"generated CPU payload copy mismatch: {path}")
                if expected_copies.get(rel) != digest:
                    raise ValueError(f"generated payload manifest copy hash mismatch: {rel}")
        if set(expected_copies) != {rel for name in manifest["payloads"]
                                    for rel in (name, f"jttms10-generated/{name}",
                                                f"ip/jttms10_fpga_runner/{name}")}:
            raise ValueError("generated payload manifest contains missing or unclassified copies")
    return changed


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


def is_non_compile_generated_output(relative: str) -> bool:
    """Recognize only exact listing/log/Verilator outputs outside Quartus inputs."""
    return relative in NON_COMPILE_GENERATED_OUTPUTS


def is_classified_cpu_generated_output(relative: str) -> bool:
    """Accept exact Quartus payloads and exact recorded diagnostic outputs."""
    return relative in CPU_GENERATED_COMPILE_INPUTS or is_non_compile_generated_output(relative)


def frozen_cpu_source_paths(repo_root: Path, helper_dir: Path) -> list[Path]:
    """Return every tracked helper, module source, and generator source hashed at freeze."""
    repo_root = Path(repo_root).resolve(strict=True)
    helper_dir = Path(helper_dir).resolve(strict=True)
    source_roots = (
        repo_root / "modules/jttms10/ucode",
        repo_root / "modules/jttms10/ver/decoder",
        repo_root / "modules/jttms10/ver/gfx",
        repo_root / "modules/jttms10/ver/ucode",
        repo_root / "modules/jttms10/hdl",
        repo_root / "modules/jtframe/src/jtframe/ucode",
    )
    source_files = {
        repo_root / "modules/jttms10/ver/build.sh",
        repo_root / "modules/jttms10/cfg/files.yaml",
        repo_root / "modules/jtframe/bin/jtframe",
        helper_dir / "build-runner-incremental.sh",
        helper_dir / "write_programming_receipt.py",
        helper_dir / "partition_build.py",
    }
    missing = sorted(path for path in source_files if not path.is_file())
    if missing:
        names = ", ".join(str(path) for path in missing)
        raise ValueError(f"required frozen CPU source is missing: {names}")
    source_files.update((helper_dir).glob("*.v"))
    for root in source_roots:
        source_files.update(path for path in root.rglob("*") if path.is_file())
    return sorted(path.resolve() for path in source_files
                  if path.is_file() and path.suffix != ".pyc"
                  and "__pycache__" not in path.parts)


def cpu_generated_output_inventory(
        generated_root: Path,
        expected_payloads: frozenset[str] = GENERATED_CPU_PAYLOADS,
        required_diagnostics: frozenset[str] = REQUIRED_GENERATED_DIAGNOSTICS,
) -> dict[str, dict[str, str]]:
    """Hash exact consumed payloads separately from generated diagnostics."""
    generated_root = Path(generated_root).resolve(strict=True)
    payloads, diagnostics = {}, {}
    for path in sorted(p for p in generated_root.rglob("*") if p.is_file()):
        relative = (Path("jttms10-generated") / path.relative_to(generated_root)).as_posix()
        if relative in CPU_GENERATED_COMPILE_INPUTS:
            payloads[Path(relative).name] = sha256(path)
        elif is_non_compile_generated_output(relative):
            diagnostics[relative] = sha256(path)
        else:
            raise ValueError(f"unclassified generated CPU output: {relative}")
    if set(payloads) != expected_payloads:
        raise ValueError("generated CPU Quartus payload inventory differs from the exact supported set")
    if not required_diagnostics <= set(diagnostics):
        missing = sorted(required_diagnostics - set(diagnostics))
        raise ValueError(f"generated CPU diagnostic inventory lacks required outputs: {missing}")
    return {"payloads": payloads, "diagnostics": diagnostics}


def regenerate_cpu_generation_inventory(
        source_root: Path,
        expected_payloads: frozenset[str] = GENERATED_CPU_PAYLOADS,
        required_diagnostics: frozenset[str] = REQUIRED_GENERATED_DIAGNOSTICS,
) -> dict[str, dict[str, str]]:
    """Re-run the independent generator and classify every emitted output."""
    source_root = Path(source_root).resolve(strict=True)
    generator = source_root / "modules/jttms10/ver/build.sh"
    if not generator.is_file():
        raise ValueError("selected source tree lacks the CPU payload generator")
    with tempfile.TemporaryDirectory(prefix="jttms10-generation-verify-") as temporary:
        output = Path(temporary) / "jttms10-generated"
        result = subprocess.run(["bash", str(generator), str(output)], cwd=source_root,
                                capture_output=True, text=True, check=False)
        if result.returncode:
            raise ValueError("independent CPU generation failed: " +
                             (result.stderr or result.stdout)[-2000:])
        return cpu_generated_output_inventory(output, expected_payloads,
                                              required_diagnostics)


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


def non_compile_generated_output_hashes(build: Path) -> dict[str, str]:
    """Read diagnostic outputs from new or legacy complete input manifests."""
    build = Path(build).resolve(strict=True)
    manifest = json.loads((build / "v2-build-inputs.json").read_text())
    answer = {}
    for relative, digest in manifest.get("non_compile_generated_outputs", {}).items():
        if not is_non_compile_generated_output(relative):
            raise ValueError(f"unclassified non-compile generated output: {relative}")
        path = build / relative
        if not path.is_file() or sha256(path) != digest:
            raise ValueError(f"non-compile generated output is missing or changed: {relative}")
        answer[relative] = digest
    for absolute, digest in manifest.get("files", {}).items():
        path = Path(absolute).resolve()
        try:
            relative = path.relative_to(build).as_posix()
        except ValueError as error:
            raise ValueError(f"compile input outside build tree: {path}") from error
        if is_non_compile_generated_output(relative):
            if relative in answer and answer[relative] != digest:
                raise ValueError(f"duplicate diagnostic hash differs: {relative}")
            answer[relative] = digest
    return answer


def compare_non_compile_generated_outputs(parent_build: Path,
                                           candidate_build: Path) -> dict[str, dict[str, str | None]]:
    """Record exact changes to generated listings/logs outside Quartus inputs."""
    before = non_compile_generated_output_hashes(parent_build)
    after = non_compile_generated_output_hashes(candidate_build)
    return {
        name: {"parent_sha256": before.get(name), "candidate_sha256": after.get(name)}
        for name in sorted(before.keys() | after.keys())
        if before.get(name) != after.get(name)
    }


def validate_compiled_input_deltas(
        parent_build: Path, candidate_build: Path, source_delta: list[str],
        generated_delta: dict | None = None, *,
        allow_generated_diagnostic_delta: bool = False
        ) -> tuple[dict[str, dict[str, str | None]],
                   dict[str, dict[str, str | None]],
                   dict[str, dict[str, str | None]]]:
    """Validate stable inputs and separately report known simulator cache churn.

    The raw input manifests remain complete. Only the exact transient outputs
    listed in TRANSIENT_DISPATCH_MODEL_OUTPUTS are removed from the stable
    compile-input comparison. Their before/after hashes are returned
    separately for the partition certificate. Only seed and typed microcode
    stages may change the complete diagnostic inventory; the legacy HDL-only
    update continues to allow just its original transient eight-output set.
    """
    parent_build = Path(parent_build).resolve(strict=True)
    candidate_build = Path(candidate_build).resolve(strict=True)

    def input_manifest(build: Path) -> dict:
        manifest_path = build / "v2-build-inputs.json"
        return json.loads(manifest_path.read_text())

    def relative_files(build: Path, manifest: dict) -> dict[str, str]:
        answer = {}
        for absolute, digest in manifest.get("files", {}).items():
            path = Path(absolute).resolve()
            try:
                relative = path.relative_to(build).as_posix()
            except ValueError as error:
                raise ValueError(f"compile input outside build tree: {path}") from error
            if is_non_compile_generated_output(relative):
                continue
            if relative in answer:
                raise ValueError(f"duplicate compile input path: {relative}")
            answer[relative] = digest
        return answer

    parent_manifest = input_manifest(parent_build)
    candidate_manifest = input_manifest(candidate_build)
    before = relative_files(parent_build, parent_manifest)
    after = relative_files(candidate_build, candidate_manifest)
    before_diagnostics = non_compile_generated_output_hashes(parent_build)
    after_diagnostics = non_compile_generated_output_hashes(candidate_build)
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
    hdl_delta = [name for name in source_delta
                 if name.startswith("modules/jttms10/hdl/") and Path(name).suffix == ".v"]
    allowed_cpu_packages = {f"ip/jttms10_fpga_runner/{Path(name).name}" for name in hdl_delta}
    expected_cpu_packages = set(allowed_cpu_packages)
    if generated_delta is not None:
        for name in generated_delta:
            if Path(name).suffix not in GENERATED_CPU_SUFFIXES or Path(name).name != name:
                raise ValueError(f"unclassified generated CPU payload delta: {name}")
            expected_cpu_packages.update({name, f"jttms10-generated/{name}",
                                          f"ip/jttms10_fpga_runner/{name}"})
    # Generated payload changes are accepted only in the separate typed mode.
    unexpected = sorted(name for name in changed if name not in expected_cpu_packages)
    if unexpected:
        raise ValueError(f"partition update changed stable compiled inputs: {unexpected}")
    if changed != expected_cpu_packages:
        raise ValueError(f"partition update compiled-input delta differs from exact CPU source/payload manifest: expected {sorted(expected_cpu_packages)}, got {sorted(changed)}")
    for name in changed:
        if name in allowed_cpu_packages:
            if Path(name).suffix != ".v" or not name.startswith("ip/jttms10_fpga_runner/"):
                raise ValueError(f"partition update changed a non-CPU HDL package: {name}")
        elif generated_delta is None or name not in {
                path for payload in generated_delta
                for path in (payload, f"jttms10-generated/{payload}",
                             f"ip/jttms10_fpga_runner/{payload}")}:
            raise ValueError(f"partition update changed an unclassified generated input: {name}")
    stable_delta = {
        name: {"parent_sha256": before.get(name), "candidate_sha256": after.get(name)}
        for name in sorted(changed)
    }
    transient_delta = {
        name: {"parent_sha256": before.get(name), "candidate_sha256": after.get(name)}
        for name in sorted(transient)
    }
    diagnostic_delta = {
        name: {"parent_sha256": before_diagnostics.get(name),
               "candidate_sha256": after_diagnostics.get(name)}
        for name in sorted(before_diagnostics.keys() | after_diagnostics.keys())
        if before_diagnostics.get(name) != after_diagnostics.get(name)
    }
    if not allow_generated_diagnostic_delta:
        unallowed = sorted(name for name in diagnostic_delta
                           if not _is_transient_dispatch_model_output(name))
        if unallowed:
            raise ValueError(f"partition update changed non-compile generated diagnostics: {unallowed}")
    return stable_delta, transient_delta, diagnostic_delta


def validate_seed_package_reconstruction(build: Path, parent_build: Path, source_root: Path) -> dict:
    """Recheck the seed's exact CPU package/QSF diff and untouched Qsys inputs."""
    build=Path(build).resolve(strict=True); parent_build=Path(parent_build).resolve(strict=True)
    source_root=Path(source_root).resolve(strict=True)
    audit_path=build/'v2-partition-seed-package-reconstruction.json'
    if not audit_path.is_file():
        raise ValueError("SOURCE/SOURCE seed lacks its CPU package reconstruction audit")
    audit=json.loads(audit_path.read_text())
    if audit.get('format')!=SEED_PACKAGE_FORMAT or audit.get('parent_build')!=str(parent_build) or \
       audit.get('candidate_build')!=str(build) or audit.get('candidate_source_root')!=str(source_root):
        raise ValueError("seed package reconstruction audit identity mismatch")
    source_hdl=source_root/'modules/jttms10/hdl'
    package=build/'ip/jttms10_fpga_runner'
    selected={p.name for p in source_hdl.glob('*.v')}|set(RUNNER_SOURCES)
    if {p.name for p in package.glob('*.v') if p.is_file()}!=selected:
        raise ValueError("seed package files differ from exact candidate CPU/runner source manifest")
    selected_hashes={row['path']:row['sha256'] for row in audit.get('candidate_selected_verilog',[])}
    if set(selected_hashes)!=selected:
        raise ValueError("seed package audit selected-file inventory is incomplete")
    for name in selected:
        source=(source_hdl/name if name not in RUNNER_SOURCES else
                source_root/'modules/jttms10/ver/fpga'/name)
        if sha256(source)!=selected_hashes[name] or sha256(package/name)!=selected_hashes[name]:
            raise ValueError(f"seed package source hash mismatch: {name}")
    parent_qsf=(parent_build/'test_board.qsf').read_text().splitlines()
    candidate_qsf=(build/'test_board.qsf').read_text().splitlines()
    parent_pkg=parent_build/'ip/jttms10_fpga_runner'
    candidate_pkg=build/'ip/jttms10_fpga_runner'
    parent_package_names={p.name for p in parent_pkg.glob('*.v') if p.is_file()}
    expected_old=set(parent_package_names)
    expected_stale=sorted(expected_old-selected)
    expected_stale_rows=[line for line in parent_qsf
                         if _is_package_cpu_verilog(line,parent_pkg) and
                         Path(_qsf_verilog_assignment_path(line)).name in expected_stale]
    old_rows=[line for line in parent_qsf if _is_package_cpu_verilog(line,parent_pkg)]
    new_rows=[line for line in candidate_qsf if _is_package_cpu_verilog(line,candidate_pkg)]
    expected_new=selected
    audit_old={row['path'] for row in audit.get('parent_package_verilog',[])}
    audit_stale={row['path']:row['sha256'] for row in audit.get('removed_stale_cpu_modules',[])}
    if audit_old != expected_old or \
       {name:audit_stale.get(name) for name in expected_stale} != {
           name:sha256(parent_pkg/name) for name in expected_stale} or \
       audit.get('removed_stale_qsf_assignments') != expected_stale_rows or \
       any((candidate_pkg/name).exists() for name in expected_stale) or \
       {Path(_qsf_verilog_assignment_path(line)).name for line in old_rows}!=expected_old or \
       {Path(_qsf_verilog_assignment_path(line)).name for line in new_rows}!=expected_new:
        raise ValueError("seed QSF direct CPU file assignments do not match package manifests")
    def non_cpu_qsf(tree: Path, package_dir: Path) -> tuple[str, ...]:
        lines = []
        for line in (tree/'test_board.qsf').read_text().splitlines():
            if any(token in line for token in (
                    "-name PARTITION_HIERARCHY", "-name PARTITION_NETLIST_TYPE",
                    "-name PARTITION_FITTER_PRESERVATION_LEVEL",
                    "-name INCREMENTAL_COMPILATION")):
                continue
            if _is_package_cpu_verilog(line, package_dir):
                continue
            lines.append(line.replace(str(tree.resolve()), "$BUILD_DIR"))
        return tuple(lines)
    base_non_cpu=non_cpu_qsf(parent_build,parent_pkg)
    new_non_cpu=non_cpu_qsf(build,candidate_pkg)
    if base_non_cpu!=new_non_cpu:
        raise ValueError("seed changed QSF assignments outside partition settings and CPU package files")
    infrastructure = {
        "QSYS_test_board/synthesis/QSYS_test_board.qip",
        "QSYS_test_board.tcl", "QSYS_test_board.qsys", "runner_clock.sdc",
    }
    infra=audit.get('infrastructure_sha256_before_after',{})
    if set(infra) != infrastructure:
        raise ValueError("seed audit does not cover every preserved Qsys/SDC input")
    for name,pair in infra.items():
        if pair.get('before')!=pair.get('after') or sha256(parent_build/name)!=pair.get('before') or \
           sha256(build/name)!=pair.get('after'):
            raise ValueError(f"seed changed preserved Qsys/SDC infrastructure: {name}")
    return audit


def regenerate_cpu_payload_hashes(source_root: Path) -> dict[str, str]:
    """Run generation and return only the exact Quartus-consumed payloads."""
    return regenerate_cpu_generation_inventory(source_root)["payloads"]


def validate_generated_payload_manifest(build: Path, source_root: Path | None = None,
                                        *, verify_generation: bool = False) -> dict:
    """Verify the generator manifest and all three compiled payload copies."""
    build=Path(build).resolve(strict=True)
    path=build/'v2-generated-payloads.json'
    if not path.is_file(): raise ValueError("generated CPU payload manifest is missing")
    data=json.loads(path.read_text())
    if data.get('format')!=GENERATED_PAYLOAD_FORMAT or not data.get('payloads'):
        raise ValueError("generated CPU payload manifest has an unsupported format or empty payload set")
    if set(data['payloads']) != GENERATED_CPU_PAYLOADS:
        raise ValueError("generated CPU payload inventory differs from the audited fixed CPU output set")
    if any(Path(name).name!=name or Path(name).suffix not in GENERATED_CPU_SUFFIXES
           for name in data['payloads']):
        raise ValueError("generated CPU payload manifest contains an unclassified output")
    if source_root is not None:
        source_root=Path(source_root).resolve(strict=True)
        generator=source_root/'modules/jttms10/ver/build.sh'
        if data.get('generator_sha256')!=sha256(generator):
            raise ValueError("generated CPU payload manifest does not bind the selected generator")
        if verify_generation and data['payloads'] != regenerate_cpu_payload_hashes(source_root):
            raise ValueError("generated CPU payloads differ from independent source regeneration")
    expected_copies={}
    for name,digest in data['payloads'].items():
        for rel in (name,f'jttms10-generated/{name}',f'ip/jttms10_fpga_runner/{name}'):
            file=build/rel
            if not file.is_file() or sha256(file)!=digest:
                raise ValueError(f"generated CPU payload copy mismatch: {rel}")
            expected_copies[rel]=digest
    if data.get('copies')!=expected_copies:
        raise ValueError("generated CPU payload copy inventory differs from its exact manifest")
    return data


def validate_dispatch_rom_source(source_root: Path, payload_manifest: dict) -> None:
    """Keep the checked-in controller ROM byte-identical to generated output."""
    path = Path(source_root).resolve(strict=True) / "modules/jttms10/hdl/tms10_dispatch.hex"
    expected = payload_manifest.get("payloads", {}).get("tms10_dispatch.hex")
    if not expected or not path.is_file() or sha256(path) != expected:
        raise ValueError("checked-in dispatch ROM differs from the independently generated CPU payload")


def validate_compiled_input_delta(parent_build: Path, candidate_build: Path,
                                  source_delta: list[str]) -> dict[str, dict[str, str | None]]:
    """Compatibility wrapper returning only changed stable Quartus inputs."""
    stable_delta, _, _ = validate_compiled_input_deltas(parent_build, candidate_build, source_delta)
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
    result_path = build / "v2-build-result.json"
    if (result_path.is_file() and
            sha256(result_path) == LEGACY_SAVED_SEED_RESULT_SHA256):
        disk_result = json.loads(result_path.read_text())
        if result != disk_result:
            raise ValueError("legacy saved-seed result differs from its on-disk certificate")
        if result.get("partition_mode") != "seed":
            raise ValueError("pinned legacy saved-seed result is not a seed")
        inputs_path = build / "v2-build-inputs.json"
        if (not inputs_path.is_file() or
                result.get("input_manifest_sha256") != sha256(inputs_path)):
            raise ValueError("legacy saved-seed result does not bind its frozen source manifest")
        inputs = json.loads(inputs_path.read_text())
        try:
            source_root = Path(inputs["source_root"]).resolve(strict=True)
            legacy_helper = (source_root / LEGACY_SAVED_SEED_HELPER_REL).resolve(strict=True)
            bound_helper_hash = inputs["source_hashes"][str(legacy_helper)]
        except (KeyError, OSError, TypeError) as error:
            raise ValueError("legacy saved-seed manifest lacks its pinned validator source") from error
        if (bound_helper_hash != LEGACY_SAVED_SEED_HELPER_SHA256 or
                sha256(legacy_helper) != LEGACY_SAVED_SEED_HELPER_SHA256):
            raise ValueError("legacy saved-seed validator source hash is not the pinned original")
        module_name = "_jtcores_149_partition_build_seed_0a4c9c5d"
        spec = importlib.util.spec_from_file_location(module_name, legacy_helper)
        if spec is None or spec.loader is None:
            raise ValueError("cannot load pinned legacy saved-seed validator")
        legacy = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(legacy)
        return legacy.validate_partition_result(build, result)

    cert_path = build / "v2-partition-stage-result.json"
    if not cert_path.is_file() or result.get("partition_stage_sha256") != sha256(cert_path):
        raise ValueError("build result does not bind the explicit partition-stage certificate")
    cert = json.loads(cert_path.read_text())
    mode = cert.get("mode")
    expected_format = MICROCODE_RESULT_FORMAT if mode == "microcode-update" else RESULT_FORMAT
    if (cert.get("format") != expected_format or mode not in {"seed", "update", "microcode-update"} or
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
    expected_command = ["/opt/quartus_free/quartus_sh", "--flow", "compile", "test_board"]
    if cert.get("command") != expected_command or cert.get("working_directory") != str(build):
        raise ValueError("partition-stage certificate command/cwd mismatch")
    expected_nets = {"seed": {"Top": "Source File", "CPU": "Source File"},
                     "update": {"Top": "Post-Fit", "CPU": "Source File"},
                     "microcode-update": {"Top": "Post-Fit", "CPU": "Source File"}}[mode]
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
    if (cert.get("non_compile_generated_output_delta", {}) !=
            delta_record.get("non_compile_generated_output_delta", {})):
        raise ValueError("non-compile generated-output delta differs from the stage certificate")
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
        source_root = Path(source_manifest.get("source_root", "")).resolve(strict=True)
        validate_seed_package_reconstruction(build, parent_dir, source_root)
        payload_manifest = validate_generated_payload_manifest(build, source_root, verify_generation=True)
        validate_dispatch_rom_source(source_root, payload_manifest)
        if cert.get("seed_package_reconstruction_sha256") != sha256(
                build / "v2-partition-seed-package-reconstruction.json"):
            raise ValueError("partition seed certificate does not bind package reconstruction audit")
        if cert.get("generated_payload_manifest_sha256") != sha256(
                build / "v2-generated-payloads.json"):
            raise ValueError("partition seed certificate does not bind generated CPU payloads")
        if delta_record.get("non_compile_generated_output_delta") != \
                compare_non_compile_generated_outputs(parent_dir, build):
            raise ValueError("partition seed diagnostic-output delta differs from parent/candidate hashes")
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
        generated_delta = None
        if mode == "microcode-update":
            typed_delta = compute_cpu_microcode_source_delta(
                json.loads((parent_dir / "v2-build-inputs.json").read_text()), source_manifest)
            source_root = Path(source_manifest.get("source_root", "")).resolve(strict=True)
            parent_inputs = json.loads((parent_dir / "v2-build-inputs.json").read_text())
            parent_source_root = Path(parent_inputs.get("source_root", "")).resolve(strict=True)
            parent_payload_manifest = validate_generated_payload_manifest(
                parent_dir, parent_source_root, verify_generation=True)
            candidate_payload_manifest = validate_generated_payload_manifest(
                build, source_root, verify_generation=True)
            validate_dispatch_rom_source(parent_source_root, parent_payload_manifest)
            validate_dispatch_rom_source(source_root, candidate_payload_manifest)
            generated_delta = generated_payload_delta(parent_dir, build)
            if delta_record.get("generated_payload_delta") != generated_delta or \
                    cert.get("generated_payload_delta") != generated_delta:
                raise ValueError("microcode source record does not match regenerated payload deltas")
            if cert.get("generated_payload_manifest_sha256") != sha256(
                    build / "v2-generated-payloads.json"):
                raise ValueError("microcode update certificate does not bind generated payload manifest")
            if cert.get("seed_package_reconstruction_sha256") is not None:
                raise ValueError("microcode update must inherit seed package without reconstruction")
        else:
            typed_delta = delta
            if any(not name.startswith("modules/jttms10/hdl/") or
                   Path(name).suffix != ".v" for name in delta):
                raise ValueError(f"partition update changed non-CPU-RTL inputs: {delta}")
            if cert.get("generated_payload_delta", {}) != {} or \
                    cert.get("generated_payload_manifest_sha256") is not None:
                raise ValueError("HDL-only update unexpectedly claims generated payload changes")
        observed_input_delta, observed_transient_delta, observed_diagnostic_delta = \
            validate_compiled_input_deltas(
                parent_dir, build, typed_delta, generated_delta,
                allow_generated_diagnostic_delta=(mode == "microcode-update"))
        if cert.get("compiled_input_delta") != observed_input_delta:
            raise ValueError("partition update compiled-input delta differs from the seed")
        if cert.get("transient_compiled_input_delta", {}) != observed_transient_delta:
            raise ValueError("partition update transient-input delta differs from the seed")
        if cert.get("non_compile_generated_output_delta", {}) != observed_diagnostic_delta:
            raise ValueError("partition update generated diagnostic delta differs from the seed")
    if cert.get("partition_observations") != extract_partition_observations(build):
        raise ValueError("partition handling observations differ from fresh map/fit/flow reports")
    return cert


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    configure = sub.add_parser("configure")
    configure.add_argument("--qsf", type=Path, required=True)
    configure.add_argument("--mode", choices=("seed", "update", "microcode-update"), required=True)
    configure.add_argument("--metadata", type=Path, required=True)
    query = sub.add_parser("write-query")
    query.add_argument("--mode", choices=("seed", "update", "microcode-update"), required=True)
    query.add_argument("--output", type=Path, required=True)
    verify = sub.add_parser("validate-query")
    verify.add_argument("--mode", choices=("seed", "update", "microcode-update"), required=True)
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
