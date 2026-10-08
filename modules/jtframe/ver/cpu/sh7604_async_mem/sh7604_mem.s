    .section .text
    .global _start

    .equ VEC_SP,        0x0000fff0
    .equ BASE,          0x00000010

    .equ STATUS_ADDR,   0x06000000
    .equ STATUS_COPY,   0x00000011
    .equ STATUS_VERIFY, 0x00000022
    .equ STATUS_RMW,    0x00000033
    .equ STATUS_PART,   0x00000044
    .equ STATUS_SCAN,   0x00000055
    .equ STATUS_PASS,   0x00000066
    .equ STATUS_FAIL,   0xdead0001

    .equ SRC_ADDR,      0x00002000
    .equ DST_ADDR,      0x00004000
    .equ RMW_ADDR,      0x00005000
    .equ PART_ADDR,     0x00005010
    .equ SCAN_ADDR,     0x00008000
    .equ COPY_WORDS,    64
    .equ SCAN_WORDS,    2048

    .org 0x00000000
    .long BASE
    .long VEC_SP
    .long BASE
    .long VEC_SP

    .org BASE
_start:
    mov.l lit_status, r14

    mov.l phase_copy, r2
    mov.l r2, @r14
    mov.l lit_src, r0
    mov.l lit_dst, r1
    mov.l lit_copy_words, r6
copy_loop:
    mov.l @r0+, r3
    mov.l r3, @r1
    add #4, r1
    dt r6
    bf copy_loop

    mov.l phase_verify, r2
    mov.l r2, @r14
    mov.l lit_src, r0
    mov.l lit_dst, r1
    mov.l lit_copy_words, r6
verify_loop:
    mov.l @r0+, r3
    mov.l @r1, r4
    cmp/eq r3, r4
    bf fail
    add #4, r1
    dt r6
    bf verify_loop

    mov.l phase_rmw, r2
    mov.l r2, @r14
    mov.l lit_rmw, r1
    mov.l lit_rmw_seed, r3
    mov.l r3, @r1
    mov.l @r1, r4
    mov #0x3d, r5
    add r5, r4
    mov.l r4, @r1
    mov.l @r1, r3
    mov.l lit_rmw_expected, r4
    cmp/eq r3, r4
    bf fail

    mov.l phase_part, r2
    mov.l r2, @r14
    mov.l lit_part, r1
    mov.l lit_part_seed, r3
    mov.l r3, @r1
    add #2, r1
    mov.w lit_part_word, r3
    mov.w r3, @r1
    add #-1, r1
    mov #0x77, r3
    mov.b r3, @r1
    add #-1, r1
    mov.l @r1, r3
    mov.l lit_part_expected, r4
    cmp/eq r3, r4
    bf fail

    mov.l phase_scan, r2
    mov.l r2, @r14
    mov.l lit_scan, r0
    mov.l lit_scan_words, r6
    mov #0, r7
scan_loop:
    mov.l @r0+, r3
    xor r3, r7
    dt r6
    bf scan_loop
    mov.l lit_scan_xor, r4
    cmp/eq r7, r4
    bf fail

    mov.l phase_pass, r2
    mov.l r2, @r14
done:
    bra done
    nop

fail:
    mov.l phase_fail, r2
    mov.l r2, @r14
fail_loop:
    bra fail_loop
    nop

    .align 4
lit_status:
    .long STATUS_ADDR
lit_src:
    .long SRC_ADDR
lit_dst:
    .long DST_ADDR
lit_rmw:
    .long RMW_ADDR
lit_part:
    .long PART_ADDR
lit_scan:
    .long SCAN_ADDR
lit_copy_words:
    .long COPY_WORDS
lit_scan_words:
    .long SCAN_WORDS
lit_rmw_seed:
    .long 0x13572468
lit_rmw_expected:
    .long 0x135724a5
lit_part_seed:
    .long 0xaabbccdd
lit_part_expected:
    .long 0xaa771122
lit_scan_xor:
    .long 0x001a0000
phase_copy:
    .long STATUS_COPY
phase_verify:
    .long STATUS_VERIFY
phase_rmw:
    .long STATUS_RMW
phase_part:
    .long STATUS_PART
phase_scan:
    .long STATUS_SCAN
phase_pass:
    .long STATUS_PASS
phase_fail:
    .long STATUS_FAIL
lit_part_word:
    .word 0x1122
    .align 4

    .org SRC_ADDR
    .set i, 0
    .rept COPY_WORDS
    .long 0x13570000 + (i * 0x1021) + ((i & 15) << 8) + (i ^ 0x5a)
    .set i, i + 1
    .endr

    .org SCAN_ADDR
    .set i, 0
    .rept SCAN_WORDS
    .set scan_word, 0x24680000 + (i * 0x0101) + ((i & 255) << 4) + (i ^ 0xa5)
    .long scan_word
    .set i, i + 1
    .endr
