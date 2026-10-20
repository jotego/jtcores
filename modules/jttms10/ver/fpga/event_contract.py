# SPDX-License-Identifier: GPL-3.0-or-later
"""Independent event-condition expectations; no transport or measured inputs.

The initial contract is the existing early-CEN timing condition applied by the
external scheduler. Its fixed pause is declared by the fixture and checked
against the exact two-event stimulus, never inferred from an FPGA observation.
"""
import importlib.util
from pathlib import Path


_irq_spec = importlib.util.spec_from_file_location('jttms10_irq_contract', Path(__file__).with_name('irq_contract.py'))
_irq_contract = importlib.util.module_from_spec(_irq_spec)
_irq_spec.loader.exec_module(_irq_contract)


def expected_pause(entry):
    contract = entry.get('external_contract')
    if contract is None:
        return 0
    if isinstance(contract, dict) and contract.get('kind') in (
            'scalar_irq', 'scalar_irq_phase', 'scalar_irq_unaligned', 'scalar_nmi'):
        _irq_contract.validate(entry)
        return 0
    if (not isinstance(contract, dict) or set(contract) != {'kind', 'clocks'} or
            contract['kind'] != 'early_cen'):
        raise ValueError('unsupported independent external event contract')
    clocks = contract['clocks']
    if type(clocks) is not int or not 1 <= clocks <= 0xffffffff:
        raise ValueError('early-CEN contract clocks must be positive uint32')
    if entry.get('stimulus', {}).get('pause_clocks', 0):
        raise ValueError('external early-CEN and legacy pauses cannot overlap')
    wanted = [dict(trigger=0, argument=0, control=32),
              dict(trigger=0, argument=clocks, control=0)]
    if entry.get('external_events') != wanted:
        raise ValueError('early-CEN stimulus differs from its independent contract')
    return clocks


def check_followup(entry, observed, lines):
    contract = entry.get('external_contract')
    if isinstance(contract, dict) and contract.get('kind') in (
            'scalar_irq', 'scalar_irq_phase', 'scalar_irq_unaligned', 'scalar_nmi'):
        return _irq_contract.check(entry, observed, lines)
    return [], None
