#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Event conditions must declare expectations before execution, and fail closed."""
import copy
import importlib.util
from pathlib import Path
import tempfile
import unittest

from event_contract import expected_pause


class EventContract(unittest.TestCase):
    def entry(self):
        return dict(external_contract=dict(kind='early_cen', clocks=7),
                    external_events=[dict(trigger=0, argument=0, control=32),
                                     dict(trigger=0, argument=7, control=0)])

    def test_declared_pause_has_no_measured_input(self):
        entry = self.entry()
        self.assertEqual(expected_pause(entry), 7)
        entry['observed'] = dict(clocks=999, paused=999)
        self.assertEqual(expected_pause(entry), 7)

    def test_changed_or_unknown_stimulus_does_not_redefine_expected_time(self):
        for trigger, argument, control in ((0, 6, 0), (3, 7, 0), (0, 7, 1), (0, 7, 32)):
            entry = self.entry()
            entry['external_events'][1] = dict(trigger=trigger, argument=argument, control=control)
            with self.assertRaisesRegex(ValueError, 'differs from its independent contract'):
                expected_pause(entry)
        entry = self.entry()
        entry['external_contract']['clocks'] = 6
        with self.assertRaises(ValueError):
            expected_pause(entry)

    def test_unknown_contract_and_overlapping_pause_fail_closed(self):
        for contract in (dict(kind='irq', clocks=7), dict(kind='early_cen', clocks=7, waive=True),
                         [], dict(kind='early_cen', clocks=True), dict(kind='early_cen', clocks=0)):
            entry = self.entry()
            entry['external_contract'] = copy.deepcopy(contract)
            with self.assertRaises(ValueError):
                expected_pause(entry)
        entry = self.entry()
        entry['stimulus'] = dict(pause_clocks=7)
        with self.assertRaisesRegex(ValueError, 'cannot overlap'):
            expected_pause(entry)

    def test_no_contract_adds_no_expected_delay(self):
        entry = self.entry()
        del entry['external_contract']
        self.assertEqual(expected_pause(entry), 0)

    def test_checker_loads_expectations_from_selected_source(self):
        # The bundled transport must not supply or cache an oracle belonging
        # to a different checkout. Only pure wire validation is shared.
        here = Path(__file__).resolve().parent
        with tempfile.TemporaryDirectory(prefix='jttms10-selected-event-contract-') as temp:
            selected = Path(temp)
            (selected/'check_results.py').write_bytes((here/'check_results.py').read_bytes())
            (selected/'event_contract.py').write_text('def expected_pause(entry):\n    return entry["selected_value"]\n')
            spec = importlib.util.spec_from_file_location('selected_checker_test', selected/'check_results.py')
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            self.assertEqual(module.expected_external_pause(dict(selected_value=123)), 123)
        self.assertEqual(expected_pause({}), 0)


if __name__ == '__main__':
    unittest.main()
