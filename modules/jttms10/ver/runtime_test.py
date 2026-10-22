"""Tests for lossless architectural-checkpoint transport."""

import os
import shlex
import subprocess
import sys
import tempfile
from pathlib import Path
import unittest

from runtime import runtime_case
from vectors import validate_case


class RuntimeCaseTests(unittest.TestCase):
    def encode(self, st, flags):
        case = {
            "entry": 0x1000,
            "words": [0x1234],
            "checks": [{
                "after": 0x1000,
                "pc": 0x1010,
                "st": st,
                "flags": flags,
            }],
        }
        row = runtime_case(case).splitlines()[1].split()
        return {
            "st_valid": int(row[2]),
            "st": int(row[3], 16),
            "flags_mask": int(row[4], 16),
            "flags_value": int(row[5], 16),
        }

    def test_st_carry_one_flag_carry_zero_remain_distinct(self):
        encoded = self.encode(1 << 30, {"C": 0})
        self.assertEqual(encoded, {
            "st_valid": 1,
            "st": 1 << 30,
            "flags_mask": 1 << 30,
            "flags_value": 0,
        })

    def test_st_carry_zero_flag_carry_one_remain_distinct(self):
        encoded = self.encode(0, {"C": 1})
        self.assertEqual(encoded, {
            "st_valid": 1,
            "st": 0,
            "flags_mask": 1 << 30,
            "flags_value": 1 << 30,
        })

    def test_consistent_full_st_and_flag_checks_are_both_present(self):
        encoded = self.encode(1 << 30, {"C": 1})
        self.assertEqual(encoded, {
            "st_valid": 1,
            "st": 1 << 30,
            "flags_mask": 1 << 30,
            "flags_value": 1 << 30,
        })

    def test_checkpoint_memory_count_has_no_unvalidated_limit(self):
        case = {
            "name": "many_memory_checks",
            "entry": 0x1000,
            "words": [0x1234],
            "checks": [{
                "after": 0x1000,
                "pc": 0x1010,
                "flags": {"Z": 0},
                "mem": [{"addr": i, "size": 1, "value": 0}
                        for i in range(40)],
            }],
        }
        validate_case(case)
        row = runtime_case(case).splitlines()[1].split()
        self.assertEqual(int(row[9]), 40)

    def test_retire_count_has_no_unvalidated_limit(self):
        count = 513
        entry = 0x1000
        case = {
            "name": "many_retire_checks",
            "entry": entry,
            "words": [0x1234] * count,
            "checks": [{
                "after": entry + 16 * i,
                "pc": entry + 16 * (i + 1),
                "flags": {"Z": 0},
            } for i in range(count)],
        }
        validate_case(case)
        rows = runtime_case(case).splitlines()
        self.assertEqual(int(rows[0].split()[1]), count)
        self.assertEqual(len(rows), count + 1)

    def test_validator_rejects_zero_retire_fault_case(self):
        case = {
            "name": "zero_retire_fault",
            "entry": 0x1000,
            "words": [0x0200],
            "checks": [],
            "expect_fault": True,
            "fault_ir": 0x0200,
        }
        with self.assertRaisesRegex(ValueError, "checks"):
            validate_case(case)


class RunnerSelectionTests(unittest.TestCase):
    def run_without_verilator(self, vector_text, *arguments):
        with tempfile.TemporaryDirectory() as temp_name:
            temp = Path(temp_name)
            vectors = temp / "vectors.yaml"
            vectors.write_text(vector_text)
            bin_dir = temp / "bin"
            bin_dir.mkdir()
            marker = temp / "verilator-was-called"
            fake_verilator = bin_dir / "verilator"
            fake_verilator.write_text(
                "#!/bin/sh\n"
                f": > {shlex.quote(str(marker))}\n"
                "exit 99\n"
            )
            fake_verilator.chmod(0o755)
            env = os.environ.copy()
            env["PATH"] = str(bin_dir) + os.pathsep + env.get("PATH", "")
            run_py = Path(__file__).resolve().with_name("run.py")
            result = subprocess.run(
                [sys.executable, str(run_py), "--vectors", str(vectors),
                 *arguments],
                capture_output=True, text=True, env=env, timeout=10,
            )
            return result, marker.exists()

    def test_empty_vector_selection_fails_before_verilator(self):
        result, called = self.run_without_verilator("cases: []\n")
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertIn("no architectural cases selected", result.stderr)
        self.assertFalse(called)

    def test_unknown_case_selection_fails_before_verilator(self):
        vectors = (
            "cases:\n"
            "  - name: one_case\n"
            "    entry: 4096\n"
            "    words: [4660]\n"
            "    checks:\n"
            "      - after: 4096\n"
            "        pc: 4112\n"
            "        flags: {Z: 0}\n"
        )
        result, called = self.run_without_verilator(vectors, "--case", "missing")
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertIn("unknown case missing", result.stderr)
        self.assertFalse(called)

    def test_duplicate_case_names_fail_before_verilator(self):
        case = (
            "  - name: same\n"
            "    entry: 4096\n"
            "    words: [4660]\n"
            "    checks:\n"
            "      - after: 4096\n"
            "        pc: 4112\n"
            "        flags: {Z: 0}\n"
        )
        result, called = self.run_without_verilator("cases:\n" + case + case)
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertIn("duplicate case names", result.stderr)
        self.assertFalse(called)


if __name__ == "__main__":
    unittest.main()
