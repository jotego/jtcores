.syntax unified
.arm
.global _start
_start:
    mov r0, #0x300
    mov r1, #0x12
    str r1, [r0]
    ldr r2, [r0]
    cmp r2, r1
    bne fail
    mov r1, #0x34
    strb r1, [r0, #1]
    ldrb r2, [r0, #1]
    cmp r2, r1
    bne fail
    mov r1, #0x11
    mov r2, #0x22
    mov r3, #0x33
    mov r4, #0x44
    add r0, r0, #8
    stmia r0!, {r1-r4}
    sub r0, r0, #16
    mov r1, #0
    mov r2, #0
    mov r3, #0
    mov r4, #0
    ldmia r0!, {r1-r4}
    cmp r1, #0x11
    bne fail
    cmp r2, #0x22
    bne fail
    cmp r3, #0x33
    bne fail
    cmp r4, #0x44
    bne fail
    // Rotated immediate sets C from bit 31; unrotated preserves C.
    movs r1, #0x80000000
    bcc fail
    movs r1, #1
    bcc fail
    movs r1, #0x100
    bcs fail
    // Logical operations preserve an existing overflow flag.
    mov r1, #0x80000000
    subs r2, r1, #1
    bvc fail
    movs r3, #0
    bvc fail
    mov r1, #0x98
    mcr p0, 0, r1, c0, c0, 0
    mov r1, #0x12
    mcr p0, 0, r1, c1, c1, 0
    cmp r1, #0x12
    mcrne p0, 0, r1, c0, c0, 0
    mov r1, #0
    mcreq p0, 0, r1, c2, c2, 0
    mrc p0, 0, r2, c5, c5, 0
    ldr r3, =0x110
    cmp r2, r3
    bne fail
    mov r1, #3
    mcr p0, 0, r1, c2, c2, 0
    mrc p0, 0, r2, c5, c5, 0
    cmp r2, #0x86
    bne fail
    mov r1, #1
    mcr p0, 0, r1, c2, c2, 0
    mrc p0, 0, r2, c5, c5, 0
    ldr r3, =0x1176
    cmp r2, r3
    bne fail
    mov r1, #100
    mcr p0, 0, r1, c0, c0, 0
    mov r1, #7
    mcr p0, 0, r1, c1, c1, 0
    cdp p0, 0, c0, c0, c0, 0
    mrc p0, 0, r2, c3, c3, 0
    cmp r2, #14
    bne fail
    mrc p0, 0, r2, c4, c4, 0
    cmp r2, #2
    bne fail
    ldr pc, load_pc_pointer
    b fail
load_pc_target:
    mov r0, #0x200
    mov r1, #0x5a
    str r1, [r0]
pass:
    b pass
fail:
    mov r0, #0x200
    mov r1, #0xee
    str r1, [r0]
    b fail
load_pc_pointer:
    .word load_pc_target - _start - 2
