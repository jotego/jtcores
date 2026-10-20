#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Pure-host checks for the explicit CPU partition assignment/provenance helpers."""

from pathlib import Path
import tempfile
import unittest
import hashlib
import json

import partition_build as partitions


class PartitionAssignments(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.qsf = Path(self.temp.name) / "test_board.qsf"
        self.qsf.write_text("\n".join([
            "set_global_assignment -name PARTITION_NETLIST_TYPE SOURCE -section_id Top",
            "set_global_assignment -name PARTITION_FITTER_PRESERVATION_LEVEL PLACEMENT_AND_ROUTING -section_id Top",
            "set_instance_assignment -name PARTITION_HIERARCHY root_partition -to | -section_id Top",
            "set_global_assignment -name QIP_FILE QSYS_test_board/synthesis/QSYS_test_board.qip",
            ""]))

    def test_seed_settings_create_exact_cpu_partition_and_keep_root(self):
        result = partitions.configure_qsf(self.qsf, "seed")
        text = self.qsf.read_text()
        self.assertEqual(result["cpu_root"], partitions.CPU_ROOT)
        self.assertEqual(text.count("-name PARTITION_HIERARCHY root_partition -to |"), 1)
        self.assertIn("-name INCREMENTAL_COMPILATION FULL_INCREMENTAL_COMPILATION", text)
        self.assertIn(f'-name PARTITION_HIERARCHY {partitions.PARTITION_FILE} -to "{partitions.CPU_ROOT}" -section_id "CPU"', text)
        self.assertEqual(text.count("-name PARTITION_NETLIST_TYPE SOURCE -section_id \"Top\""), 1)
        self.assertEqual(text.count("-name PARTITION_NETLIST_TYPE SOURCE -section_id \"CPU\""), 1)
        self.assertEqual(text.count("-name PARTITION_FITTER_PRESERVATION_LEVEL PLACEMENT_AND_ROUTING -section_id \"CPU\""), 1)

    def test_update_reuses_only_top_postfit_and_keeps_cpu_source(self):
        partitions.configure_qsf(self.qsf, "seed")
        partitions.configure_qsf(self.qsf, "update")
        text = self.qsf.read_text()
        self.assertEqual(text.count("-name PARTITION_NETLIST_TYPE POST_FIT -section_id \"Top\""), 1)
        self.assertEqual(text.count("-name PARTITION_NETLIST_TYPE SOURCE -section_id \"CPU\""), 1)
        self.assertNotIn("-name PARTITION_NETLIST_TYPE POST_FIT -section_id \"CPU\"", text)
        self.assertEqual(text.count(f'-name PARTITION_HIERARCHY {partitions.PARTITION_FILE} -to "{partitions.CPU_ROOT}" -section_id "CPU"'), 1)

    def test_configuration_rejects_missing_or_ambiguous_top_root(self):
        self.qsf.write_text('set_global_assignment -name PARTITION_NETLIST_TYPE SOURCE -section_id Top\n')
        with self.assertRaisesRegex(ValueError, "exactly one Top root"):
            partitions.configure_qsf(self.qsf, "seed")
        self.qsf.write_text("\n".join([
            "set_instance_assignment -name PARTITION_HIERARCHY root_partition -to | -section_id Top",
            "set_instance_assignment -name PARTITION_HIERARCHY root_partition -to | -section_id Top",
        ]))
        with self.assertRaisesRegex(ValueError, "exactly one Top root"):
            partitions.configure_qsf(self.qsf, "seed")

    def test_query_checks_exact_hierarchy_and_mode_netlists(self):
        seed = partitions.query_tcl("seed")
        update = partitions.query_tcl("update")
        self.assertIn('puts "PARTITIONS=$parts"', seed)
        self.assertIn(f"set expected_root {{{partitions.CPU_ROOT}}}", seed)
        self.assertIn("Top {Source File}", seed)
        self.assertIn("CPU {Source File}", seed)
        self.assertIn('if {$part eq "Top" && $root ne "|"}', seed)
        self.assertIn("project_close -dont_export_assignments", seed)
        self.assertIn("Top {Post-Fit}", update)
        self.assertIn("CPU {Source File}", update)
        self.assertIn("INCREMENTAL_COMPILATION", seed)

    def test_installed_tool_query_output_is_checked_fail_closed(self):
        success = "\n".join([
            "PARTITIONS=Top CPU",
            "PARTITION=Top ROOTS=| NETLIST=Source File PRESERVATION=Placement and Routing",
            f"PARTITION=CPU ROOTS={partitions.CPU_ROOT} NETLIST=Source File PRESERVATION=Placement and Routing",
            "INCREMENTAL_COMPILATION=FULL_INCREMENTAL_COMPILATION",
            "Quartus Prime Shell was successful",
        ])
        partitions.validate_query_output(success, "seed")
        with self.assertRaisesRegex(ValueError, "missing expected results"):
            partitions.validate_query_output(success.replace(partitions.CPU_ROOT, "u_cpu"), "seed")
        update = success.replace("NETLIST=Source File PRESERVATION=Placement and Routing\nPARTITION=CPU",
                                "NETLIST=Post-Fit PRESERVATION=Placement and Routing\nPARTITION=CPU", 1)
        partitions.validate_query_output(update, "update")
        with self.assertRaisesRegex(ValueError, "missing expected results"):
            partitions.validate_query_output(success, "update")

    def test_source_hash_normalization_and_non_cpu_update_rejection(self):
        a = Path(self.temp.name) / "work-a"
        b = Path(self.temp.name) / "work-b"
        for root in (a, b):
            (root / "modules/jttms10/hdl").mkdir(parents=True)
            (root / "modules/jttms10/hdl/jttms10.v").write_text("same\n")
        row_a = {"source_root": str(a), "source_hashes": {
            str(a / "modules/jttms10/hdl/jttms10.v"): "abc"}}
        row_b = {"source_root": str(b), "source_hashes": {
            str(b / "modules/jttms10/hdl/jttms10.v"): "abc"}}
        self.assertEqual(partitions.source_hashes_relative(row_a), partitions.source_hashes_relative(row_b))
        with self.assertRaisesRegex(ValueError, "outside source root"):
            partitions.source_hashes_relative({"source_root": str(a), "source_hashes": {"/tmp/nope": "x"}})

    def test_cpu_delta_accepts_only_real_cpu_hdl_changes(self):
        root = Path(self.temp.name) / "repo"
        cpu = str(root / "modules/jttms10/hdl/jttms10.v")
        helper = str(root / "modules/jttms10/ver/fpga/partition_build.py")
        parent = {"source_root": str(root), "source_hashes": {cpu: "cpu-old", helper: "tool"}}
        changed_cpu = {"source_root": str(root), "source_hashes": {cpu: "cpu-new", helper: "tool"}}
        self.assertEqual(partitions.compute_cpu_source_delta(parent, changed_cpu),
                         ["modules/jttms10/hdl/jttms10.v"])
        with self.assertRaisesRegex(ValueError, "actual CPU RTL source change"):
            partitions.compute_cpu_source_delta(parent, parent)
        changed_tool = {"source_root": str(root), "source_hashes": {cpu: "cpu-old", helper: "tool-new"}}
        with self.assertRaisesRegex(ValueError, "outside CPU HDL"):
            partitions.compute_cpu_source_delta(parent, changed_tool)

    @staticmethod
    def _manifest(root):
        files = {}
        for path in root.rglob("*"):
            if path.is_file() and path.name != "v2-build-inputs.json":
                files[str(path)] = hashlib.sha256(path.read_bytes()).hexdigest()
        (root / "v2-build-inputs.json").write_text(json.dumps({"files": files}))

    def test_update_compile_inputs_allow_only_qsf_mode_and_cpu_package(self):
        parent = Path(self.temp.name) / "seed"
        update = Path(self.temp.name) / "update"
        for root in (parent, update):
            (root / "ip/jttms10_fpga_runner").mkdir(parents=True)
            (root / "ip/jttms10_fpga_runner/jttms10.v").write_text("cpu-old\n")
            (root / "ip/jttms10_fpga_runner/jttms10_fpga_runner.v").write_text("runner\n")
            (root / "QSYS_test_board/synthesis").mkdir(parents=True)
            (root / "QSYS_test_board/synthesis/QSYS_test_board.qip").write_text("qip\n")
            (root / "test_board.qsf").write_text("\n".join([
                "set_global_assignment -name DEVICE 5CSEMA5F31C8",
                "set_global_assignment -name PARTITION_NETLIST_TYPE SOURCE -section_id Top",
                "set_global_assignment -name PARTITION_NETLIST_TYPE SOURCE -section_id CPU",
                "set_instance_assignment -name PARTITION_HIERARCHY root_partition -to | -section_id Top",
                f'set_instance_assignment -name PARTITION_HIERARCHY {partitions.PARTITION_FILE} -to "{partitions.CPU_ROOT}" -section_id "CPU"',
                "set_global_assignment -name QIP_FILE QSYS_test_board/synthesis/QSYS_test_board.qip",
                f"set_global_assignment -library QSYS_test_board -name VERILOG_FILE {root}/ip/jttms10_fpga_runner/jttms10.v",
            ]) + "\n")
        (update / "ip/jttms10_fpga_runner/jttms10.v").write_text("cpu-new\n")
        update_qsf = (update / "test_board.qsf")
        update_qsf.write_text(update_qsf.read_text().replace(
            "PARTITION_NETLIST_TYPE SOURCE -section_id Top",
            "PARTITION_NETLIST_TYPE POST_FIT -section_id Top"))
        self._manifest(parent)
        self._manifest(update)
        source_delta = ["modules/jttms10/hdl/jttms10.v"]
        changed = partitions.validate_compiled_input_delta(parent, update, source_delta)
        self.assertEqual(set(changed), {"ip/jttms10_fpga_runner/jttms10.v"})

        (update / "QSYS_test_board/synthesis/QSYS_test_board.qip").write_text("changed\n")
        self._manifest(update)
        with self.assertRaisesRegex(ValueError, "stable compiled inputs"):
            partitions.validate_compiled_input_delta(parent, update, source_delta)

    def _partition_input_pair(self, parent, update, changed_cpu=True):
        for root in (parent, update):
            (root / "ip/jttms10_fpga_runner").mkdir(parents=True)
            (root / "ip/jttms10_fpga_runner/jttms10.v").write_text("cpu-old\n")
            (root / "ip/jttms10_fpga_runner/jttms10_fpga_runner.v").write_text("runner\n")
            (root / "QSYS_test_board/synthesis/submodules").mkdir(parents=True)
            (root / "QSYS_test_board/synthesis/QSYS_test_board.qip").write_text("qip\n")
            (root / "QSYS_test_board/synthesis/submodules/runner.sdc").write_text("sdc\n")
            (root / "ip/jttms10_fpga_runner/memory.v").write_text("ram\n")
            (root / "tms10_gfx.hex").write_text("0123\n")
            (root / "test_board.qsf").write_text("\n".join([
                "set_global_assignment -name DEVICE 5CSEMA5F31C8",
                "set_global_assignment -name PARTITION_NETLIST_TYPE SOURCE -section_id Top",
                "set_global_assignment -name PARTITION_NETLIST_TYPE SOURCE -section_id CPU",
                "set_instance_assignment -name PARTITION_HIERARCHY root_partition -to | -section_id Top",
                f'set_instance_assignment -name PARTITION_HIERARCHY {partitions.PARTITION_FILE} -to "{partitions.CPU_ROOT}" -section_id "CPU"',
                "set_global_assignment -name QIP_FILE QSYS_test_board/synthesis/QSYS_test_board.qip",
                f"set_global_assignment -library QSYS_test_board -name VERILOG_FILE {root}/ip/jttms10_fpga_runner/jttms10.v",
                ""]) + "\n")
        update_qsf = update / "test_board.qsf"
        update_qsf.write_text(update_qsf.read_text().replace(
            "PARTITION_NETLIST_TYPE SOURCE -section_id Top",
            "PARTITION_NETLIST_TYPE POST_FIT -section_id Top"))
        if changed_cpu:
            (update / "ip/jttms10_fpga_runner/jttms10.v").write_text("cpu-new\n")

    def test_dispatch_model_cache_churn_is_recorded_separately(self):
        parent = Path(self.temp.name) / "cache-seed"
        update = Path(self.temp.name) / "cache-update"
        self._partition_input_pair(parent, update)
        for root, content in ((parent, "seed cache\n"), (update, "rebuilt cache\n")):
            model = root / "jttms10-generated/dispatch-model"
            model.mkdir(parents=True)
            for name in partitions.TRANSIENT_DISPATCH_MODEL_OUTPUTS:
                (model / name).write_text(content + name + "\n")
        self._manifest(parent)
        self._manifest(update)

        stable, transient = partitions.validate_compiled_input_deltas(
            parent, update, ["modules/jttms10/hdl/jttms10.v"])
        self.assertEqual(set(stable), {"ip/jttms10_fpga_runner/jttms10.v"})
        self.assertEqual(set(transient), {
            f"jttms10-generated/dispatch-model/{name}"
            for name in partitions.TRANSIENT_DISPATCH_MODEL_OUTPUTS
        })
        for name, hashes in transient.items():
            self.assertEqual(hashes["parent_sha256"], hashlib.sha256(
                (parent / name).read_bytes()).hexdigest())
            self.assertEqual(hashes["candidate_sha256"], hashlib.sha256(
                (update / name).read_bytes()).hexdigest())

    def test_dispatch_model_hdl_and_new_outputs_remain_stable_inputs(self):
        for index, relpath in enumerate((
                "jttms10-generated/dispatch-model/Vtest_new",
                "jttms10-generated/dispatch-model/Vtest_extra.v",
                "jttms10-generated/dispatch-model/nested/Vtest__ALL.o",
                "jttms10-generated/other-model/Vtest__ALL.o")):
            with self.subTest(relpath=relpath):
                parent = Path(self.temp.name) / f"strict-seed-{index}"
                update = Path(self.temp.name) / f"strict-update-{index}"
                self._partition_input_pair(parent, update)
                for root, content in ((parent, "old"), (update, "new")):
                    path = root / relpath
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_text(content + "\n")
                self._manifest(parent)
                self._manifest(update)
                with self.assertRaisesRegex(ValueError, "stable compiled inputs"):
                    partitions.validate_compiled_input_deltas(
                        parent, update, ["modules/jttms10/hdl/jttms10.v"])
                self.addCleanup(lambda p=parent: __import__("shutil").rmtree(p, ignore_errors=True))
                self.addCleanup(lambda p=update: __import__("shutil").rmtree(p, ignore_errors=True))

    def test_dispatch_cache_churn_does_not_replace_required_cpu_package_delta(self):
        parent = Path(self.temp.name) / "no-cpu-seed"
        update = Path(self.temp.name) / "no-cpu-update"
        self._partition_input_pair(parent, update, changed_cpu=False)
        for root, content in ((parent, "seed"), (update, "updated")):
            model = root / "jttms10-generated/dispatch-model"
            model.mkdir(parents=True)
            (model / "Vtest").write_text(content + "\n")
        self._manifest(parent)
        self._manifest(update)
        with self.assertRaisesRegex(ValueError, "did not compile every changed CPU module"):
            partitions.validate_compiled_input_deltas(
                parent, update, ["modules/jttms10/hdl/jttms10.v"])

    def test_update_rejects_qip_sdc_ram_rom_and_device_changes(self):
        changes = (
            ("QSYS_test_board/synthesis/QSYS_test_board.qip", "new qip\n"),
            ("QSYS_test_board/synthesis/submodules/runner.sdc", "new sdc\n"),
            ("ip/jttms10_fpga_runner/memory.v", "new ram\n"),
            ("tms10_gfx.hex", "abcd\n"),
        )
        for index, (relpath, content) in enumerate(changes):
            with self.subTest(relpath=relpath):
                parent = Path(self.temp.name) / f"input-seed-{index}"
                update = Path(self.temp.name) / f"input-update-{index}"
                self._partition_input_pair(parent, update)
                (update / relpath).write_text(content)
                self._manifest(parent)
                self._manifest(update)
                with self.assertRaisesRegex(ValueError, "stable compiled inputs"):
                    partitions.validate_compiled_input_deltas(
                        parent, update, ["modules/jttms10/hdl/jttms10.v"])
                self.addCleanup(lambda p=parent: __import__("shutil").rmtree(p, ignore_errors=True))
                self.addCleanup(lambda p=update: __import__("shutil").rmtree(p, ignore_errors=True))

        parent = Path(self.temp.name) / "device-seed"
        update = Path(self.temp.name) / "device-update"
        self._partition_input_pair(parent, update)
        qsf = update / "test_board.qsf"
        qsf.write_text(qsf.read_text().replace("5CSEMA5F31C8", "5CSEMA5F31C6"))
        self._manifest(parent)
        self._manifest(update)
        with self.assertRaisesRegex(ValueError, "outside the partition configuration"):
            partitions.validate_compiled_input_deltas(
                parent, update, ["modules/jttms10/hdl/jttms10.v"])

    def test_update_compile_inputs_reject_qsf_drift_outside_partition_assignments(self):
        parent = Path(self.temp.name) / "seed-qsf"
        update = Path(self.temp.name) / "update-qsf"
        for root in (parent, update):
            root.mkdir()
            (root / "test_board.qsf").write_text("set_global_assignment -name DEVICE 5CSEMA5F31C8\n")
        (update / "test_board.qsf").write_text(
            "set_global_assignment -name DEVICE 5CSEMA5F31C6\n"
            "set_global_assignment -name PARTITION_NETLIST_TYPE POST_FIT -section_id Top\n")
        for root in (parent, update):
            self._manifest(root)
        with self.assertRaisesRegex(ValueError, "outside the partition configuration"):
            partitions.validate_compiled_input_delta(parent, update, ["modules/jttms10/hdl/jttms10.v"])


if __name__ == "__main__":
    unittest.main()
