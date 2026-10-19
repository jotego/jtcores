#!/usr/bin/env python3
"""Run the unchanged timing oracle through synthesizable observation ports.

The temporary bench keeps the existing stimulus, but replaces register peeks
with a scoreboard fed only by the exposed register write transactions. Its
additional assertions cross-check that scoreboard against the simulation RAM.
Pass timing/run.py arguments through, e.g. --simulator verilator --case addk.
This verifies observation wiring; it is not the synthesizable batch controller.
"""
from pathlib import Path
import re
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
TIMING = HERE.parent / 'timing'


def bench_source():
    source = (TIMING / 'test.sv').read_text()
    # Use only public observer signals for register snapshots and bus/decode logs.
    source = re.sub(r'dut\.u_cpu\.u_core\.u_regs\.ram0\[([^\]]+)\]',
                    r'observer_regs[\1]', source)
    replacements = {
        'dut.u_cpu.u_core.step && dut.u_cpu.u_core.ld_ir': 'dut.obs_decode',
        'dut.u_fabric.u_bus.g_timing.u_timer.start': 'dut.obs_bus_start',
        'dut.u_fabric.u_bus.complete': 'dut.obs_bus_complete',
        'dut.u_fabric.u_bus.cycle_rdata': 'dut.obs_bus_rdata',
        'dut.u_cpu.u_core.fetch ? pc : pc-32\'d16': 'dut.obs_decode_pc',
        'dut.u_cpu.u_core.fetch ?\n                           dut.u_cpu.u_core.read_data[15:0] : dut.u_cpu.u_core.md[15:0]':
            'dut.obs_decode_ir',
    }
    for before, after in replacements.items():
        if before not in source:
            raise RuntimeError(f'timing bench changed: missing {before!r}')
        source = source.replace(before, after)
    marker = '    reg [15:0] mem[0:4095];'
    if source.count(marker) != 1:
        raise RuntimeError('timing bench changed: cannot locate memory declaration')
    scoreboard = '''
    reg [31:0] observer_regs[0:63];
    reg [63:0] observer_valid=0;
    always @(posedge clk) begin
        if(rst) observer_valid<=0;
        else begin
            for(integer q=0;q<64;q=q+1)
                if(observer_valid[q] && observer_regs[q]!==dut.u_cpu.u_core.u_regs.ram0[q])
                    $fatal(1,"observer register mismatch at physical register %0d",q);
            if(dut.obs_rf_we) begin
                observer_regs[dut.obs_rf_addr]<=dut.obs_rf_data;
                observer_valid[dut.obs_rf_addr]<=1;
            end
            if(dut.obs_work!=={dut.u_cpu.u_core.u_ctrl.uaddr,
                dut.u_cpu.u_core.active,dut.u_cpu.u_core.a,dut.u_cpu.u_core.b,
                dut.u_cpu.u_core.md,dut.u_cpu.u_core.tmp,dut.u_cpu.u_core.mul_count,
                dut.u_cpu.u_core.multi_mask,dut.u_cpu.u_core.multi_index,dut.u_cpu.u_core.multi_steps})
                $fatal(1,"observer working-state mismatch");
            if(dut.obs_field_pending_fault!==(!dut.u_cpu.field_req &&
                (dut.u_cpu.field_word_req || dut.u_cpu.field_word_lock) && !dut.word_pending))
                $fatal(1,"observer pending-field mismatch");
        end
    end
'''
    # Unconnected public outputs are intentionally read hierarchically by this bench.
    return ('`define JTTMS10_REGRESSION\n'
            '/* verilator lint_off PINMISSING */\n' + source.replace(marker, scoreboard + marker))


def main():
    if any(arg == '--bench' or arg.startswith('--bench=') for arg in sys.argv[1:]):
        raise SystemExit('check_observer.py supplies its own --bench')
    with tempfile.TemporaryDirectory(prefix='jttms10-observer-') as temporary:
        bench = Path(temporary) / 'test.sv'
        bench.write_text(bench_source())
        return subprocess.call([sys.executable, str(TIMING / 'run.py'),
                                '--bench', str(bench), *sys.argv[1:]])


if __name__ == '__main__':
    sys.exit(main())
