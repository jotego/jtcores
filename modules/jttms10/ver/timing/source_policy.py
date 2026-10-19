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

# Table13-4 source-extension copies retain two address states and the
# repeated three-CD-state cost per word; preserve every printed alternative.
for identifier,rows in {
    'MOVE_OFF_POST':[(7,13,7,16,7,16),(7,15,7,18,None,None),(7,16,7,20,None,None),
                     (7,19,7,22,None,None),(7,22,9,22,None,None)],
    'MOVE_ABS_POST':[(7,16,7,19,7,19),(7,18,7,21,None,None),(7,19,7,23,None,None),
                     (7,22,7,25,None,None),(7,25,9,25,None,None)],
}.items():
    for sc,sd,pc,pd,ec,ed in rows:
        values=dict(summary_cpu=sc,summary_cd=sd,policy_cpu=pc,policy_cd=pd,
                    entry_typical_cpu=ec,entry_typical_cd=ed)
        CHOICES[identifier,signature(values)]='source-extension-copy-common-equation'

for printed,formula in [(0x20000,0x200C0),(0x28000,0x280C0),
                        (0x0F020000,0x0F0200C0),(0x10000,0x10030)]:
    values=dict(entry_cpu=3,entry_cd=6,policy_cpu=3,policy_cd=6,
                entry_example_result=printed,formula_result=formula,
                policy_result=formula)
    CHOICES['CVXYL_RR',signature(values)]='xy-conversion-repeated-formula'

# Table13-4 two-address forms and their typical instruction entries disagree.
# Keep the shared source-read/hidden-write formula, with two/four operand
# states. Byte offset's entry CD9 and absolute field's entry CD12 are literal.
for identifier,rows in {
    'MOVE_OFF_OFF':[(7,16,7,19,7,19),(7,18,7,21,None,None),(7,19,7,23,None,None),
                    (7,22,7,25,None,None),(7,25,9,25,None,None)],
    'MOVE_ABS_ABS':[(7,23,7,23,7,12),(9,24,9,27,9,27),(9,26,9,29,None,None),
                    (9,27,9,31,None,None),(9,30,9,33,None,None),(9,33,11,33,None,None)],
    'MOVB_OFF_OFF':[(5,7,5,17,5,9),(5,7,5,17,None,None),
                    (6,13,7,19,None,None),(7,19,7,23,None,None)],
    'MOVB_ABS_ABS':[(7,7,7,25,7,25),(7,7,7,25,None,None),
                    (6,12,9,27,None,None),(9,27,9,31,None,None)],
}.items():
    for sc,sd,pc,pd,ec,ed in rows:
        values=dict(summary_cpu=sc,summary_cd=sd,policy_cpu=pc,policy_cd=pd,
                    entry_typical_cpu=ec,entry_typical_cd=ed)
        CHOICES[identifier,signature(values)]='two-address-copy-common-equation'

# The later data-sheet minimum6 agrees with the guide summary6/9, while
# the instruction entry prints8/11. RUN-low emulation duration is separate.
CHOICES['EMU',signature(dict(summary_cpu=6,summary_cd=9,entry_cpu=8,entry_cd=11,
    datasheet_cpu=6,policy_cpu=6,policy_cd=9))]='emu-run-summary-and-datasheet'


# MMFM's read-only operation conflicts with parenthesized hidden writes;
# preserve both figures and literal CPU/CD, following the owner's fallback.
# Empty lists perform no data access while retaining the printed equations.
for n in range(16):
    for unaligned in (False,True):
        cpu=3+(6 if unaligned else 4)*n
        cd=(13+6*n) if unaligned else (11+4*n)
        values=dict(entry_cpu=cpu,entry_cd=cd,policy_cpu=cpu,policy_cd=cd,
                    entry_hidden=4 if unaligned else 2,policy_hidden=0)
        CHOICES['MMFM',signature(values)]='register-list-read-only-hidden-states'
for hidden in (2,8):
    values=dict(entry_cpu=2,entry_cd=10,policy_cpu=2,policy_cd=10,
                entry_hidden=hidden,policy_hidden=0)
    CHOICES['MMTM',signature(values)]='empty-register-list-no-data-work'


def project_choice(identifier,values,kind):
    if kind=='agreed-published-target-gap':return None
    decision=CHOICES.get((identifier,signature(values)))
    if decision is None:return None
    return dict(decision=decision,authority='project-owner-2026-10-18',
                classification='project-interpretation',official_ti_resolution=False)
