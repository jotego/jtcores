#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Explicit project choices for contradictory TI sources, never TI errata.

Owner direction, 2026-10-18: "If you cannot find a reliable conclusion,
implement the easier one". Retain the existing simple shared datapath and
documented counts/formula. This registry reads no RTL or observations.
Exact source signatures prevent new discrepancies inheriting an exception.
MOVB absolute is deliberately absent: its agreed published target is open.
"""


def signature(values):
    return tuple(sorted(values.items()))


# Each row is: summary CPU/CD, selected CPU/CD, typical entry CPU/CD.
# These alternatives are transcribed in the cited instruction fixtures.
TIMING_CHOICES = {
    'MOVE_ABS_R': ('absolute-load-summary', [
        (5,14,5,14,5,15), (7,16,7,16,7,13)]),
    'MOVE_R_OFF': ('offset-store-equation', [
        (3,9,3,10,3,7,1), (3,12,3,12,3,9,3),
        (3,13,3,16,None,None,7)]),
    'MOVB_R_OFF': ('offset-byte-store-equation', [
        (3,7,3,12,3,9,3), (3,7,3,12,None,None,3),
        (3,13,3,16,None,None,7)]),
    'MOVE_R_ABS': ('absolute-store-summary', [
        (3,13,3,13,3,7,1), (3,15,3,15,3,9,3)]),
}

CHOICES = {}
for identifier,(decision,rows) in TIMING_CHOICES.items():
    for row in rows:
        sc,sd,pc,pd,ec,ed,*hidden=row
        values=dict(summary_cpu=sc,summary_cd=sd,policy_cpu=pc,policy_cd=pd,
                    entry_typical_cpu=ec,entry_typical_cd=ed)
        if hidden:values['summary_hidden']=hidden[0]
        CHOICES[identifier,signature(values)]=decision

for identifier,decision,values in [
    ('JR_SHORT','untaken-short-jr-entry-and-datasheet',dict(
        summary_cpu=2,summary_cd=5,datasheet_cpu=1,
        entry_typical_cpu=1,entry_typical_cd=4,policy_cpu=1,policy_cd=4)),
    ('JR_LONG','untaken-long-jr-datasheet-and-inferred-cd',dict(
        summary_cpu=1,summary_cd=4,datasheet_cpu=2,
        entry_typical_cpu=4,entry_typical_cd=7,policy_cpu=2,policy_cd=5)),
    ('CMPXY_RR','compare-xy-summary-and-datasheet',dict(
        entry_cpu=1,entry_cd=4,summary_cpu=3,summary_cd=6,
        datasheet_cpu=3,policy_cpu=3,policy_cd=6)),
]:
    CHOICES[identifier,signature(values)]=decision

# Table13-4 index12's CPU5 conflicts with its three source reads and
# its own CD17/H7 arithmetic. Retain the simpler shared read schedule.
CHOICES['MOVE_IND_IND',signature(dict(summary_cpu=5,summary_cd=17,
    policy_cpu=7,policy_cd=17))]='copy-three-source-word-schedule'

# Table13-4 pointer forms retain the same simpler read schedule.
for identifier,values in [
    ('MOVE_POST_POST',dict(summary_cpu=6,summary_cd=17,policy_cpu=8,policy_cd=17)),
    ('MOVE_PRE_PRE',dict(summary_cpu=6,summary_cd=18,policy_cpu=8,policy_cd=18)),
    ('MOVE_PRE_PRE',dict(summary_cpu=6,summary_cd=15,policy_cpu=6,policy_cd=16)),
]:
    CHOICES[identifier,signature(values)]='pointer-copy-common-state-equation'

for printed,formula in [(0x20000,0x200C0),(0x28000,0x280C0),
                        (0x0F020000,0x0F0200C0),(0x10000,0x10030)]:
    values=dict(entry_cpu=3,entry_cd=6,policy_cpu=3,policy_cd=6,
                entry_example_result=printed,formula_result=formula,
                policy_result=formula)
    CHOICES['CVXYL_RR',signature(values)]='xy-conversion-repeated-formula'


def project_choice(identifier,values,kind):
    if kind=='agreed-published-target-gap':return None
    decision=CHOICES.get((identifier,signature(values)))
    if decision is None:return None
    return dict(decision=decision,authority='project-owner-2026-10-18',
                classification='project-interpretation',official_ti_resolution=False)
