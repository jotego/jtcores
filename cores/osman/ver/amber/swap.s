.syntax unified
.arm
.global _start
_start:
    mov r0, #0x100
    mov r1, #0x12
    str r1, [r0]
    mov r1, #0x34
    swp r2, r1, [r0]
    cmp r2, #0x12
    bne fail
    ldr r3, [r0]
    cmp r3, #0x34
    bne fail
    mov r1, #0x56
    swpb r2, r1, [r0]
    cmp r2, #0x34
    bne fail
    ldrb r3, [r0]
    cmp r3, #0x56
    bne fail
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
