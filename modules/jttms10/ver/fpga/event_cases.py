# SPDX-License-Identifier: GPL-3.0-or-later
"""External-condition fixtures layered on the unchanged independent ISA cases."""


def specifications():
    def event(trigger, argument, control):
        return dict(trigger=trigger, argument=argument, control=control)

    rows = [
        dict(base='nop_hit', label='empty', events=[]),
        dict(base='nop_off', label='empty', events=[]),
        dict(base='nop_hit', label='lint_host', events=[event(0, 0, 1), event(0, 1, 0),
             event(0, 2, 16), event(5, 1, 0)]),
        dict(base='nop_hit', label='host_nmim', events=[event(0, 0, 0x210),
             event(5, 1, 16), event(5, 2, 0)]),
        dict(base='nop_hit', label='relative_delay', events=[event(0, 0, 2), event(3, 3, 0)]),
        dict(base='nop_off', label='all_16', events=[event(0, q, 2 if q % 2 == 0 else 0)
             for q in range(16)]),
    ]
    # HOLD grants the external bus; it need not freeze a cached instruction.
    # Release after three acknowledged clocks, before the off-cache next fetch.
    for base in ('nop_hit', 'nop_off'):
        rows.append(dict(base=base, label='hold_ack3', events=[event(0, 0, 4), event(4, 3, 0)]))
    for waits in (0, 1, 3):
        rows.append(dict(base='blit_ll_ps4_n4_rows2_hit', label=f'write_trigger_w{waits}',
            events=[event(1, 1, 1), event(3, 1, 0)], wait_states=waits))
        rows.append(dict(base='store_move_indirect_w1_o0_f0_r0_2_0_q32_dependency0_hit',
            label=f'follow_decode_w{waits}', events=[event(2, 'follow_pc', 2), event(3, 1, 0)],
            wait_states=waits))
    for base in ('nop_hit', 'add_off', 'load_move_f0_w32_o15_s1_off',
                 'blit_ll_ps4_n4_rows2_hit'):
        for clocks in (1, 7, 8):
            for waits in (0, 1):
                rows.append(dict(base=base, label=f'early_cen{clocks}_w{waits}',
                    events=[event(0, 0, 32), event(0, clocks, 0)],
                    contract=dict(kind='early_cen', clocks=clocks), wait_states=waits))
    return rows
