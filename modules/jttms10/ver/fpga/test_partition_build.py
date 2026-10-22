#!/usr/bin/env python3
"""Host-only tests for strict CPU partition source and payload transitions."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import partition_build


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_manifest(root: Path, changes: dict[str, bytes] | None = None) -> dict:
    changes = changes or {}
    rows = {
        "modules/jttms10/hdl/jttms10.v": b"rtl-a",
        "modules/jttms10/ucode/tms10.yaml": b"yaml-a",
        "modules/jttms10/ucode/gfx.yaml": b"yaml-gfx",
        "modules/jtframe/src/jtframe/ucode/main.go": b"generator",
    }
    rows.update({name: content for name, content in changes.items() if name not in rows})
    for relative, content in rows.items():
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(changes.get(relative, content))
    return {
        "source_root": str(root.resolve()),
        "source_hashes": {str((root / name).resolve()): digest(root / name) for name in rows},
    }


def payload_manifest(build: Path, changed: bool = False) -> None:
    names = partition_build.GENERATED_CPU_PAYLOADS
    payloads = {}
    copies = {}
    for name in sorted(names):
        content = ("changed-" if changed and name == "tms10.uc" else "stable-").encode() + name.encode()
        payloads[name] = hashlib.sha256(content).hexdigest()
        for relative in (name, f"jttms10-generated/{name}", f"ip/jttms10_fpga_runner/{name}"):
            path = build / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)
            copies[relative] = digest(path)
    (build / "v2-generated-payloads.json").write_text(json.dumps({
        "format": partition_build.GENERATED_PAYLOAD_FORMAT,
        "generator_sha256": "frozen-generator",
        "payloads": payloads,
        "copies": copies,
    }))


class PartitionBuildTests(unittest.TestCase):
    def test_compile_snapshot_binds_manifest_not_last_diagnostic(self) -> None:
        helper = HERE / "build-runner-incremental.sh"
        with tempfile.TemporaryDirectory(prefix="jttms10-compile-snapshot-") as temporary:
            build = Path(temporary)
            input_file = build / "input.v"
            diagnostic = build / "jttms10-generated/dispatch-model/Vtest.mk"
            input_file.write_text("compiled source\n")
            diagnostic.parent.mkdir(parents=True)
            diagnostic.write_text("diagnostic output\n")
            manifest_path = build / "v2-build-inputs.json"
            manifest_path.write_text(json.dumps({
                "files": {str(input_file): digest(input_file)},
                "non_compile_generated_outputs": {
                    "jttms10-generated/dispatch-model/Vtest.mk": digest(diagnostic),
                },
            }))

            result = subprocess.run(
                ["bash", "-c", 'source "$1"; build_dir="$2"; capture_compile_inputs',
                 "test", str(helper), str(build)],
                text=True, capture_output=True, check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            snapshot = json.loads((build / "v2-compile-inputs.json").read_text())
            self.assertEqual(snapshot["map_manifest_sha256"], digest(manifest_path))
            self.assertNotEqual(snapshot["map_manifest_sha256"], digest(diagnostic))
            self.assertEqual(snapshot["files"], {str(input_file): digest(input_file)})

            diagnostic.write_text("changed diagnostic output\n")
            rejected = subprocess.run(
                ["bash", "-c", 'source "$1"; build_dir="$2"; capture_compile_inputs',
                 "test", str(helper), str(build)],
                text=True, capture_output=True, check=False,
            )
            self.assertNotEqual(rejected.returncode, 0)
            self.assertIn("generated diagnostic output changed after map", rejected.stderr)

    def test_cpu_package_name_accepts_top_and_rejects_unrelated_verilog(self) -> None:
        self.assertTrue(partition_build._is_cpu_source_filename("jttms10.v"))
        self.assertTrue(partition_build._is_cpu_source_filename("jttms10_cache.v"))
        self.assertFalse(partition_build._is_cpu_source_filename("bus_timer.v"))
        self.assertFalse(partition_build._is_cpu_source_filename("jttms10.yaml"))

    def test_prepare_clears_inherited_seed_only_audit(self) -> None:
        with tempfile.TemporaryDirectory(prefix="jttms10-stage-cleanup-") as temporary:
            build = Path(temporary)
            audit = build / "v2-partition-seed-package-reconstruction.json"
            audit.write_text('{"format":"inherited-seed-audit"}\n')
            partition_build.clear_inherited_seed_package_audit(build)
            self.assertFalse(audit.exists())
            with self.assertRaisesRegex(ValueError, "lacks its package reconstruction audit"):
                partition_build.seed_package_reconstruction_binding(build, "seed")
            self.assertIsNone(partition_build.seed_package_reconstruction_binding(
                build, "microcode-update"))
            audit.write_text('{"format":"stale-seed-audit"}\n')
            with self.assertRaisesRegex(ValueError, "inherited a seed-only"):
                partition_build.seed_package_reconstruction_binding(build, "microcode-update")

    def test_transient_dispatch_build_log_is_exact_path_only(self) -> None:
        self.assertTrue(partition_build.is_non_compile_generated_output(
            "jttms10-generated/dispatch-model/build.log"))
        self.assertTrue(partition_build.is_non_compile_generated_output(
            "jttms10-generated/dispatch-build.log"))
        self.assertTrue(partition_build.is_non_compile_generated_output(
            "jttms10-generated/tms10.lst"))
        self.assertTrue(partition_build.is_non_compile_generated_output(
            "jttms10-generated/tms10_gfx.lst"))
        self.assertFalse(partition_build.is_non_compile_generated_output("build.log"))
        self.assertFalse(partition_build.is_non_compile_generated_output(
            "jttms10-generated/dispatch-model/other.log"))

    def test_real_parent_seed_reconstruction_without_quartus(self) -> None:
        parent = Path("/tmp/jtcores-144-line-boolean-native-full-1").resolve()
        source = Path("/tmp/jtcores-149-seed-source").resolve()
        if not parent.is_dir() or not source.is_dir():
            self.skipTest("reviewed parent/candidate snapshots are unavailable")
        with tempfile.TemporaryDirectory(prefix="jttms10-seed-preflight-") as temporary:
            candidate = Path(temporary) / "candidate"
            candidate.mkdir()
            shutil.copytree(parent / "ip/jttms10_fpga_runner",
                            candidate / "ip/jttms10_fpga_runner")
            for relative in (
                "QSYS_test_board/synthesis/QSYS_test_board.qip",
                "QSYS_test_board.tcl", "QSYS_test_board.qsys", "runner_clock.sdc",
            ):
                destination = candidate / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(parent / relative, destination)
            qsf = (parent / "test_board.qsf").read_text().replace(str(parent), str(candidate))
            (candidate / "test_board.qsf").write_text(qsf)

            audit = partition_build.reconstruct_seed_cpu_package(parent, candidate, source)
            (candidate / "v2-partition-seed-package-reconstruction.json").write_text(
                json.dumps(audit, indent=2, sort_keys=True) + "\n")
            checked = partition_build.validate_seed_package_reconstruction(candidate, parent, source)
            self.assertEqual(audit, checked)
            self.assertEqual(
                [row["path"] for row in audit["removed_stale_cpu_modules"]],
                ["jttms10_bus_timer.v"],
            )
            self.assertEqual(audit["infrastructure_sha256_before_after"].keys(), {
                "QSYS_test_board/synthesis/QSYS_test_board.qip", "QSYS_test_board.tcl",
                "QSYS_test_board.qsys", "runner_clock.sdc",
            })

    def test_seed_rejects_stale_module_reference_in_preserved_qip(self) -> None:
        with tempfile.TemporaryDirectory(prefix="jttms10-seed-refusal-") as temporary:
            root = Path(temporary)
            parent, candidate, source = root / "parent", root / "candidate", root / "source"
            self._synthetic_seed_trees(parent, candidate, source)
            for tree in (parent, candidate):
                with (tree / "QSYS_test_board/synthesis/QSYS_test_board.qip").open("a") as stream:
                    stream.write("# jttms10_bus_timer.v\n")
            with self.assertRaisesRegex(ValueError, "referenced by preserved infrastructure"):
                partition_build.reconstruct_seed_cpu_package(parent, candidate, source)

    def test_microcode_yaml_delta_is_typed_and_scoped(self) -> None:
        with tempfile.TemporaryDirectory(prefix="jttms10-source-delta-") as temporary:
            root = Path(temporary)
            before_root, after_root = root / "before", root / "after"
            before = source_manifest(before_root)
            after = source_manifest(after_root, {"modules/jttms10/ucode/tms10.yaml": b"yaml-b"})
            delta = partition_build.compute_cpu_microcode_source_delta(before, after)
            self.assertEqual(delta, ["modules/jttms10/ucode/tms10.yaml"])
            with self.assertRaisesRegex(ValueError, "outside CPU HDL"):
                partition_build.compute_cpu_source_delta(before, after)
            bad = source_manifest(root / "bad", {"modules/jttms10/ucode/unreviewed.yaml": b"yaml-c"})
            with self.assertRaisesRegex(ValueError, "outside CPU HDL/allowlisted YAML"):
                partition_build.compute_cpu_microcode_source_delta(before, bad)
            with self.assertRaisesRegex(ValueError, "requires an explicit CPU microcode YAML"):
                partition_build.compute_cpu_microcode_source_delta(
                    before,
                    source_manifest(root / "rtl-only", {"modules/jttms10/hdl/jttms10.v": b"rtl-b"}),
                )

    def test_microcode_mode_keeps_top_postfit_and_cpu_source(self) -> None:
        with tempfile.TemporaryDirectory(prefix="jttms10-partition-settings-") as temporary:
            qsf = Path(temporary) / "test_board.qsf"
            qsf.write_text("set_global_assignment -name PARTITION_HIERARCHY root_partition -to | -section_id Top\n")
            metadata = partition_build.configure_qsf(qsf, "microcode-update")
            self.assertEqual(metadata["top_netlist"], "POST_FIT")
            self.assertEqual(metadata["cpu_netlist"], "SOURCE")
            query = partition_build.query_tcl("microcode-update")
            self.assertIn("Top {Post-Fit}", query)
            self.assertIn("CPU {Source File}", query)

    def test_real_source_generator_has_fixed_payload_inventory(self) -> None:
        source = Path("/tmp/jtcores-149-seed-source").resolve()
        if not source.is_dir():
            self.skipTest("frozen #149 source snapshot is unavailable")
        regenerated = partition_build.regenerate_cpu_payload_hashes(source)
        self.assertEqual(set(regenerated), partition_build.GENERATED_CPU_PAYLOADS)

    def test_payload_delta_requires_exact_names_and_all_copies(self) -> None:
        with tempfile.TemporaryDirectory(prefix="jttms10-payload-delta-") as temporary:
            root = Path(temporary)
            parent, child = root / "parent", root / "child"
            parent.mkdir(); child.mkdir()
            payload_manifest(parent)
            payload_manifest(child, changed=True)
            self.assertEqual(set(partition_build.generated_payload_delta(parent, child)), {"tms10.uc"})
            tampered = child / "ip/jttms10_fpga_runner/tms10.uc"
            tampered.write_text("wrong")
            with self.assertRaisesRegex(ValueError, "copy mismatch"):
                partition_build.generated_payload_delta(parent, child)

    def test_payload_delta_rejects_unknown_generated_output(self) -> None:
        with tempfile.TemporaryDirectory(prefix="jttms10-payload-inventory-") as temporary:
            root = Path(temporary)
            parent, child = root / "parent", root / "child"
            parent.mkdir(); child.mkdir()
            payload_manifest(parent)
            payload_manifest(child, changed=True)
            manifest_path = child / "v2-generated-payloads.json"
            manifest = json.loads(manifest_path.read_text())
            manifest["payloads"]["unreviewed.hex"] = "0" * 64
            manifest_path.write_text(json.dumps(manifest))
            with self.assertRaisesRegex(ValueError, "audited CPU payload inventory"):
                partition_build.generated_payload_delta(parent, child)

    def test_compiled_input_delta_rejects_qip_and_sdc_change(self) -> None:
        for blocked in ("test_board.qip", "runner_clock.sdc"):
            with self.subTest(blocked=blocked), tempfile.TemporaryDirectory(
                    prefix="jttms10-input-delta-") as temporary:
                root = Path(temporary)
                parent, child = root / "parent", root / "child"
                parent.mkdir(); child.mkdir()
                (parent / "test_board.qsf").write_text(self._qsf("Source File"))
                (child / "test_board.qsf").write_text(self._qsf("Post-Fit"))
                (parent / blocked).write_text("stable")
                (child / blocked).write_text("changed")
                for tree in (parent, child):
                    files = {str(p.resolve()): digest(p) for p in tree.iterdir() if p.is_file()}
                    (tree / "v2-build-inputs.json").write_text(json.dumps({"files": files}))
                with self.assertRaisesRegex(ValueError, "stable compiled inputs"):
                    partition_build.validate_compiled_input_deltas(parent, child, [
                        "modules/jttms10/ucode/tms10.yaml",
                    ], {"tms10.uc": {"parent_sha256": "a", "candidate_sha256": "b"}})

    def test_compiled_input_delta_accepts_only_generated_cpu_payload_copies(self) -> None:
        with tempfile.TemporaryDirectory(prefix="jttms10-input-positive-") as temporary:
            root = Path(temporary)
            parent, child = root / "parent", root / "child"
            parent.mkdir(); child.mkdir()
            (parent / "test_board.qsf").write_text(self._qsf("Source File"))
            (child / "test_board.qsf").write_text(self._qsf("Post-Fit"))
            payload_manifest(parent)
            payload_manifest(child, changed=True)
            for tree in (parent, child):
                files = {str(path.resolve()): digest(path)
                         for path in tree.rglob("*") if path.is_file()
                         and path.name not in {"v2-build-inputs.json",
                                                "v2-generated-payloads.json"}}
                (tree / "v2-build-inputs.json").write_text(json.dumps({"files": files}))
            payload_delta = partition_build.generated_payload_delta(parent, child)
            stable, transient, diagnostics = partition_build.validate_compiled_input_deltas(
                parent, child, ["modules/jttms10/ucode/tms10.yaml"], payload_delta)
            self.assertEqual(set(stable), {
                "tms10.uc", "jttms10-generated/tms10.uc",
                "ip/jttms10_fpga_runner/tms10.uc",
            })
            self.assertEqual(transient, {})
            self.assertEqual(diagnostics, {})

    def test_real_candidate4_cpu_yaml_generation_and_compiled_delta(self) -> None:
        before_source = Path("/tmp/jtcores-149-seed-source").resolve()
        after_source = Path(
            "/nobackup/tasks/jtcores-149/artifacts/stageb-sharedshift-candidate4/source"
        ).resolve()
        if not before_source.is_dir() or not after_source.is_dir():
            self.skipTest("reviewed baseline/candidate4 source snapshots are unavailable")

        before_generated = partition_build.regenerate_cpu_generation_inventory(before_source)
        after_generated = partition_build.regenerate_cpu_generation_inventory(after_source)
        self.assertEqual(set(before_generated["payloads"]), partition_build.GENERATED_CPU_PAYLOADS)
        self.assertEqual(set(after_generated["payloads"]), partition_build.GENERATED_CPU_PAYLOADS)
        self.assertEqual(len(before_generated["diagnostics"]), 28)
        self.assertEqual(set(before_generated["diagnostics"]), set(after_generated["diagnostics"]))
        self.assertNotEqual(
            before_generated["diagnostics"]["jttms10-generated/tms10.lst"],
            after_generated["diagnostics"]["jttms10-generated/tms10.lst"],
        )
        self.assertNotEqual(
            before_generated["diagnostics"]["jttms10-generated/dispatch-build.log"],
            after_generated["diagnostics"]["jttms10-generated/dispatch-build.log"],
        )
        self.assertIn("jttms10-generated/tms10_gfx.lst", before_generated["diagnostics"])
        self.assertEqual(
            before_generated["diagnostics"]["jttms10-generated/tms10_gfx.lst"],
            after_generated["diagnostics"]["jttms10-generated/tms10_gfx.lst"],
        )
        self.assertNotEqual(
            before_generated["payloads"]["tms10_dispatch.hex"],
            after_generated["payloads"]["tms10_dispatch.hex"],
        )
        self.assertNotEqual(
            (before_source / "modules/jttms10/hdl/tms10_dispatch.hex").read_bytes(),
            (after_source / "modules/jttms10/hdl/tms10_dispatch.hex").read_bytes(),
        )

        source_paths = [
            *before_source.glob("modules/jttms10/hdl/*"),
            *before_source.glob("modules/jttms10/ucode/*.yaml"),
        ]
        source_paths = [path for path in source_paths if path.is_file()]
        candidate_paths = [after_source / path.relative_to(before_source) for path in source_paths]
        before_manifest = {
            "source_root": str(before_source),
            "source_hashes": {str(path): digest(path) for path in source_paths},
        }
        after_manifest = {
            "source_root": str(after_source),
            "source_hashes": {str(path): digest(path) for path in candidate_paths},
        }
        source_delta = partition_build.compute_cpu_microcode_source_delta(
            before_manifest, after_manifest)
        self.assertEqual(source_delta, [
            "modules/jttms10/hdl/jttms10.v",
            "modules/jttms10/hdl/jttms10_ctrl.v",
            "modules/jttms10/hdl/tms10_dispatch.hex",
            "modules/jttms10/ucode/control.yaml",
        ])
        self.assertIn("modules/jttms10/hdl/tms10_dispatch.hex", source_delta)
        self.assertTrue(any(name.endswith(".yaml") for name in source_delta))
        partition_build.validate_dispatch_rom_source(
            before_source, {"payloads": before_generated["payloads"]})
        partition_build.validate_dispatch_rom_source(
            after_source, {"payloads": after_generated["payloads"]})
        with tempfile.TemporaryDirectory(prefix="jttms10-rom-source-guard-") as temporary:
            wrong_source = Path(temporary) / "modules/jttms10/hdl/tms10_dispatch.hex"
            wrong_source.parent.mkdir(parents=True)
            wrong_source.write_text("0000\n")
            with self.assertRaisesRegex(ValueError, "differs from the independently generated"):
                partition_build.validate_dispatch_rom_source(
                    wrong_source.parents[3], {"payloads": after_generated["payloads"]})

        with tempfile.TemporaryDirectory(prefix="jttms10-real-delta-") as temporary:
            root = Path(temporary)
            before_build, after_build = root / "before", root / "after"
            before_build_inventory = self._materialize_generated_build(
                before_build, before_source, before_generated, "Source File",
                legacy_diagnostics=True)
            after_build_inventory = self._materialize_generated_build(
                after_build, after_source, after_generated, "Post-Fit",
                legacy_diagnostics=False)
            payload_delta = {
                name: {"parent_sha256": before_build_inventory["payloads"][name],
                       "candidate_sha256": after_build_inventory["payloads"][name]}
                for name in partition_build.GENERATED_CPU_PAYLOADS
                if before_build_inventory["payloads"][name] != after_build_inventory["payloads"][name]
            }
            stable, transient, diagnostic_delta = partition_build.validate_compiled_input_deltas(
                before_build, after_build, source_delta, payload_delta,
                allow_generated_diagnostic_delta=True)
            expected_payload_inputs = {
                path for name in payload_delta
                for path in (name, f"jttms10-generated/{name}",
                             f"ip/jttms10_fpga_runner/{name}")
            }
            expected_hdl_inputs = {
                f"ip/jttms10_fpga_runner/{Path(name).name}"
                for name in source_delta
                if name.startswith("modules/jttms10/hdl/") and name.endswith(".v")
            }
            self.assertEqual(set(stable), expected_payload_inputs | expected_hdl_inputs)
            self.assertEqual(transient, {})
            self.assertIn("jttms10-generated/tms10.lst", diagnostic_delta)
            self.assertIn("jttms10-generated/dispatch-build.log", diagnostic_delta)
            self.assertTrue(any(
                name.startswith("jttms10-generated/dispatch-model/")
                for name in diagnostic_delta
            ))
            self.assertNotIn("jttms10-generated/tms10_gfx.lst", diagnostic_delta)

            tampered = json.loads((after_build / "v2-build-inputs.json").read_text())
            tampered["non_compile_generated_outputs"]["jttms10-generated/unreviewed.log"] = "0" * 64
            (after_build / "v2-build-inputs.json").write_text(json.dumps(tampered))
            with self.assertRaisesRegex(ValueError, "unclassified non-compile generated output"):
                partition_build.validate_compiled_input_deltas(
                    before_build, after_build, source_delta, payload_delta,
                    allow_generated_diagnostic_delta=True)

    def _materialize_generated_build(self, build: Path, source: Path, inventory: dict,
                                     cpu_netlist: str, *, legacy_diagnostics: bool) -> dict:
        generated = build / "jttms10-generated"
        generated.mkdir(parents=True)
        command = ["bash", str(source / "modules/jttms10/ver/build.sh"), str(generated)]
        import subprocess
        result = subprocess.run(command, cwd=source, capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        actual = partition_build.cpu_generated_output_inventory(generated)
        self.assertEqual(actual["payloads"], inventory["payloads"])
        for relative in ("test_board.qip", "runner_clock.sdc"):
            (build / relative).write_text("preserved infrastructure\n")
        qsf = build / "test_board.qsf"
        qsf.write_text(self._qsf(cpu_netlist))
        cpu_package = build / "ip/jttms10_fpga_runner"
        cpu_package.mkdir(parents=True)
        for source_hdl in (source / "modules/jttms10/hdl").glob("*.v"):
            shutil.copy2(source_hdl, cpu_package / source_hdl.name)
        copies = {}
        for name, expected_hash in inventory["payloads"].items():
            source_payload = generated / name
            self.assertEqual(digest(source_payload), expected_hash)
            for relative in (name, f"ip/jttms10_fpga_runner/{name}"):
                target = build / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source_payload, target)
                copies[relative] = digest(target)
            copies[f"jttms10-generated/{name}"] = digest(source_payload)
        (build / "v2-generated-payloads.json").write_text(json.dumps({
            "format": partition_build.GENERATED_PAYLOAD_FORMAT,
            "generator_sha256": digest(source / "modules/jttms10/ver/build.sh"),
            "payloads": inventory["payloads"],
            "copies": copies,
        }))
        files = {str(path.resolve()): digest(path)
                 for path in build.rglob("*") if path.is_file()
                 and path.name not in {"v2-build-inputs.json", "v2-generated-payloads.json"}}
        diagnostics = actual["diagnostics"]
        if legacy_diagnostics:
            # Old full manifests kept generated listings/logs in `files`; the
            # validator must still classify them as diagnostics by exact path.
            for relative, expected_hash in diagnostics.items():
                path = build / relative
                self.assertEqual(digest(path), expected_hash)
                files[str(path.resolve())] = expected_hash
            diagnostics_field = {}
        else:
            files = {path: value for path, value in files.items()
                     if not partition_build.is_non_compile_generated_output(
                         Path(path).relative_to(build).as_posix())}
            diagnostics_field = diagnostics
        manifest = {"source_root": str(source), "files": files,
                    "non_compile_generated_outputs": diagnostics_field}
        (build / "v2-build-inputs.json").write_text(json.dumps(manifest))
        return actual

    @staticmethod
    def _qsf(top: str) -> str:
        return "\n".join((
            "set_global_assignment -name PARTITION_HIERARCHY root_partition -to | -section_id Top",
            f"set_global_assignment -name PARTITION_NETLIST_TYPE {top} -section_id Top",
            'set_global_assignment -library "QSYS_test_board" -name VERILOG_FILE $BUILD_DIR/ip/jttms10_fpga_runner/jttms10.v',
        )) + "\n"

    def _synthetic_seed_trees(self, parent: Path, candidate: Path, source: Path) -> None:
        stale = "jttms10_bus_timer.v"
        for tree in (parent, candidate):
            package = tree / "ip/jttms10_fpga_runner"
            package.mkdir(parents=True)
            (package / stale).write_text("module jttms10_bus_timer; endmodule\n")
            (package / "jttms10.v").write_text("module jttms10; endmodule\n")
            for relative in (
                "QSYS_test_board/synthesis/QSYS_test_board.qip",
                "QSYS_test_board.tcl", "QSYS_test_board.qsys", "runner_clock.sdc",
            ):
                path = tree / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("stable infrastructure\n")
        (parent / "ip/jttms10_fpga_runner/jttms10_fpga_runner_hw.tcl").write_text("component")
        (candidate / "ip/jttms10_fpga_runner/jttms10_fpga_runner_hw.tcl").write_text("component")
        source_hdl = source / "modules/jttms10/hdl"
        source_hdl.mkdir(parents=True)
        (source_hdl / "jttms10.v").write_text("module jttms10; endmodule\n")
        fpga = source / "modules/jttms10/ver/fpga"
        fpga.mkdir(parents=True)
        source_component = fpga / "ip/jttms10_fpga_runner"
        source_component.mkdir(parents=True)
        (source_component / "jttms10_fpga_runner_hw.tcl").write_text("component")
        for name in partition_build.RUNNER_SOURCES:
            source_file = fpga / name
            source_file.write_text(f"module {name.removesuffix('.v')}; endmodule\n")
            for tree in (parent, candidate):
                shutil.copy2(source_file, tree / "ip/jttms10_fpga_runner" / name)
        for tree in (parent, candidate):
            package = tree / "ip/jttms10_fpga_runner"
            qsf_lines = [
                "set_global_assignment -name PARTITION_HIERARCHY root_partition -to | -section_id Top",
            ]
            qsf_lines.extend(
                f"set_global_assignment -library QSYS_test_board -name VERILOG_FILE {package/name}"
                for name in ("jttms10.v", stale, *partition_build.RUNNER_SOURCES)
            )
            (tree / "test_board.qsf").write_text("\n".join(qsf_lines) + "\n")


if __name__ == "__main__":
    unittest.main(verbosity=2)
