    .section .text
    .global _start

    .equ VEC_SP,      0x0000fff0
    .equ BASE,        0x00000400
    .equ DATA_ADDR,   0x00002000
    .equ STATUS_ADDR, 0x06000000
    .equ STATUS_PASS, 0x55aa00ff
    .equ STATUS_CACHE,0x55aa00c3
    .equ STATUS_FAIL, 0xdead0001

    .org 0x00000000
    .long BASE
    .long VEC_SP
    .long BASE
    .long VEC_SP

    .org BASE
_start:
    mov.l lit_410, r13
    mov.l lit_target, r14
    jmp @r14
    nop

    .align 4
lit_410:
    .long 0x00000410
lit_target:
    .long stage1

stage1:
    mov #0x12, r0
    extu.b r0, r1
    shll2 r1
    add #0x34, r1
    mov.l lit_const, r2
    mov r2, r3
    add r1, r3
    mov.l lit_data, r4
    mov.l r3, @r4
    mov.l @r4, r5
    cmp/eq r3, r5
    bf fail
    bsr subroutine
    mov #0x55, r8
return_here:
    mov.l lit_cache_base, r6
    mov.l lit_cache_word0, r7
    mov.l r7, @r6
    add #4, r6
    mov.l lit_cache_word1, r7
    mov.l r7, @r6
    add #4, r6
    mov.l lit_cache_target, r7
    mov.l r7, @r6
    mov.l lit_cache_base, r0
    jmp @r0
    nop
after_cache:
    mov.l lit_chain_addr0, r0
    mov.l lit_chain_word0, r1
    mov.l r1, @r0
    mov.l lit_chain_addr1, r0
    mov.l lit_chain_word1, r1
    mov.l r1, @r0
    mov.l lit_chain_addr2, r0
    mov.l lit_chain_word2, r1
    mov.l r1, @r0
    mov.l lit_chain_addr0, r0
    mov.l @r0, r0
    mov.l @r0, r0
    mov.l @r0, r0
    mov.l lit_status, r14
    mov.l lit_pass, r0
    mov.l r0, @r14
done:
    bra done
    nop

subroutine:
    mov #0x66, r9
    rts
    mov #0x77, r10

fail:
    mov.l lit_status, r14
    mov.l lit_fail, r0
    mov.l r0, @r14
fail_loop:
    bra fail_loop
    nop

    .align 4
lit_const:
    .long 0x12345678
lit_data:
    .long DATA_ADDR
lit_status:
    .long STATUS_ADDR
lit_pass:
    .long STATUS_PASS
lit_fail:
    .long STATUS_FAIL
lit_cache_base:
    .long 0xc0000000
lit_cache_word0:
    .long 0xd001402b  /* mov.l @(1,pc),r0 ; jmp @r0 */
lit_cache_word1:
    .long 0x00090009  /* nop ; nop */
lit_cache_target:
    .long cache_target
lit_cache_status:
    .long STATUS_CACHE
lit_chain_addr0:
    .long 0x00000010
lit_chain_addr1:
    .long 0x00002034
lit_chain_addr2:
    .long 0x00002398
lit_chain_word0:
    .long 0x00002034
lit_chain_word1:
    .long 0x00002398
lit_chain_word2:
    .long 0x00002394

    .org 0x00000544
cache_target:
    mov.l lit_status_544, r14
    mov.l lit_cache_status_544, r0
    mov.l r0, @r14
    mov.l lit_after_cache_544, r0
    jmp @r0
    nop

    .align 4
lit_status_544:
    .long STATUS_ADDR
lit_cache_status_544:
    .long STATUS_CACHE
lit_after_cache_544:
    .long after_cache

    .org DATA_ADDR
    .long 0x00000000
