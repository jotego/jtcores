#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Fail the full-suite gate until every TI instruction form has timing probes.

This is a necessary coverage gate, not a substitute for condition/bus/IRQ
audits. The index is transcribed from SPVU001A §12.10 (June 1988), using
printed instruction-entry page numbers. It is independent of RTL dispatch.
Unresolved timing-source overrides also block acceptance, even if every
instruction form has probes and every implementation-policy probe passes.
"""
import argparse
import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
from run import cases

# Identifier, printed page(s). Separate encodings/addressing forms must not
# disappear behind a single instruction-family or opcode-decoder match.
REQUIRED_ROWS = [line.split() for line in """
ABS_R 12-35
ADD_RR 12-36
ADDC_RR 12-37
ADDI_IW 12-38
ADDI_IL 12-39
ADDK_K 12-40
ADDXY_RR 12-41
AND_RR 12-42
ANDI_IL 12-43
ANDN_RR 12-44
ANDNI_IL 12-45
BTST_K 12-46
BTST_RR 12-47
CALL_R 12-48
CALLA 12-49
CALLR 12-50
CLR_R 12-51
CLRC 12-52
CMP_RR 12-53
CMPI_IW 12-54
CMPI_IL 12-55
CMPXY_RR 12-56
CPW_RR 12-57..58
CVXYL_RR 12-59..60
DEC_R 12-61
DINT 12-62
DIVS_RR 12-63..64
DIVU_RR 12-65..66
DRAV_RR 12-67..69
DSJ 12-70
DSJEQ 12-71..72
DSJNE 12-73..74
DSJS 12-75
EINT 12-76
EMU 12-77
EXGF_R 12-78
EXGPC_R 12-79
FILL_L 12-80..83
FILL_XY 12-84..88
GETPC_R 12-89
GETST_R 12-90
INC_R 12-91
JACC 12-92..93
JR_SHORT 12-94..95
JR_LONG 12-96..97
JUMP_R 12-98
LINE 12-99..107
LMO_RR 12-108
MMFM 12-109..110
MMTM 12-111..112
MODS 12-113
MODU 12-114
MOVB_R_IND 12-115
MOVB_R_OFF 12-116
MOVB_R_ABS 12-117
MOVB_IND_R 12-118
MOVB_IND_IND 12-119
MOVB_OFF_R 12-120
MOVB_OFF_OFF 12-121..122
MOVB_ABS_R 12-123
MOVB_ABS_ABS 12-124..125
MOVE_RR 12-126
MOVE_R_IND 12-127
MOVE_R_POST 12-128..129
MOVE_R_PRE 12-130..131
MOVE_R_OFF 12-132..133
MOVE_R_ABS 12-134
MOVE_IND_R 12-135..136
MOVE_IND_IND 12-137..138
MOVE_POST_R 12-139..140
MOVE_POST_POST 12-141..142
MOVE_PRE_R 12-143..144
MOVE_PRE_PRE 12-145..146
MOVE_OFF_R 12-147..148
MOVE_OFF_POST 12-149..150
MOVE_OFF_OFF 12-151..152
MOVE_ABS_R 12-153..154
MOVE_ABS_POST 12-155..156
MOVE_ABS_ABS 12-157..158
MOVI_IW 12-159
MOVI_IL 12-160
MOVK_K 12-161
MOVX_RR 12-162
MOVY_RR 12-163
MPYS_RR 12-164..165
MPYU_RR 12-166..167
NEG_R 12-168
NEGB_R 12-169
NOP 12-170
NOT_R 12-171
OR_RR 12-172
ORI_IL 12-173
PIXBLT_BL 12-174..178
PIXBLT_BXY 12-179..186
PIXBLT_LL 12-187..192
PIXBLT_LXY 12-193..199
PIXBLT_XYL 12-200..205
PIXBLT_XYXY 12-206..212
PIXT_R_LIN 12-213..214
PIXT_R_XY 12-215..217
PIXT_LIN_R 12-218..219
PIXT_LIN_LIN 12-220..221
PIXT_XY_R 12-222..223
PIXT_XY_XY 12-224..226
POPST 12-227
PUSHST 12-228
PUTST_R 12-229
RETI 12-230..231
RETS 12-232
REV_R 12-233
RL_K 12-234
RL_RR 12-235
SETC 12-236
SETF 12-237
SEXT_R 12-238
SLA_K 12-239
SLA_RR 12-240
SLL_K 12-241
SLL_RR 12-242
SRA_K 12-243
SRA_RR 12-244
SRL_K 12-245
SRL_RR 12-246
SUB_RR 12-247
SUBB_RR 12-248
SUBI_IW 12-249
SUBI_IL 12-250
SUBK_K 12-251
SUBXY_RR 12-252
TRAP 12-253..254
XOR_RR 12-255
XORI_IL 12-256
ZEXT_R 12-257
""".splitlines() if line.strip()]
REQUIRED = dict(REQUIRED_ROWS)
if len(REQUIRED) != len(REQUIRED_ROWS):
    raise ValueError('duplicate instruction form in the TI coverage index')


def inventory(rows):
    """Inventory probe presence and unresolved expectations independently.

    Source values are transcribed in fixtures; no RTL or measured latency is
    consulted. In particular, agreeing TI entry/summary values must not be
    called a conflict between sources when the chosen policy differs.
    """
    probes = {identifier: [] for identifier in REQUIRED}
    unresolved = []
    for case in rows:
        identifier = case['coverage_id']
        if identifier not in REQUIRED:
            raise ValueError(f"unknown TI coverage identifier {identifier!r}")
        probes[identifier].append(case['name'])
        values = case.get('source_values', {})
        suffix = 'cd' if case['cache_disabled'] else 'cpu'
        policy = values.get('policy_'+suffix)
        if policy is not None:
            miss = 9 if case.get('cache_miss') in ('load_extension','store_extension') else 0
            if case['states'] != policy + miss:
                raise ValueError(f"{case['name']}: source policy differs from the probe expectation")
        published = [count for key,count in values.items()
                     if key.endswith('_'+suffix) and not key.startswith('policy_') and count is not None]
        differs = policy is not None and any(count != policy for count in published)
        results=[result for key,result in values.items() if key.endswith('_result') and not key.startswith('policy_')]
        result_differs=False
        if results:
            selected=values.get('policy_result')
            register=case.get('source_result_register','')
            if selected is None or not register:
                raise ValueError(f"{case['name']}: missing selected result-source policy")
            expected=case['expected_regs'][int(register[1:])] if register.startswith('a') else case['expected_extra_regs'][register]
            if selected!=expected:
                raise ValueError(f"{case['name']}: source result policy differs from the probe expectation")
            result_differs=any(value!=selected for value in results)
        if differs or result_differs or case.get('timing_source_status') == 'inferred-conflict-resolution':
            agreed_gap = len(published)>=2 and len(set(published))==1 and published[0]!=policy
            unresolved.append(dict(
                name=case['name'], identifier=identifier, citation=case['citation'],
                clock_unit='machine states', cache_disabled=case['cache_disabled'],
                kind='unresolved-behavior-source' if result_differs or case.get('source_conflict_kind')=='behavior' else
                     'agreed-published-target-gap' if agreed_gap else 'unresolved-source-policy',
                source_values=values))
    missing = [identifier for identifier, names in probes.items() if not names]
    return dict(
        full_isa_signoff=False,
        gate_passed=not missing and not unresolved,
        note='Probe presence and resolved timing sources are necessary; condition and bus/IRQ audits also remain required.',
        missing_forms=missing, unresolved_source_probes=unresolved,
        forms=[dict(identifier=identifier, source='SPVU001A '+page,
                    probes=probes[identifier], status='probes-present' if probes[identifier] else 'unvalidated')
               for identifier, page in REQUIRED.items()])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    try:
        result = inventory(cases())
    except ValueError as error:
        parser.error(str(error))
    missing = result['missing_forms']
    print(f'TI instruction-form coverage: {len(REQUIRED)-len(missing)}/{len(REQUIRED)} have timing probes')
    for identifier in missing:
        print(f'UNVALIDATED {identifier}: SPVU001A {REQUIRED[identifier]}')
    unresolved = result['unresolved_source_probes']
    agreed = [row for row in unresolved if row['kind']=='agreed-published-target-gap']
    print(f'TI expectation-source acceptance: {len(unresolved)} unresolved probes, including {len(agreed)} probes with agreed published-target gaps')
    for identifier in dict.fromkeys(row['identifier'] for row in unresolved):
        affected = [row for row in unresolved if row['identifier']==identifier]
        print(f'UNRESOLVED {identifier}: {len(affected)} source-policy probes; see source_values in the coverage report')
    if agreed:
        row = agreed[0]
        print(f'PUBLISHED_TARGET_GAP {row["name"]}: {row["source_values"]} ({row["citation"]})')
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(result, indent=2)+'\n')
    return int(not result['gate_passed'])


if __name__ == '__main__':
    sys.exit(main())
