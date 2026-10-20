#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Prepare FPGA batches and check observations using the independent timing suite.

This module performs no SSH, device access or FPGA programming. Protocol v5
adds actual context-completion and retirement clocks to v4 external events.
Unsupported fixture requirements fail explicitly rather than losing checks.
"""
import argparse
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
from stimulus_schema import validate_event as validate_external_event

HERE = Path(__file__).resolve().parent
TIMING = HERE.parent / 'timing'
# A copied transport may select another source checkout. Load its independent
# event expectations by source path, without relying on the driver's sys.path.
_event_spec = importlib.util.spec_from_file_location('jttms10_event_contract', HERE/'event_contract.py')
_event_contract = importlib.util.module_from_spec(_event_spec)
_event_spec.loader.exec_module(_event_contract)
expected_external_pause = _event_contract.expected_pause
MAX_CASES = 32
MAX_WORDS = 4096
RESULT_WORDS = 202
FORMAT_V1 = 'jttms10-fpga-batch-v1'
FORMAT = 'jttms10-fpga-batch-v2'
FORMAT_V3 = 'jttms10-fpga-batch-v3'
FORMAT_V4 = 'jttms10-fpga-batch-v4'
FORMAT_V5 = 'jttms10-fpga-batch-v5'
FORMATS = {1: FORMAT_V1, 2: FORMAT, 3: FORMAT_V3, 4: FORMAT_V4, 5: FORMAT_V5}
RESULT_SIZES = {1: 72, 2: RESULT_WORDS, 3: 288, 4: 288, 5: 292}
EVENT_LIMITS = {1: (128, 4096), 2: (512, 16384), 3: (512, 16384), 4: (512, 16384), 5: (512, 16384)}
MASK32 = (1 << 32) - 1
# Explicit fixture-family selection, not a verdict allowlist. Every selected
# fixture still passes require_supported and every existing oracle assertion.
READ_ONLY_TERMS = ['mpys_', 'mpyu_', 'nop_hit', 'nop_off', 'nop_next_subsegment_miss_',
                   'add_hit', 'add_off', 'movk_hit', 'movk_off', 'sla_', 'sll_', 'sra_',
                   'srl_', 'rl_', 'lmo_', 'scalar_', 'divs_', 'divu_', 'mods_', 'modu_',
                   'immediate_', 'xy_addxy_', 'xy_subxy_', 'xy_cmpxy_',
                   'coordinate_cpw_', 'coordinate_cvxyl_', 'emu_run_']

_store_dependency_checker = None
_byte_store_event_modules = None

BYTE_STORE_EVENT_NAME_PREFIXES = (
    'store_movb_absolute_cd_follow_', 'copy_movb_cd_follow_',
    'store_movb_absolute_cd_hold_', 'copy_movb_cd_hold_',
)


def is_store_dependency(case):
    name = case.get('name', '')
    return 'dependency_conditions' in case or (isinstance(name, str) and 'cd_dependency_' in name)


def is_byte_store_event(case):
    name = case.get('name', '')
    return 'byte_store_event' in case or (
        isinstance(name, str) and name.startswith(BYTE_STORE_EVENT_NAME_PREFIXES))


def instruction_duration_required(case, entry):
    """Apply only explicitly validated family-specific duration policies."""
    if is_store_dependency(case):
        validate_store_dependency(case, 5)
        return False
    if is_byte_store_event(case):
        return validate_byte_store_event(case, 5)['kind'] == 'following'
    return _event_contract.check_duration(entry)


def validate_store_dependency(case, protocol_version):
    """Validate the complete CD dependency contract before any scoped policy."""
    if protocol_version != 5:
        raise ValueError(f"{case['name']}: CD dependency fixtures require FPGA protocol 5")
    conditions = case.get('dependency_conditions')
    required = {'destination', 'preceding_word', 'offset', 'next_opcode_modified'}
    if not isinstance(conditions, dict) or set(conditions) != required:
        raise ValueError(f"{case['name']}: malformed dependency_conditions keys")
    destination = conditions['destination']
    offset = conditions['offset']
    preceding = conditions['preceding_word']
    modified = conditions['next_opcode_modified']
    if type(destination) is not int or not 0 <= destination <= MASK32:
        raise ValueError(f"{case['name']}: invalid dependency destination")
    if type(offset) is not int or not 0 <= offset < 16 or (destination & 15) != offset:
        raise ValueError(f"{case['name']}: invalid dependency byte offset")
    if type(preceding) is not bool or type(modified) is not bool:
        raise ValueError(f"{case['name']}: dependency flags must be booleans")
    if not isinstance(case.get('name'), str) or 'cd_dependency_' not in case['name']:
        raise ValueError(f"{case['name']}: dependency metadata on an unrelated fixture")
    if case.get('measure_pass') != 0 or type(case.get('measure_pass')) is not int:
        raise ValueError(f"{case['name']}: dependency fixture must measure first pass")
    if case.get('drain_instructions') != -2 or type(case.get('drain_instructions')) is not int:
        raise ValueError(f"{case['name']}: dependency fixture requires posted-write drain")
    if case.get('cache_disabled') is not True:
        raise ValueError(f"{case['name']}: dependency fixture requires cache-disabled operation")
    if 'data_copy' in case:
        spec = case['data_copy']
        if not isinstance(spec, dict) or spec.get('width') != 8 or type(spec.get('width')) is not int:
            raise ValueError(f"{case['name']}: dependency copy must be one byte")
        if spec.get('byte') is not True:
            raise ValueError(f"{case['name']}: dependency copy must use byte mode")
        actual_destination = spec.get('destination')
        store_spec = case.get('data_store')
        if (not isinstance(store_spec, dict) or store_spec.get('width') != 8 or
                store_spec.get('address') != actual_destination):
            raise ValueError(f"{case['name']}: dependency copy/store descriptions disagree")
    elif 'data_store' in case:
        spec = case['data_store']
        if not isinstance(spec, dict) or spec.get('width') != 8 or type(spec.get('width')) is not int:
            raise ValueError(f"{case['name']}: dependency store must be one byte")
        actual_destination = spec.get('address')
    else:
        raise ValueError(f"{case['name']}: dependency fixture has no byte-store operation")
    if type(actual_destination) is not int or actual_destination != destination:
        raise ValueError(f"{case['name']}: dependency destination disagrees with operation")
    next_pc = case.get('next_pc')
    if type(next_pc) is not int or not 0 <= next_pc <= MASK32:
        raise ValueError(f"{case['name']}: invalid dependency next PC")
    expected_destination = u32(next_pc - 16 * int(preceding) + offset)
    if destination != expected_destination:
        raise ValueError(f"{case['name']}: dependency destination disagrees with next-PC geometry")
    expected_modified = any(((destination + bit) & ~15) == next_pc for bit in range(8))
    if modified != expected_modified:
        raise ValueError(f"{case['name']}: dependency next-opcode flag disagrees with geometry")
    if 'expected_memory' not in case or 'initial_memory' not in case:
        raise ValueError(f"{case['name']}: dependency fixture needs complete sparse memory")


def validate_byte_store_event(case, protocol_version):
    """Validate the byte-event fixture before applying its scoped HOLD rule."""
    name = case.get('name', '<unnamed>')
    if protocol_version != 5:
        raise ValueError(f'{name}: byte-store events require FPGA protocol 5')
    spec = case.get('byte_store_event')
    if not isinstance(spec, dict):
        raise ValueError(f'{name}: missing or malformed byte_store_event metadata')
    kind = spec.get('kind')
    if kind == 'following':
        if set(spec) != {'kind', 'delay'}:
            raise ValueError(f'{name}: following byte_store_event keys must be kind and delay')
        delay = spec['delay']
        if type(delay) is not int or delay not in (0, 3):
            raise ValueError(f'{name}: following byte-store delay must be 0 or 3')
        expected_prefixes = ('store_movb_absolute_cd_follow_', 'copy_movb_cd_follow_')
        if not isinstance(name, str) or not name.startswith(expected_prefixes):
            raise ValueError(f'{name}: following metadata is attached to the wrong fixture family')
        expected_drain = delay + 1
        if case.get('drain_instructions') != expected_drain or type(case.get('drain_instructions')) is not int:
            raise ValueError(f'{name}: following byte-store drain does not match its delay')
        if case.get('follow_delay') is not None or case.get('control_follow') is not None:
            raise ValueError(f'{name}: use byte_store_event metadata, not the generic follow contract')
        if not isinstance(case.get('following_words'), list) or len(case['following_words']) != delay + 5:
            raise ValueError(f'{name}: following byte-store program words are malformed')
        if any(type(word) is not int or not 0 <= word <= 0xffff for word in case['following_words']):
            raise ValueError(f'{name}: following byte-store words must be uint16 values')
        expected_follow_pc = case.get('next_pc')
        if type(expected_follow_pc) is not int or not 0 <= expected_follow_pc <= MASK32:
            raise ValueError(f'{name}: following byte-store fixture has invalid next PC')
        expected_follow_pc += 16 * (delay + 1)
        if case.get('follow_pc') != expected_follow_pc:
            raise ValueError(f'{name}: following byte-store PC does not match delay geometry')
        if (not isinstance(case.get('expected_follow_regs'), list) or
                not isinstance(case.get('expected_follow_extra_regs'), dict) or
                type(case.get('expected_follow_st')) is not int):
            raise ValueError(f'{name}: following byte-store fixture lacks full load-state expectations')
        opcode = 0x8e00 | (1 << 5) | (2 if name.startswith('copy_') else 1)
        wanted_words = [0x0300] * delay + [opcode] + [0x0300] * 4
        if case['following_words'] != wanted_words:
            raise ValueError(f'{name}: dependent-load words do not match the declared delay')
        if case.get('expected_next_opcode') != (opcode if delay == 0 else 0x0300):
            raise ValueError(f'{name}: accepted opcode does not match dependent-load placement')
    elif kind == 'hold':
        if set(spec) != {'kind'}:
            raise ValueError(f'{name}: HOLD byte_store_event must contain only kind')
        if not isinstance(name, str) or not name.startswith((
                'store_movb_absolute_cd_hold_', 'copy_movb_cd_hold_')):
            raise ValueError(f'{name}: HOLD metadata is attached to the wrong fixture family')
        if case.get('drain_instructions') != -2 or type(case.get('drain_instructions')) is not int:
            raise ValueError(f'{name}: HOLD byte-store fixture requires posted-write drain -2')
        if any(key in case for key in ('follow_pc', 'following_words', 'expected_follow_regs',
                                       'expected_follow_extra_regs', 'expected_follow_st')):
            raise ValueError(f'{name}: HOLD byte-store fixture cannot declare a following-load snapshot')
        if case.get('expected_next_opcode') != 0x0300:
            raise ValueError(f'{name}: HOLD byte-store fixture must retain the following NOP')
    else:
        raise ValueError(f'{name}: unknown byte_store_event kind')

    if case.get('measure_pass') != 0 or type(case.get('measure_pass')) is not int:
        raise ValueError(f'{name}: byte-store event must measure the first pass')
    if case.get('cache_disabled') is not True:
        raise ValueError(f'{name}: byte-store event must use cache-disabled operation')
    store = case.get('data_store')
    if not isinstance(store, dict) or store.get('width') != 8 or type(store.get('width')) is not int:
        raise ValueError(f'{name}: byte-store event needs a byte store operation')
    destination = store.get('address')
    if type(destination) is not int or not 0 <= destination <= MASK32:
        raise ValueError(f'{name}: invalid byte-store destination')
    if 'data_copy' in case:
        copy_spec = case['data_copy']
        if (not isinstance(copy_spec, dict) or copy_spec.get('width') != 8 or
                type(copy_spec.get('width')) is not int or copy_spec.get('byte') is not True or
                copy_spec.get('destination') != destination):
            raise ValueError(f'{name}: byte-copy and store destinations disagree')
        if not name.startswith('copy_movb_cd_'):
            raise ValueError(f'{name}: copy operation has the wrong byte-event family name')
    elif not name.startswith('store_movb_absolute_cd_'):
        raise ValueError(f'{name}: store operation has the wrong byte-event family name')
    offset = destination & 15
    allowed = (0, 8, 9, 15) if kind == 'following' else ((0, 8) if 'data_copy' in case else (0, 15))
    if offset not in allowed:
        raise ValueError(f'{name}: byte-store offset is outside the selected event inventory')
    if not isinstance(case.get('initial_memory'), list) or not isinstance(case.get('expected_memory'), list):
        raise ValueError(f'{name}: byte-store event needs complete sparse memory expectations')
    cases_module, _ = byte_store_event_modules()
    canonical_cases = (cases_module.following_cases() if kind == 'following'
                       else cases_module.hold_cases())
    canonical = next((fixture for fixture, _ in canonical_cases if fixture.get('name') == name), None)
    if canonical is None or json.dumps(case, sort_keys=True) != json.dumps(canonical, sort_keys=True):
        raise ValueError(f'{name}: fixture differs from the selected byte-store event inventory')
    return spec


def validate_byte_store_event_entry(entry, protocol_version):
    """Validate stimulus metadata separately from the CPU fixture contract."""
    case = entry['fixture']
    spec = validate_byte_store_event(case, protocol_version)
    cases_module, _ = byte_store_event_modules()
    canonical_cases = (cases_module.following_cases() if spec['kind'] == 'following'
                       else cases_module.hold_cases())
    canonical = next(((fixture, words) for fixture, words in canonical_cases
                      if fixture.get('name') == case.get('name')), None)
    if canonical is None:
        raise ValueError(f"{case['name']}: missing canonical byte-store event program")
    canonical_fixture, canonical_words = canonical
    if (entry.get('program_words') != canonical_words or
            entry.get('test_pc') != canonical_fixture.get('test_pc') or
            entry.get('next_pc') != canonical_fixture.get('next_pc')):
        raise ValueError(f"{case['name']}: program or measurement interval differs from canonical fixture")
    profile = entry.get('byte_store_event_profile')
    settings = stimulus_for(entry)
    if spec['kind'] == 'following':
        if profile != {'kind': 'following'} or entry.get('external_events', []) != []:
            raise ValueError(f"{case['name']}: following event must not schedule external events")
        if (settings['wait_states'], settings['pause_clocks'], settings['pause_after_clocks']) not in (
                (0, 0, 0), (1, 0, 0), (3, 0, 0), (1, 1, 0), (1, 7, 0)):
            raise ValueError(f"{case['name']}: unsupported following event profile")
    else:
        if (not isinstance(profile, dict) or set(profile) != {'kind', 'hold_phase'} or
                profile.get('kind') != 'hold'):
            raise ValueError(f"{case['name']}: malformed HOLD event profile")
        phase = profile['hold_phase']
        if type(phase) is not int or phase not in (0, 8, 24, 40, 52):
            raise ValueError(f"{case['name']}: invalid HOLD event phase")
        if (settings['wait_states'] not in (0, 1) or settings['pause_clocks'] or
                settings['pause_after_clocks']):
            raise ValueError(f"{case['name']}: unsupported HOLD wait/pause profile")
        wanted = [dict(trigger=0, argument=phase, control=4),
                  dict(trigger=4, argument=3, control=0)]
        if entry.get('external_events') != wanted:
            raise ValueError(f"{case['name']}: HOLD scheduler events differ from grant/release contract")
    return spec


def store_dependency_checker():
    """Load the independent checker from the selected source checkout."""
    global _store_dependency_checker
    if _store_dependency_checker is not None:
        return _store_dependency_checker
    oracle = oracle_module()
    dependency_dir = HERE.parent / 'store_dependency'
    if not (dependency_dir / 'check.py').is_file():
        raise ValueError('CD dependency metadata requires store_dependency/check.py')
    # The independent check module imports its own fixture module and the
    # selected checkout's timing.run helpers. Bind those imports explicitly.
    for path in (TIMING, dependency_dir):
        if str(path) in sys.path:
            sys.path.remove(str(path))
        sys.path.insert(0, str(path))
    prior_run = sys.modules.get('run')
    prior_cases = sys.modules.get('cases')
    sys.modules['run'] = oracle
    try:
        cases_spec = importlib.util.spec_from_file_location(
            'jttms10_store_dependency_cases', dependency_dir / 'cases.py')
        cases_module = importlib.util.module_from_spec(cases_spec)
        cases_spec.loader.exec_module(cases_module)
        sys.modules['cases'] = cases_module
        check_spec = importlib.util.spec_from_file_location(
            'jttms10_store_dependency_check', dependency_dir / 'check.py')
        check_module = importlib.util.module_from_spec(check_spec)
        check_spec.loader.exec_module(check_module)
    finally:
        if prior_run is None:
            sys.modules.pop('run', None)
        else:
            sys.modules['run'] = prior_run
        if prior_cases is None:
            sys.modules.pop('cases', None)
        else:
            sys.modules['cases'] = prior_cases
    _store_dependency_checker = check_module
    return check_module


def byte_store_event_modules():
    """Load the selected checkout's event fixtures and shared oracle by path."""
    global _byte_store_event_modules
    if _byte_store_event_modules is not None:
        return _byte_store_event_modules
    dependency_dir = HERE.parent / 'store_dependency'
    # Clear every importable module stem in the selected source directories,
    # including timing models added after this loader was written.  A fixed
    # list can accidentally retain an ambient module from another checkout.
    timing_names = {path.stem for path in TIMING.glob('*.py')}
    timing_names.update(path.stem for path in dependency_dir.glob('*.py'))
    timing_names.update(('run', 'cases', 'oracle'))
    saved_modules = {}
    for name, module in list(sys.modules.items()):
        filename = getattr(module, '__file__', None)
        if name in timing_names or filename:
            try:
                source_path = Path(filename).resolve() if filename else None
                if name in timing_names or source_path is not None and (
                        TIMING in source_path.parents or dependency_dir in source_path.parents):
                    saved_modules[name] = module
                    sys.modules.pop(name, None)
            except (OSError, TypeError):
                if name in timing_names:
                    saved_modules[name] = module
                    sys.modules.pop(name, None)
    saved_path = list(sys.path)
    try:
        for path in (TIMING, dependency_dir):
            if str(path) in sys.path:
                sys.path.remove(str(path))
        sys.path[:0] = [str(dependency_dir), str(TIMING)]
        oracle = oracle_module()
        sys.modules['run'] = oracle
        cases_spec = importlib.util.spec_from_file_location(
            'jttms10_byte_store_event_cases', dependency_dir / 'byte_events_cases.py')
        cases_module = importlib.util.module_from_spec(cases_spec)
        cases_spec.loader.exec_module(cases_module)
        event_spec = importlib.util.spec_from_file_location(
            'jttms10_byte_store_event_oracle', TIMING / 'byte_store_event_oracle.py')
        event_module = importlib.util.module_from_spec(event_spec)
        event_spec.loader.exec_module(event_module)
        _byte_store_event_modules = (cases_module, event_module)
    finally:
        sys.path[:] = saved_path
        for name, module in list(sys.modules.items()):
            filename = getattr(module, '__file__', None)
            try:
                source_path = Path(filename).resolve() if filename else None
                if source_path is not None and (TIMING in source_path.parents or
                                                dependency_dir in source_path.parents):
                    sys.modules.pop(name, None)
            except (OSError, TypeError):
                pass
        sys.modules.update(saved_modules)
    return _byte_store_event_modules


def oracle_module():
    # The fixture generator and all expectations remain owned by timing/run.py.
    if str(TIMING) not in sys.path:
        sys.path.insert(0, str(TIMING))
    spec = importlib.util.spec_from_file_location('jttms10_timing_oracle', TIMING / 'run.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def require_supported(case, protocol_version=1):
    # Fail closed when fixtures gain a new observation or stimulus requirement.
    # A blacklist would silently discard checks added to the software backend.
    supported = {'name', 'opcode', 'regs', 'expected_regs', 'expected_st', 'states',
                 'cache_disabled', 'cache_miss', 'extensions', 'expected_extra_regs',
                 'expected_masks', 'initial_b_regs', 'initial_sp', 'observe_implicit',
                 'instruction_word_offset', 'measure_pass', 'miss_word', 'setup_io',
                 'instruction_alignment_words',
                 'pc_result_register', 'test_pc', 'next_pc', 'citation', 'conditions',
                 'coverage_id', 'source_conflict_kind', 'source_notes',
                 'source_result_register', 'source_values', 'timing_source_status'}
    if protocol_version in (2, 3, 4, 5):
        supported |= {'initial_memory', 'expected_memory', 'data_load', 'stack_load', 'pixel_load',
                      'stack_fields', 'data_list', 'hidden_states', 'initial_all_regs',
                      'observe_all', 'register_overrides', 'seed', 'source_register',
                      'source_value', 'bank', 'control', 'status_holder',
                      'expected_next_opcode', 'stack_control_flow', 'literal_return_pc',
                      'control_flow', 'drain_instructions'}
        if protocol_version >= 3:
            supported |= {
                'data_store', 'data_copy', 'tail_instructions', 'follow_delay',
                'following_words', 'expected_follow_regs', 'expected_follow_st',
                'expected_follow_extra_regs', 'expected_follow_memory', 'follow_pc',
                'control_follow', 'list_follow', 'memory_before_measured',
                'literal_model_memory', 'literal_citation', 'literal_source_notes',
                'target_opcode', 'next_opcode_miss', 'call_flow', 'trap_flow',
                'data_trap', 'following_bank', 'pixel_store', 'follow_opcode',
                'pixel_processing', 'pixel_copy', 'pixel_xy_store', 'pixel_draw',
                'pixel_xy_copy', 'data_fill', 'fill_timing', 'transparent_history',
                'data_line', 'line_timing', 'expected_st_mask', 'expected_wvp',
                'data_blit', 'blit_timing',
            }
            drain = case.get('drain_instructions', 0)
            if type(drain) is not int or not -2 <= drain <= 0x7fffffff:
                raise ValueError(f"{case['name']}: invalid FPGA drain mode")
            follow_pc = u32(case.get('follow_pc', 0))
            if follow_pc & 15:
                raise ValueError(f"{case['name']}: unaligned FPGA following PC")
            if ('expected_follow_regs' in case or 'expected_follow_extra_regs' in case) and not any(
                    key in case for key in ('control_follow', 'follow_delay', 'list_follow')) and not is_byte_store_event(case):
                raise ValueError(f"{case['name']}: unhandled following-register expectation")
        if is_store_dependency(case):
            supported.add('dependency_conditions')
            validate_store_dependency(case, protocol_version)
        if is_byte_store_event(case):
            supported.add('byte_store_event')
            validate_byte_store_event(case, protocol_version)
        if protocol_version < 3 and case.get('drain_instructions', 0) not in (0, -1):
            raise ValueError(f"{case['name']}: unsupported FPGA drain/follow requirement")
        if protocol_version == 2 and 'data_list' in case and not case['data_list']['load']:
            raise ValueError(f"{case['name']}: unsupported FPGA memory write")
        if (protocol_version == 2 and 'expected_memory' in case and not
                ('data_list' in case or case.get('stack_load') or case.get('pixel_load'))):
            raise ValueError(f"{case['name']}: unsupported FPGA memory expectation")
        if protocol_version >= 3 and 'expected_memory' in case and not any(
                key in case for key in ('data_store', 'data_list', 'stack_load', 'pixel_load', 'data_fill', 'data_line', 'data_blit')):
            raise ValueError(f"{case['name']}: unhandled FPGA memory expectation")
    elif protocol_version != 1:
        raise ValueError('unsupported FPGA protocol version')
    found = sorted(set(case) - supported)
    if found:
        raise ValueError(f"{case['name']}: unsupported FPGA fixture requirements: {', '.join(found)}")


def prepare_store_dependency_cases(protocol_version, stimulus=None):
    """Prepare only the explicit cache-disabled CD dependency inventory."""
    if protocol_version != 5:
        raise ValueError('--store-dependency requires --protocol-version 5')
    dependency_dir = HERE.parent / 'store_dependency'
    if str(TIMING) in sys.path:
        sys.path.remove(str(TIMING))
    if str(dependency_dir) in sys.path:
        sys.path.remove(str(dependency_dir))
    sys.path[:0] = [str(dependency_dir), str(TIMING)]
    oracle = oracle_module()
    prior_run = sys.modules.get('run')
    sys.modules['run'] = oracle
    try:
        spec = importlib.util.spec_from_file_location(
            'jttms10_store_dependency_cases_prepare', dependency_dir / 'cases.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
    finally:
        if prior_run is None:
            sys.modules.pop('run', None)
        else:
            sys.modules['run'] = prior_run
    prepared = list(module.cases())
    if len(prepared) != 16:
        raise ValueError(f'CD dependency inventory changed: expected 16 cases, got {len(prepared)}')
    entries = []
    names = set()
    for identifier, (fixture, words) in enumerate(prepared):
        name = fixture['name']
        if name in names:
            raise ValueError(f'duplicate CD dependency fixture name: {name}')
        names.add(name)
        require_supported(fixture, protocol_version)
        test_pc, next_pc = fixture['test_pc'], fixture['next_pc']
        entry = dict(id=identifier, name=name, fixture=fixture,
                     program_words=words, test_pc=test_pc, next_pc=next_pc)
        if stimulus:
            entry['stimulus'] = dict(stimulus)
        entries.append(entry)
    return entries


def prepare_byte_store_event_cases(kind, protocol_version, stimulus=None, hold_phase=0):
    """Prepare a complete, narrowly selected protocol-v5 byte-event inventory."""
    if protocol_version != 5:
        raise ValueError('--byte-store-events requires --protocol-version 5')
    if kind not in ('following', 'hold'):
        raise ValueError('byte-store event kind must be following or hold')
    stimulus = dict(stimulus or {})
    allowed_stimulus = {'wait_states', 'pause_clocks', 'pause_after_clocks'}
    if set(stimulus) - allowed_stimulus:
        raise ValueError('unknown byte-store event profile setting')
    wait = stimulus.get('wait_states', 0)
    pause = stimulus.get('pause_clocks', 0)
    pause_after = stimulus.get('pause_after_clocks', 0)
    if any(type(value) is not int or value < 0 for value in (wait, pause, pause_after)):
        raise ValueError('byte-store event profile values must be nonnegative integers')
    if kind == 'following':
        if (wait, pause, pause_after) not in ((0, 0, 0), (1, 0, 0), (3, 0, 0),
                                             (1, 1, 0), (1, 7, 0)):
            raise ValueError('unsupported following byte-store profile')
        if hold_phase != 0:
            raise ValueError('--hold-phase is only valid for HOLD byte-store events')
    else:
        if wait not in (0, 1) or pause != 0 or pause_after != 0:
            raise ValueError('HOLD byte-store events support wait 0/1 and no CEN pause')
        if type(hold_phase) is not int or hold_phase not in (0, 8, 24, 40, 52):
            raise ValueError('unsupported HOLD phase')

    cases_module, _ = byte_store_event_modules()
    prepared = list(cases_module.following_cases() if kind == 'following'
                    else cases_module.hold_cases())
    expected_count = 16 if kind == 'following' else 4
    if len(prepared) != expected_count:
        raise ValueError(f'byte-store {kind} inventory changed: expected {expected_count}, got {len(prepared)}')
    entries, names = [], set()
    for identifier, (fixture, words) in enumerate(prepared):
        name = fixture.get('name')
        if name in names:
            raise ValueError(f'duplicate byte-store event fixture name: {name}')
        names.add(name)
        fixture = copy.deepcopy(fixture)
        require_supported(fixture, protocol_version)
        entry = dict(id=identifier, name=name, fixture=fixture, program_words=words,
                     test_pc=fixture['test_pc'], next_pc=fixture['next_pc'],
                     stimulus=dict(wait_states=wait, pause_clocks=pause,
                                   pause_after_clocks=pause_after), external_events=[])
        if kind == 'hold':
            entry['external_events'] = [dict(trigger=0, argument=hold_phase, control=4),
                                        dict(trigger=4, argument=3, control=0)]
            entry['byte_store_event_profile'] = dict(kind=kind, hold_phase=hold_phase)
        else:
            entry['byte_store_event_profile'] = dict(kind=kind)
        external_event_words(entry, protocol_version)
        entries.append(entry)
    return entries


def prepare_cases(terms, limit=None, protocol_version=2, stimulus=None,
                  read_only_matrix=False, audit=None, published_targets=False):
    if not terms and not read_only_matrix and not published_targets:
        raise ValueError('select cases explicitly with at least one --case')
    oracle = oracle_module()
    entries = []
    inventory_hash, selected_hash = hashlib.sha256(), hashlib.sha256()
    if audit is not None:
        audit.update(inventory_count=0, excluded_count=0, exclusions={}, complete_inventory=True)
    for original in oracle.cases():
        if audit is not None:
            audit['inventory_count'] += 1
        inventory_hash.update((original['name']+'\n').encode())
        if published_targets:
            original = oracle.published_duration_case(original)
            if original is None:
                continue
        explicit = any(term in original['name'] for term in terms)
        if not explicit and not read_only_matrix and not (published_targets and not terms):
            continue
        try:
            require_supported(original, protocol_version)
        except ValueError as error:
            if explicit or not read_only_matrix:
                raise
            if audit is not None:
                reason = str(error).split(': ', 1)[-1]
                group = audit['exclusions'].setdefault(reason, dict(count=0, examples=[]))
                group['count'] += 1
                audit['excluded_count'] += 1
                if len(group['examples']) < 3:
                    group['examples'].append(original['name'])
            continue
        case = copy.deepcopy(original)
        words, test_pc, next_pc = oracle.program(case)
        if not 0 < len(words) <= 3840:
            raise ValueError(f"{case['name']}: program does not fit the FPGA target")
        if not (0 <= test_pc <= MASK32 and 0 <= next_pc <= MASK32
                and not (test_pc | next_pc) & 15):
            raise ValueError(f"{case['name']}: unsupported program measurement interval")
        case.update(test_pc=test_pc, next_pc=next_pc)
        # The original runner derives this after program(), not in the builder.
        if 'follow_delay' in case:
            case['follow_pc'] = next_pc + 16 * (case['follow_delay'] + 1)
        require_supported(case, protocol_version)
        entry = dict(id=len(entries), name=case['name'], fixture=case,
                     program_words=words, test_pc=test_pc, next_pc=next_pc)
        if stimulus:
            entry['stimulus'] = dict(stimulus)
        entries.append(entry)
        selected_hash.update((entry['name']+'\n').encode())
        if limit is not None and len(entries) >= limit:
            if audit is not None:
                audit['complete_inventory'] = False
            break
    if not entries:
        raise ValueError('no matching timing fixtures')
    if audit is not None:
        audit.update(selected_count=len(entries), inventory_names_sha256=inventory_hash.hexdigest(),
                     selected_names_sha256=selected_hash.hexdigest())
    return entries


def stimulus_for(entry):
    settings = entry.get('stimulus', {})
    if set(settings) - {'wait_states', 'pause_clocks', 'pause_after_clocks'}:
        raise ValueError('unknown FPGA stimulus setting')
    result = {key: u32(settings.get(key, 0))
              for key in ('wait_states', 'pause_clocks', 'pause_after_clocks')}
    if result['wait_states'] > 0x1fffffff:
        raise ValueError('FPGA wait latency exceeds its 32-bit counter')
    return result


def initial_words(case):
    memory = case.get('initial_memory', [])
    if not isinstance(memory, list) or len(memory) > 64:
        raise ValueError('invalid sparse initializer count')
    addresses, regions, result = set(), set(), []
    for pair in memory:
        if not isinstance(pair, (list, tuple)) or len(pair) != 2:
            raise ValueError('invalid sparse initializer record')
        address, value = pair
        u32(address)
        if address & 15 or address in addresses:
            raise ValueError('unaligned or duplicate sparse initializer address')
        if type(value) is not int or not 0 <= value <= 0xffff:
            raise ValueError('invalid sparse initializer value')
        addresses.add(address)
        regions.add(address >> 10)
        result.extend([address & 0xffff, address >> 16, value])
    if len(regions) > 16:
        raise ValueError('too many sparse memory regions')
    return result


def external_event_words(entry, protocol_version):
    events = entry.get('external_events', [])
    if not isinstance(events, list) or len(events) > 16:
        raise ValueError('external event table must contain at most 16 entries')
    if events and protocol_version < 4:
        raise ValueError('external events require FPGA protocol 4')
    if entry.get('external_contract') is not None and protocol_version < 4:
        raise ValueError('external event expectations require FPGA protocol 4')
    contract = entry.get('external_contract')
    if (isinstance(contract, dict) and contract.get('kind') in ('scalar_irq_unaligned', 'scalar_nmi', 'scalar_nmi_phase', 'scalar_nmi_nostack', 'scalar_nmi_nostack_io', 'graphics_fill_irq') and
            protocol_version < 5):
        raise ValueError('unaligned IRQ/NMI requires FPGA protocol 5')
    expected_external_pause(entry)
    words = []
    for event in events:
        trigger, argument, control = validate_external_event(event)
        words.extend((argument & 65535, argument >> 16, control, trigger))
    return words


def make_batches(entries, protocol_version=2):
    if protocol_version not in RESULT_SIZES:
        raise ValueError('unsupported FPGA protocol version')
    batches = []
    def empty():
        return dict(cases=[], program_words=[], descriptors=[], protocol_version=protocol_version)
    batch = empty()
    identifiers = set()
    for entry in entries:
        words = entry['program_words']
        identifier = u32(entry['id'])
        if identifier in identifiers:
            raise ValueError('duplicate external case identifier')
        identifiers.add(identifier)
        if not words or len(words) > 3840 or any(type(v) is not int or not 0 <= v <= 0xffff for v in words):
            raise ValueError(f"{entry['name']}: invalid program length")
        require_supported(entry['fixture'], protocol_version)
        if is_byte_store_event(entry['fixture']):
            validate_byte_store_event_entry(entry, protocol_version)
        memory = initial_words(entry['fixture']) if protocol_version >= 2 else []
        stimulus = stimulus_for(entry)
        if protocol_version == 1 and any(stimulus.values()):
            raise ValueError('v1 does not support configurable stimulus')
        external = external_event_words(entry, protocol_version)
        total_words = len(words) + len(memory) + len(external)
        if total_words > MAX_WORDS:
            raise ValueError('case program, initial memory and events exceed the staging pool')
        if len(batch['cases']) == MAX_CASES or len(batch['program_words']) + total_words > MAX_WORDS:
            batches.append(batch)
            batch = empty()
        base = len(batch['program_words'])
        descriptor = [entry['id'], base, len(words), entry['test_pc'], entry['next_pc'],
                      entry['fixture'].get('measure_pass', 1)]
        descriptor += ([base + len(words), len(memory) // 3, stimulus['wait_states'],
                        stimulus['pause_clocks'], stimulus['pause_after_clocks'], 0]
                       if protocol_version >= 2 else [0, 0])
        if protocol_version >= 3:
            descriptor += [entry['fixture'].get('drain_instructions', 0) & MASK32,
                           entry['fixture'].get('follow_pc', 0), len(external) // 4,
                           base + len(words) + len(memory) if external else 0]
        batch['descriptors'].append(descriptor)
        batch['cases'].append(entry)
        batch['program_words'].extend(words + memory + external)
    if batch['cases']:
        batches.append(batch)
    return batches


def u32(value):
    if type(value) is not int or not 0 <= value <= MASK32:
        raise ValueError(f'invalid protocol word: {value!r}')
    return value


def validate_manifest(manifest):
    """Keep the envelope and every batch on the same wire contract."""
    formats = {name: version for version, name in FORMATS.items()}
    version = formats.get(manifest.get('format'))
    if version is None or manifest.get('protocol_version', 1) != version:
        raise ValueError('unsupported manifest format or protocol version')
    batches = manifest['batches']
    if not isinstance(batches, list) or not batches:
        raise ValueError('manifest has no batches')
    if any(batch.get('protocol_version', 1) != version for batch in batches):
        raise ValueError('batch protocol version differs from the manifest')
    validate_byte_store_event_manifest(manifest, version)
    return version


def validate_byte_store_event_manifest(manifest, protocol_version):
    """Bind the new standalone selector to its canonical inventory and sources."""
    selected = manifest.get('byte_store_event_profile')
    entries = [entry for batch in manifest['batches'] for entry in batch['cases']]
    has_family = any(is_byte_store_event(entry.get('fixture', {})) for entry in entries)
    if selected is None:
        if has_family:
            raise ValueError('byte-store event cases require a standalone selector manifest')
        return
    if protocol_version != 5 or not isinstance(selected, dict) or set(selected) != {
            'kind', 'hold_phase', 'wait_states', 'pause_clocks', 'pause_after_clocks', 'response_pause'}:
        raise ValueError('malformed byte-store event manifest selector')
    kind = selected['kind']
    if kind not in ('following', 'hold') or selected['response_pause'] is not True:
        raise ValueError('unsupported byte-store event manifest selector')
    phase = selected['hold_phase']
    if kind == 'following' and phase is not None:
        raise ValueError('following event selector may not set a HOLD phase')
    if kind == 'hold' and (type(phase) is not int or phase not in (0, 8, 24, 40, 52)):
        raise ValueError('invalid HOLD phase in byte-store event manifest')
    profile = dict(wait_states=selected['wait_states'], pause_clocks=selected['pause_clocks'],
                   pause_after_clocks=selected['pause_after_clocks'])
    wanted = prepare_byte_store_event_cases(kind, 5, profile, phase or 0)
    if len(entries) != len(wanted) or [entry.get('name') for entry in entries] != [
            entry['name'] for entry in wanted]:
        raise ValueError('byte-store event manifest inventory differs from its selector')
    for actual, canonical in zip(entries, wanted):
        if json.dumps(actual, sort_keys=True) != json.dumps(canonical, sort_keys=True):
            raise ValueError(f"{actual.get('name')}: byte-store event manifest entry differs from its selector")
    audit = manifest.get('fixture_selection_audit', {})
    if (audit.get('inventory_count') != len(wanted) or audit.get('selected_count') != len(wanted)
            or audit.get('excluded_count') != 0 or audit.get('complete_inventory') is not True):
        raise ValueError('byte-store event fixture-selection audit is incomplete')
    event_sources = manifest.get('byte_store_event_sources_sha256')
    if not isinstance(event_sources, dict):
        raise ValueError('byte-store event manifest lacks source hashes')
    expected_paths = ('store_dependency/byte_events_cases.py', 'timing/byte_store_event_oracle.py',
                      'store_dependency/check_byte_events.py', 'timing/byte_store_oracle.py',
                      'timing/copy_cases.py', 'timing/store_cases.py', 'timing/load_cases.py',
                      'timing/run.py')
    expected = {relative: hashlib.sha256((HERE.parent / relative).read_bytes()).hexdigest()
                for relative in expected_paths}
    if event_sources != expected:
        raise ValueError('byte-store event fixture/oracle source hashes differ from the manifest')


def decode_events(raw, case_count, protocol_version=1):
    per_case, per_batch = EVENT_LIMITS[protocol_version]
    if not isinstance(raw, list) or len(raw) > per_batch:
        raise ValueError('invalid event buffer length')
    lines = [[] for _ in range(case_count)]
    previous_case = -1
    previous_clock = -1
    counts = [0] * case_count
    stimulus_counts = [0] * case_count
    stimulus_clocks = [-1] * case_count
    for words in raw:
        if not isinstance(words, list) or len(words) != 4:
            raise ValueError('each event must contain four words')
        clock, data, address, flags = map(u32, words)
        index = (flags >> 9) & 31
        stimulus_record = protocol_version >= 4 and bool(flags & (1 << 14))
        allowed = 0x7fe00 if stimulus_record else (0x1c3fff if protocol_version >= 4 else 0x3fff)
        if flags & ~allowed or index >= case_count or (not stimulus_record and not flags & 0x1801e0):
            raise ValueError('invalid event flags or case association')
        if index < previous_case:
            raise ValueError('event case order is not chronological')
        if index != previous_case:
            previous_clock = -1
        previous_case = index
        counts[index] += 1
        if counts[index] > per_case:
            raise ValueError('event buffer exceeds its per-case bound')
        if stimulus_record:
            event_index = (flags >> 15) & 15
            if event_index != stimulus_counts[index] or clock <= stimulus_clocks[index]:
                raise ValueError('stimulus appendix is missing, duplicate or out of order')
            trigger, control = data >> 16, data & 0xffff
            validate_external_event(dict(trigger=trigger, argument=address, control=control))
            lines[index].append(f'STIMULUS {clock} {event_index} {trigger} {address:08x} {control:04x}')
            stimulus_counts[index] += 1
            stimulus_clocks[index] = clock
            continue
        if stimulus_counts[index] or clock < previous_clock:
            raise ValueError('runtime events follow stimulus appendix or run backwards')
        previous_clock = clock
        if protocol_version >= 4:
            if flags & (1 << 19):
                lines[index].append(f'HOLD_ACK {clock} {(flags >> 18) & 1}')
            if flags & (1 << 20):
                lines[index].append(f'HOST_ACK {clock}')
        kind, iaq = (flags >> 1) & 15, flags & 1
        for bit, prefix, complete in ((6, 'BUS', False), (5, 'BUS', True),
                                      (8, 'TARGET', False), (7, 'TARGET', True)):
            if flags & (1 << bit):
                # Preserve the simulation contract: logical allocations use the
                # enclosing TI state boundary; raw target dispatch is unrounded.
                when = clock - clock % 8 if prefix == 'BUS' and not complete else clock
                value = data & 0xffff if complete else data >> 16
                line = f'{prefix}_{"END" if complete else "BEGIN"} {when} {kind} {address:08x} {value:04x}'
                if not complete:
                    line += f' {iaq}'
                lines[index].append(line)
                if prefix == 'BUS' and not complete:
                    lines[index].append(f'BUS_ACCEPT {clock}')
    return lines


def register_slot(name):
    if name == 'sp':
        return 15
    if len(name) > 1 and name[0] in 'ab' and name[1:].isdigit() and int(name[1:]) < 16:
        logical = int(name[1:])
        return 15 if logical == 15 else logical + (16 if name[0] == 'b' else 0)
    raise ValueError(f'unsupported architectural observation {name!r}')


def read_register(result, base, name, valid, errors, context='', required=True):
    slot = register_slot(name)
    value = result[base + slot]
    missing = value == 0xdead0000 + slot if valid is None else not (valid >> slot) & 1
    if missing and required:
        errors.append(f'{context}{name.upper()}: RF shadow slot was not initialized')
    return value


def v3_observation_lines(case, result, observed, errors, protocol_version=3):
    """Reconstruct original-bench labels only from actual FPGA observations."""
    if result[202] > 0xffff:
        errors.append('primary INTPEND observation exceeds 16 bits')
    if 'data_line' in case:
        observed['wvp'] = (result[202] >> 11) & 1
    if result[273] or (any(result[278:]) if protocol_version == 3 else result[287]):
        errors.append('reserved result words are nonzero')
    drain = case.get('drain_instructions', 0)
    if drain > 0 or drain == -2:
        if result[272] <= observed['end']:
            errors.append('missing or invalid final drain boundary')
        final = result[272]
    else:
        if result[272]:
            errors.append('unexpected final drain boundary')
        final = observed['end']
    count, follow_pc = result[203], case.get('follow_pc', 0)
    if count != int(bool(follow_pc)):
        errors.append(f'following capture count: expected {int(bool(follow_pc))}, observed {count}')
    if not count:
        if any(result[204:272]) or any(result[276:278]):
            errors.append('unused following observation words are nonzero')
        return []
    if result[206] != follow_pc:
        errors.append('following capture PC association mismatch')
    if result[207] > 0xffff:
        errors.append('following accepted opcode exceeds 16 bits')
    if not observed['start'] < result[204] <= final:
        errors.append('following capture clock is outside the measured/drained interval')
    valid = result[276] | (result[277] << 32)
    required = {f'a{q}' for q in range(len(case.get('expected_follow_regs', [])))}
    required.update(case.get('expected_follow_extra_regs', {}))
    def values(names):
        return ' '.join(f'{name}={read_register(result, 208, name, valid, errors, "following ", name in required):08x}'
                        for name in names)
    lines = [f'FOLLOW clock={result[204]} st={result[205]:08x} ' + values([f'a{q}' for q in range(4)])]
    if case.get('observe_all'):
        lines.append('FOLLOW_ALL ' + values([name for q in range(4, 15) for name in (f'a{q}', f'b{q}')]))
    if case.get('observe_implicit') or case.get('observe_all') or (
            is_byte_store_event(case) and case.get('byte_store_event', {}).get('kind') == 'following'):
        lines.append('FOLLOW_EXTRA ' + values([*[f'b{q}' for q in range(7)], 'sp']))
    return lines


def check_batch(batch, capture):
    version = batch.get('protocol_version', 1)
    if version not in RESULT_SIZES or capture.get('protocol_version', 1) != version:
        raise ValueError('capture protocol version differs from the manifest')
    entries = batch['cases']
    if not 0 < len(entries) <= MAX_CASES:
        raise ValueError('invalid batch case count')
    if len({entry['id'] for entry in entries}) != len(entries):
        raise ValueError('duplicate external case identifier')
    count = u32(capture['event_count'])
    if count & 0x80000000:
        raise ValueError('FPGA diagnostic trace overflow')
    if u32(capture['status']) != 2:
        failures = []
        for result in capture.get('results', []):
            if isinstance(result, list) and len(result) >= 2 and type(result[1]) is int and result[1] != 2:
                failures.append(f'case id={result[0]} status=0x{result[1]:08x}')
        detail = '; '.join(failures) or 'no failing case result was returned'
        raise ValueError(f"FPGA batch did not succeed: status=0x{capture['status']:08x}; {detail}")
    if count != len(capture['events']):
        raise ValueError('event count differs from the drained buffer length')
    results = capture['results']
    if not isinstance(results, list) or len(results) != len(entries):
        raise ValueError('result count differs from the requested case count')
    traces = decode_events(capture['events'], len(entries), version)
    oracle = oracle_module()
    rows = []
    for index, (entry, result) in enumerate(zip(entries, results)):
        case = copy.deepcopy(entry['fixture'])
        require_supported(case, version)
        byte_event_case = is_byte_store_event(case)
        if byte_event_case:
            validate_byte_store_event_entry(entry, version)
        # Restore Python tuple pairs lost at the JSON transport boundary.
        for key in ('initial_memory', 'expected_memory', 'expected_follow_memory'):
            if key in case:
                case[key] = [tuple(pair) for pair in case[key]]
        if not isinstance(result, list) or len(result) != RESULT_SIZES[version]:
            raise ValueError(f"{entry['name']}: malformed result length")
        result = list(map(u32, result))
        errors = []
        if result[0] != entry['id']:
            errors.append(f"case identifier mismatch: expected {entry['id']}, observed {result[0]}")
        if result[1] != 2:
            errors.append(f'case execution failed: status=0x{result[1]:08x}')
        if result[3:5] != [entry['test_pc'], entry['next_pc']]:
            errors.append('measurement PC association mismatch')
        if result[7] + result[2] > MASK32 or result[2] == 0:
            errors.append('invalid or wrapped measurement clocks')
        observed = dict(case=result[0], clocks=result[2], start=result[7],
                        end=result[7] + result[2], paused=result[72] if version >= 2 else 0, st=result[6])
        if version >= 5:
            observed['protocol_version'] = version
        if observed['paused'] > observed['clocks']:
            errors.append('paused clocks exceed the measurement interval')
        required = [f'a{q}' for q in range(len(case['expected_regs']))]
        required.extend(case.get('expected_extra_regs', {}))
        valid = (result[274] | (result[275] << 32)) if version >= 3 else None
        for name in required:
            observed[name] = read_register(result, 8, name, valid, errors)
        word = (entry['next_pc'] - 0x1000) // 16
        expected_opcode = (entry['program_words'][word]
                           if 0 <= word < len(entry['program_words']) else 0)
        expected_opcode = dict(case.get('initial_memory', [])).get(entry['next_pc'], expected_opcode)
        expected_opcode = case.get('expected_next_opcode', expected_opcode)
        if result[5] != expected_opcode:
            errors.append('next accepted opcode differs from the fixture program')
        stimulus = stimulus_for(entry)
        expected_pause = stimulus['pause_clocks'] + expected_external_pause(entry)
        lines = list(traces[index])
        if version >= 3:
            lines.extend(v3_observation_lines(case, result, observed, errors, version))
        if version >= 5:
            count, previous, complete, first = result[288:292]
            if count == 0 and any((previous, complete, first)):
                errors.append('IRQ boundary clocks without context completion')
            if count and not ((previous == 0 and _event_contract.check_transfer_observation(entry) is False) or
                             observed['start'] <= previous < complete < first <= result[272]):
                errors.append('missing, unordered or out-of-range IRQ boundary clocks')
            lines.append(f'IRQ_BOUNDARY count={count} previous={previous} complete={complete} first={first}')
        dependency_case = is_store_dependency(case)
        errors.extend(oracle.check(case, observed, stimulus['wait_states'], expected_pause,
                                   check_duration=instruction_duration_required(case, entry)))
        if version >= 2:
            initial_words(case)
            memory = case.get('initial_memory', [])
            if result[73] != len(memory):
                errors.append('memory snapshot count differs from the initialized word count')
            for q, (address, _) in enumerate(memory):
                actual_address, value = result[74+2*q:76+2*q]
                if actual_address != address or value > 0xffff:
                    errors.append('memory snapshot association or value is invalid')
                lines.append(f'MEMORY {actual_address:08x} {value:04x}')
            if any(result[74+2*len(memory):202]):
                errors.append('unused memory snapshot words are nonzero')
        if any(key in case for key in ('control_flow', 'stack_control_flow', 'call_flow', 'trap_flow')):
            lines.append(f'NEXT_OPCODE {result[5]:04x}')
        if byte_event_case and case['byte_store_event']['kind'] == 'hold':
            lines.append(f'NEXT_OPCODE {result[5]:04x}')
        if version >= 4:
            errors.extend(check_external_events(entry, result, traces[index], version))
        log = '\n'.join(lines)
        row = oracle.check_observation(case, observed, errors, log, stimulus['wait_states'], expected_pause,
                                       check_transfer_observation=(False if byte_event_case else
                                           _event_contract.check_transfer_observation(entry)))
        if dependency_case:
            dependency = store_dependency_checker()
            bus_errors = dependency.check_trace(case, row['bus_trace'], stimulus['wait_states'])
            target_errors = dependency.check_trace(case, row['target_trace'], stimulus['wait_states'], raw=True)
            errors.extend(bus_errors)
            errors.extend(target_errors)
            # Keep the captured opcode in the normalized row so the ordinary
            # cross-backend comparator can compare it with the archived bench.
            # The preceding result[5] check still rejects a wrong opcode; this
            # field records what the FPGA actually returned, not the fixture's
            # expected value.
            row['observed_next_opcodes'] = [result[5]]
            row['dependency_observation'] = dict(conditions=copy.deepcopy(case['dependency_conditions']),
                                                 bus_errors=bus_errors,
                                                 target_errors=target_errors)
        if byte_event_case:
            _, event_oracle = byte_store_event_modules()
            event_row = event_oracle.check_observation(case, observed, log,
                                                        stimulus['wait_states'], expected_pause)
            errors.extend(event_row['errors'])
            for key in ('bus_trace', 'target_trace', 'observed_memory', 'hold_edges',
                        'observed_follow', 'observed_next_opcodes'):
                if key in event_row:
                    row[key] = event_row[key]
            row['byte_store_event'] = copy.deepcopy(case['byte_store_event'])
            row['byte_store_event_profile'] = copy.deepcopy(entry.get('byte_store_event_profile'))
            row['external_observation'] = external_observation(result, traces[index])
        follow_errors, irq_observation = _event_contract.check_followup(entry, observed, lines)
        errors.extend(follow_errors)
        if irq_observation is not None:
            row['irq_observation'] = irq_observation
        if not byte_event_case and (entry.get('external_events') or entry.get('external_contract') is not None):
            row['external_observation'] = external_observation(result, traces[index])
            row['external_contract'] = copy.deepcopy(entry.get('external_contract'))
        rows.append(row)
    failures = sum(bool(row['errors']) for row in rows)
    return dict(cases=rows, passed=len(rows) - failures, failed=failures)


def check_external_events(entry, result, traces, protocol_version=4):
    """Check transport/event observations; keep ISA timing expectations separate."""
    expected = entry.get('external_events', [])
    external_event_words(entry, protocol_version)
    errors, applied, writes, hosts, hold_edges = [], [], [], [], []
    for line in traces:
        fields = line.split()
        if fields[0] == 'STIMULUS':
            applied.append((int(fields[1]), int(fields[3]), int(fields[4], 16), int(fields[5], 16)))
        elif fields[0] == 'TARGET_END' and fields[2] == '1':
            writes.append(int(fields[1]))
        elif fields[0] == 'HOST_ACK':
            hosts.append(int(fields[1]))
        elif fields[0] == 'HOLD_ACK':
            hold_edges.append((int(fields[1]), int(fields[2])))
    finish = result[272] or result[7] + result[2]

    def held_before(clock):
        total, start = 0, None
        for when, level in hold_edges:
            if when >= clock:
                break
            if level:
                start = when
            elif start is not None:
                total += when - start
                start = None
        if start is not None:
            total += clock - start
        return total

    level = 0
    for _, following in hold_edges:
        if following == level:
            errors.append('HOLD acknowledgement record does not change level')
        level = following
    if result[278:280] != [len(expected), len(expected)] or len(applied) != len(expected):
        errors.append('external event table/applied/trace count mismatch')
    if result[280] != len(writes) or result[281] != held_before(finish + 1):
        errors.append('external write/HOLD counter differs from trace')
    issued = sum(bool(event['control'] & 16) for event in expected)
    if result[282:284] != [issued, issued] or len(hosts) != issued:
        errors.append('external host request/acknowledgement count mismatch')
    if result[284] or result[287]:
        errors.append('external sequencer failure or reserved result word')
    previous = result[7] + 1
    pause_start, paused = None, 0
    for wanted, observed in zip(expected, applied):
        trigger, argument, control = validate_external_event(wanted)
        clock, actual_trigger, actual_argument, actual_control = observed
        if (actual_trigger, actual_argument, actual_control) != (trigger, argument, control):
            errors.append('applied external event differs from fixture stimulus')
        if clock <= result[7] or clock > finish:
            errors.append('external event lies outside execution interval')
        if trigger == 0 and clock != result[7] + argument + 1:
            errors.append('external event clock differs from configured clock')
        elif trigger == 1 and sum(when < clock for when in writes) != argument:
            errors.append('external event write checkpoint mismatch')
        elif trigger == 2:
            follow = entry['fixture'].get('follow_pc', 0)
            if argument != follow or not result[203] or clock != result[204] + 1:
                errors.append('external PC trigger has no matching independent decode observation')
        elif trigger == 3 and clock - previous != argument:
            errors.append('external relative-delay trigger mismatch')
        elif trigger == 4 and held_before(clock) != argument:
            errors.append('external HOLD acknowledgement trigger mismatch')
        elif trigger == 5 and sum(when < clock for when in hosts) != argument:
            errors.append('external host acknowledgement trigger mismatch')
        if control & 32 and pause_start is None:
            pause_start = clock
        elif not control & 32 and pause_start is not None:
            paused += clock - pause_start
            pause_start = None
        previous = clock
    if pause_start is not None:
        paused += finish + 1 - pause_start
    if result[286] != paused:
        errors.append('external CEN pause count differs from applied controls')
    last = applied[-1][0] - result[7] - 1 if applied else 0
    if result[285] != last:
        errors.append('external last-event clock mismatch')
    return errors


def external_observation(result, traces):
    """Serialize actual observations for cross-backend comparison, without expectations."""
    start = result[7]
    observation = dict(zip(('configured', 'applied', 'writes', 'holds', 'hosts', 'issued',
                            'error', 'last', 'paused'), result[278:287]))
    observation.update(events=[], hold_edges=[], host_clocks=[])
    for line in traces:
        fields = line.split()
        if fields[0] == 'STIMULUS':
            observation['events'].append([int(fields[1])-start, int(fields[2]),
                int(fields[3]), int(fields[4], 16), int(fields[5], 16)])
        elif fields[0] == 'HOLD_ACK':
            observation['hold_edges'].append([int(fields[1])-start, int(fields[2])])
        elif fields[0] == 'HOST_ACK':
            observation['host_clocks'].append(int(fields[1])-start)
    return observation


def compare_reference(rows, reference_rows):
    """Compare validated captures with the original bench, relative to decode."""
    actual = {row['name']: row for row in rows}
    reference = {row['name']: row for row in reference_rows}
    if len(actual) != len(rows) or len(reference) != len(reference_rows):
        return ['duplicate case names in cross-backend comparison']
    if actual.keys() != reference.keys():
        return ['case inventory differs between FPGA and reference captures']
    errors = []
    for name, row in actual.items():
        other = reference[name]
        if row['errors'] or other['errors']:
            errors.append(name+': failing input capture cannot establish equivalence')
            continue
        for key in ('external_contract', 'external_observation', 'irq_observation'):
            if row.get(key) != other.get(key):
                errors.append(name+': '+key+' differs')
        reference_fixture = other.get('fixture', other)
        for key in ('opcode', 'regs', 'expected_regs', 'expected_st', 'states',
                    'cache_disabled', 'extensions', 'expected_extra_regs', 'test_pc', 'next_pc',
                    'initial_memory', 'expected_memory', 'data_load', 'data_list',
                    'stack_load', 'pixel_load', 'control_flow', 'stack_control_flow',
                    'initial_all_regs', 'register_overrides', 'data_store', 'data_copy',
                    'data_trap', 'data_fill', 'data_line', 'data_blit', 'blit_timing', 'drain_instructions', 'follow_pc',
                    'expected_follow_regs', 'expected_follow_st', 'expected_follow_extra_regs',
                    'expected_follow_memory', 'control_follow', 'list_follow', 'follow_delay',
                    'expected_st_mask', 'expected_wvp', 'observe_all', 'observe_implicit',
                    'dependency_conditions', 'byte_store_event', 'following_words',
                    'expected_next_opcode'):
            if json.loads(json.dumps(row.get(key))) != json.loads(json.dumps(reference_fixture.get(key))):
                errors.append(name+': fixture '+key+' differs')
        observed, golden = row['observed'], other['observed']
        fields = ['clocks', 'st', 'paused', *[f'a{q}' for q in range(len(row['expected_regs']))],
                  *row.get('expected_extra_regs', {})]
        for key in fields:
            if observed.get(key) != golden.get(key):
                errors.append(name+': observed '+key+' differs')
        if 'data_line' in row and observed.get('wvp') != golden.get('wvp'):
            errors.append(name+': observed WVP differs')
        if 'observed_follow' in row or 'observed_follow' in other:
            actual_follow, golden_follow = row.get('observed_follow', {}), other.get('observed_follow', {})
            follow_fields = ['st', *[f'a{q}' for q in range(len(row.get('expected_follow_regs', [])))],
                             *row.get('expected_follow_extra_regs', {})]
            for key in follow_fields:
                if actual_follow.get(key) != golden_follow.get(key):
                    errors.append(name+': following '+key+' differs')
            if (actual_follow.get('clock', -1) - observed['end'] !=
                    golden_follow.get('clock', -1) - golden['end']):
                errors.append(name+': following relative clock differs')
        for key in ('observed_memory', 'observed_next_opcodes'):
            if json.loads(json.dumps(row.get(key))) != json.loads(json.dumps(other.get(key))):
                errors.append(name+': '+key+' differs')
        actual_event = row.get('byte_store_event', row.get('fixture', {}).get('byte_store_event'))
        golden_event = other.get('byte_store_event', other.get('fixture', {}).get('byte_store_event'))
        if json.loads(json.dumps(actual_event)) != json.loads(json.dumps(golden_event)):
            errors.append(name+': byte_store_event differs')
        if actual_event is not None:
            actual_profile = row.get('byte_store_event_profile')
            golden_profile = other.get('byte_store_event_profile')
            if golden_profile is None:
                # Older independent-reference wrappers represented the same
                # metadata as top-level kind/hold_phase fields.
                golden_profile = dict(kind=other.get('kind'))
                if other.get('kind') == 'hold':
                    golden_profile['hold_phase'] = other.get('hold_phase')
            elif ('kind' in other and other.get('kind') != golden_profile.get('kind') or
                  other.get('kind') == 'hold' and
                  other.get('hold_phase') != golden_profile.get('hold_phase')):
                errors.append(name+': reference byte_store_event_profile conflicts with its descriptive fields')
            if actual_profile != golden_profile:
                errors.append(name+': byte_store_event_profile differs')
        actual_holds = [[clock-row['observed']['start'], level]
                        for clock, level in row.get('hold_edges', [])]
        golden_holds = [[clock-other['observed']['start'], level]
                        for clock, level in other.get('hold_edges', [])]
        if actual_holds != golden_holds:
            errors.append(name+': hold_edges differs relative to measured start')
        for key in ('bus_trace', 'target_trace', 'follow_bus_trace', 'follow_target_trace'):
            normalized = []
            for item in (row, other):
                lines = []
                for line in item.get(key, []):
                    parts = line.split()
                    parts[1] = str(int(parts[1]) - item['observed']['start'])
                    lines.append(' '.join(parts))
                normalized.append(lines)
            if normalized[0] != normalized[1]:
                errors.append(name+': '+key+' differs relative to accepted decode')
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    prepare = sub.add_parser('prepare')
    prepare.add_argument('--case', action='append', default=[])
    prepare.add_argument('--matrix', '--read-only-matrix', dest='read_only_matrix', action='store_true',
                         help='select all fixtures supported by the chosen protocol; record exclusions')
    prepare.add_argument('--limit', type=int)
    prepare.add_argument('--published-targets', action='store_true',
                         help='select agreeing TI MOVB duration targets; known failures on the baseline CPU')
    prepare.add_argument('--store-dependency', action='store_true',
                         help='select only the explicit cache-disabled CD byte-store dependency fixtures')
    prepare.add_argument('--byte-store-events', choices=('following', 'hold'),
                         help='select the explicit protocol-v5 CD byte-store event inventory')
    prepare.add_argument('--hold-phase', type=int, choices=(0, 8, 24, 40, 52), default=None,
                         help='HOLD grant phase in INCLK (only with --byte-store-events hold)')
    prepare.add_argument('--protocol-version', type=int, choices=(1, 2, 3, 4, 5), default=5)
    prepare.add_argument('--wait-states', type=int, default=0)
    prepare.add_argument('--pause-clocks', type=int, default=0)
    prepare.add_argument('--pause-after-clocks', type=int, default=0)
    prepare.add_argument('--output', type=Path, required=True)
    check = sub.add_parser('check')
    check.add_argument('manifest', type=Path)
    check.add_argument('capture', type=Path)
    check.add_argument('--batch', type=int, default=0)
    check.add_argument('--report', type=Path)
    compare = sub.add_parser('compare', help='compare a checked multi-batch capture with Verilator')
    compare.add_argument('manifest', type=Path)
    compare.add_argument('capture', type=Path)
    compare.add_argument('reference', type=Path)
    compare.add_argument('--report', type=Path)
    args = parser.parse_args()
    try:
        if args.command == 'prepare':
            if args.limit is not None and args.limit < 1:
                raise ValueError('--limit must be positive')
            selectors = sum((bool(args.case), args.read_only_matrix, args.published_targets,
                             args.store_dependency, args.byte_store_events is not None))
            if selectors > 1:
                raise ValueError('fixture-selection modes are mutually exclusive')
            if args.hold_phase is not None and args.byte_store_events != 'hold':
                raise ValueError('--hold-phase is valid only with --byte-store-events hold')
            if args.byte_store_events:
                if args.limit is not None:
                    raise ValueError('--byte-store-events is a complete standalone inventory')
                stimulus = dict(wait_states=args.wait_states, pause_clocks=args.pause_clocks,
                                pause_after_clocks=args.pause_after_clocks)
                phase = 0 if args.hold_phase is None else args.hold_phase
                entries = prepare_byte_store_event_cases(args.byte_store_events,
                    args.protocol_version, stimulus, phase)
                names = ''.join(entry['name']+'\n' for entry in entries)
                audit = dict(inventory_count=len(entries), selected_count=len(entries),
                    excluded_count=0, exclusions={}, complete_inventory=True,
                    inventory_names_sha256=hashlib.sha256(names.encode()).hexdigest(),
                    selected_names_sha256=hashlib.sha256(names.encode()).hexdigest())
                dependency_dir = HERE.parent / 'store_dependency'
                event_hashes = {
                    str(path.relative_to(HERE.parent)): hashlib.sha256(path.read_bytes()).hexdigest()
                    for path in (dependency_dir / 'byte_events_cases.py',
                                 TIMING / 'byte_store_event_oracle.py',
                                 dependency_dir / 'check_byte_events.py',
                                 TIMING / 'byte_store_oracle.py', TIMING / 'copy_cases.py',
                                 TIMING / 'store_cases.py', TIMING / 'load_cases.py',
                                 TIMING / 'run.py')
                }
                byte_selection = dict(kind=args.byte_store_events,
                    hold_phase=phase if args.byte_store_events == 'hold' else None,
                    wait_states=args.wait_states, pause_clocks=args.pause_clocks,
                    pause_after_clocks=args.pause_after_clocks, response_pause=True)
                dependency_hashes = None
            elif args.store_dependency:
                if args.case or args.read_only_matrix or args.published_targets or args.limit is not None:
                    raise ValueError('--store-dependency is an explicit standalone fixture selection')
                stimulus = dict(wait_states=args.wait_states, pause_clocks=args.pause_clocks,
                                pause_after_clocks=args.pause_after_clocks)
                entries = prepare_store_dependency_cases(args.protocol_version, stimulus)
                audit = dict(inventory_count=16, selected_count=16, excluded_count=0,
                             exclusions={}, complete_inventory=True,
                             inventory_names_sha256=hashlib.sha256(
                                 ''.join(entry['name']+'\n' for entry in entries).encode()).hexdigest(),
                             selected_names_sha256=hashlib.sha256(
                                 ''.join(entry['name']+'\n' for entry in entries).encode()).hexdigest())
                dependency_dir = HERE.parent / 'store_dependency'
                dependency_hashes = {
                    str(path.relative_to(HERE.parent)): hashlib.sha256(path.read_bytes()).hexdigest()
                    for path in (dependency_dir / 'cases.py', dependency_dir / 'check.py',
                                 TIMING / 'copy_cases.py', TIMING / 'store_cases.py',
                                 TIMING / 'store_dependency_oracle.py')
                }
            else:
                terms = args.case
                audit = {}
                entries = prepare_cases(terms, args.limit, args.protocol_version,
                                        dict(wait_states=args.wait_states, pause_clocks=args.pause_clocks,
                                             pause_after_clocks=args.pause_after_clocks),
                                        read_only_matrix=args.read_only_matrix, audit=audit,
                                        published_targets=args.published_targets)
                dependency_hashes = None
            data = dict(format=FORMATS[args.protocol_version],
                        protocol_version=args.protocol_version,
                        batches=make_batches(entries, args.protocol_version),
                        fixture_selection_audit=audit,
                        oracle_sha256=hashlib.sha256((TIMING / 'run.py').read_bytes()).hexdigest())
            if args.byte_store_events:
                data['byte_store_event_selection'] = byte_selection
                data['byte_store_event_sources_sha256'] = event_hashes
                data['byte_store_event_profile'] = copy.deepcopy(byte_selection)
            if dependency_hashes is not None:
                data['dependency_sources_sha256'] = dependency_hashes
                data['dependency_profile'] = dict(wait_states=args.wait_states,
                    pause_clocks=args.pause_clocks,
                    pause_after_clocks=args.pause_after_clocks,
                    response_pause=True)
            args.output.write_text(json.dumps(data, indent=2) + '\n')
            print(f"Prepared {len(entries)} cases in {len(data['batches'])} batches")
            return 0
        manifest = json.loads(args.manifest.read_text())
        validate_manifest(manifest)
        if args.command == 'compare':
            captures = json.loads(args.capture.read_text())['batches']
            if not isinstance(captures, list) or not captures or len(captures) != len(manifest['batches']):
                raise ValueError('capture batch count differs from the manifest')
            reports = [check_batch(batch, captured)
                       for batch, captured in zip(manifest['batches'], captures)]
            rows = [row for report in reports for row in report['cases']]
            differences = compare_reference(rows, json.loads(args.reference.read_text())['cases'])
            report = dict(batches=reports, passed=sum(x['passed'] for x in reports),
                          failed=sum(x['failed'] for x in reports),
                          reference_comparison_errors=differences)
            if args.report:
                args.report.write_text(json.dumps(report, indent=2) + '\n')
            for row in rows:
                for error in row['errors']:
                    print(f"{row['name']}: {error}", file=sys.stderr)
            for error in differences:
                print(error, file=sys.stderr)
            print(f"Checked {len(rows)} cases: {report['failed']} failed, "
                  f"{len(differences)} reference differences")
            return int(bool(report['failed']) or bool(differences))
        if not 0 <= args.batch < len(manifest['batches']):
            raise ValueError('invalid batch index')
        report = check_batch(manifest['batches'][args.batch], json.loads(args.capture.read_text()))
        if args.report:
            args.report.write_text(json.dumps(report, indent=2) + '\n')
        for row in report['cases']:
            print(f"{row['name']}: {'FAIL' if row['errors'] else 'PASS'}")
            for error in row['errors']:
                print('  ' + error)
        return int(bool(report['failed']))
    except (ValueError, KeyError, TypeError, IndexError) as error:
        print(f'FPGA result error: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
