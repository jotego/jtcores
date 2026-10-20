# SPDX-License-Identifier: GPL-3.0-or-later
"""Wire-schema checks only; contains no CPU result or instruction timing oracle."""


def uint32(value):
    if type(value) is not int or not 0 <= value <= 0xffffffff:
        raise ValueError('external event field is outside uint32 range')
    return value


def validate_event(event):
    if not isinstance(event, dict) or set(event) != {'trigger', 'argument', 'control'}:
        raise ValueError('external event must contain trigger, argument and control')
    trigger, argument, control = (uint32(event[key]) for key in ('trigger', 'argument', 'control'))
    if trigger > 5 or control & ~0x833f or (control & 0x8300 and not control & 16):
        raise ValueError('unknown external trigger/control or missing host strobe')
    if trigger == 2 and argument & 15:
        raise ValueError('unaligned external decode trigger')
    if trigger in (1, 3, 4, 5) and argument == 0:
        raise ValueError('zero external counter/delay trigger')
    return trigger, argument, control
