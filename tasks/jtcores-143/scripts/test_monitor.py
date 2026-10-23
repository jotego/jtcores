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

class PanPrograms(unittest.TestCase):
    def test_primary_pan_bits_and_other_registers(self):
        both=monitor.make_table('tone')
        for name,want in [('tone-left',0x47),('tone-right',0x87),('tone',0xc7)]:
            with self.subTest(name=name):
                data=bytearray(monitor.make_table(name))
                self.assertEqual(data[-1],0)
                self.assertEqual((len(data)-1)%3,0)
                positions=[]
                for index in range(0,len(data)-1,3):
                    self.assertEqual(data[index],1)
                    if data[index+1]==0x20: positions.append(index+2)
                self.assertEqual(data[positions[-1]],want)
                data[positions[-1]]=0xc7
                self.assertEqual(bytes(data),both)

if __name__=='__main__': unittest.main()
