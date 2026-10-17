"""Rearm preconditions must reject uncertain CPU state before touching USB."""
import tempfile
from pathlib import Path
import unittest
from unittest.mock import patch, MagicMock
import monitor

class RearmGuards(unittest.TestCase):
    def test_uncertain_monitor_state(self):
        for state in [
            {'booted':False,'pending':False},
            {'booted':True,'pending':True},
            {'booted':True,'pending':False,'reply_partial':'d0'},
        ]:
            with self.subTest(state=state), tempfile.TemporaryDirectory() as folder:
                output=Path(folder)/'rearm.json'
                with patch.object(monitor,'load_state',return_value=state):
                    with self.assertRaises(AssertionError):
                        # None is deliberate: any USB access before rejection fails.
                        monitor.rearm(None,output)
                self.assertFalse(output.exists())

    def test_unqualified_rom_parameters(self):
        for parameters in [
            {'rom_enable':'0','addr_mask':'0xffff'},
            {'rom_enable':'1','addr_mask':'0x7fff'},
            {'rom_enable':'1','addr_mask':'invalid'},
        ]:
            with self.subTest(parameters=parameters), tempfile.TemporaryDirectory() as folder:
                output=Path(folder)/'rearm.json'
                pico=MagicMock()
                pico.read.return_value=bytes([32,223])
                pico.get.side_effect=parameters.__getitem__
                with patch.object(monitor,'load_state',return_value={'booted':True,'pending':False,'generation':32}):
                    with self.assertRaises((AssertionError,ValueError)):
                        monitor.rearm(pico,output)
                pico.end.assert_not_called()
                pico.start.assert_not_called()
                pico.poll.assert_not_called()
                self.assertFalse(output.with_suffix('.window.bin').exists())

if __name__=='__main__': unittest.main()
