/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 31-10-2026 */

    .text
    .globl forgottn_aim
forgottn_aim:
    movem.l %d0-%d5,-(%sp)
    move.w  0x800064,%d0
    cmpi.w  #0x4a55,%d0
    bne.w   .Lrelative
    move.w  0x800060,%d0
    tst.b   0x1f(%a0)
    beq.s   .Lsample
    move.w  0x800062,%d0
.Lsample:
    move.w  %d0,%d1
    ext.w   %d0
    lsr.w   #8,%d1
    ext.w   %d1
    move.w  %d0,%d4
    move.w  %d1,%d5
    tst.w   %d0
    bpl.s   .Lxabs
    neg.w   %d0
.Lxabs:
    tst.w   %d1
    bpl.s   .Lyabs
    neg.w   %d1
.Lyabs:
    moveq   #0,%d2
    move.w  %d0,%d2
    moveq   #0,%d3
    move.w  %d1,%d3
    cmp.w   %d1,%d0
    bcc.s   .Lmajor
    exg     %d2,%d3
.Lmajor:
    cmpi.w  #24,%d2
    bcs.w   .Lreturn
    lsl.w   #8,%d3
    divu.w  %d2,%d3
    moveq   #0,%d2
    cmpi.w  #25,%d3
    bcs.s   .Lsector
    addq.w  #1,%d2
    cmpi.w  #78,%d3
    bcs.s   .Lsector
    addq.w  #1,%d2
    cmpi.w  #137,%d3
    bcs.s   .Lsector
    addq.w  #1,%d2
    cmpi.w  #210,%d3
    bcs.s   .Lsector
    addq.w  #1,%d2
.Lsector:
    cmp.w   %d1,%d0
    bcc.s   .Lquadrant
    neg.w   %d2
    addq.w  #8,%d2
.Lquadrant:
    tst.w   %d4
    bpl.s   .Lyflip
    neg.w   %d2
    addi.w  #16,%d2
.Lyflip:
    tst.w   %d5
    bmi.s   .Langle
    neg.w   %d2
.Langle:
    andi.w  #31,%d2
    lsl.w   #6,%d2
    move.w  %d2,0x28(%a0)
.Lreturn:
    movem.l (%sp)+,%d0-%d5
    move.w  0x28(%a0),%d0
    rts
.Lrelative:
    movem.l (%sp)+,%d0-%d5
    add.w   %d1,0x28(%a0)
    move.w  0x28(%a0),%d0
    rts
