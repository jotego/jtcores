    .section .text

    .equ STACK_TOP,     0x0207fff0
    .equ START_ADDR,    0x00000400
    .equ BCR2_ADDR,     0xffffffe4
    .equ BCR2_VALUE,    0xa55a00e8

    .equ PAL_BASE,      0x04080000
    .equ SSMAP_BASE,    0x05040000
    .equ SSCHAR_BASE,   0x05048000
    .equ SSREG_BASE,    0x05050000
    .equ SS_PAL_BASE,   SSREG_BASE + 0x24
    .equ INPUT_BASE,    0x05000000
    .equ DIP_BASE,      0x05000a00
    .equ VBL_ACK,       0x05100000
    .equ MAINRAM_BASE,  0x02000000
    .equ MAINRAM_WORDS, 0x00020000
    .equ FLASH1_BASE,   0x06000000
    .equ GFXFLASH_BASE, 0x04200000
    .equ GFXBANK_REG,   0x040c0088
    .equ RESULT_BASE,   0x02070000

    .equ PALH_WHITE,    2
    .equ PALH_RED,      4
    .equ PALH_GREEN,    6
    .equ PALH_BLUE,     8
    .equ PALH_GRAY,     10
    .equ FONT_COUNT,    38

    .org 0x00000000
    .long START_ADDR
    .long STACK_TOP
    .long START_ADDR
    .long STACK_TOP

    .org 0x00000118
    .long vbl_irq_handler

    .org START_ADDR
    .global _start
_start:
    mov.l boot_lit_stack, r15
    mov.l boot_lit_bcr2_addr, r0
    mov.l boot_lit_bcr2_value, r1
    mov.l r1, @r0

    bsr test_full_ram_once
    nop
    mov r0, r8

    bsr clear_results
    nop
    mov.l boot_lit_result_base, r1
    mov.l r8, @(28,r1)
    bsr init_palette
    nop
    bsr init_ss_regs
    nop
    bsr load_font
    nop
    bsr draw_static_screen
    nop
    bsr run_smoke_tests
    nop
    bsr update_live_values
    nop
    bsr enable_vbl_irq
    nop
    mov.l boot_lit_run_simm_crc_tests, r0
    jsr @r0
    nop

main_loop:
    sleep
    bra main_loop
    nop

enable_vbl_irq:
    mov.l boot_lit_vbl_ack, r1
    mov #0, r0
    mov.l r0, @r1
    mov #0, r0
    ldc r0, sr
    rts
    nop

test_full_ram_once:
    mov.l boot_lit_mainram_base, r1
    mov.l boot_lit_mainram_words, r2
    mov.l boot_lit_pat_ram, r3
full_ram_write_loop:
    mov r1, r4
    xor r3, r4
    mov.l r4, @r1
    add #4, r1
    dt r2
    bf full_ram_write_loop

    mov.l boot_lit_mainram_base, r1
    mov.l boot_lit_mainram_words, r2
    mov.l boot_lit_pat_ram, r3
full_ram_verify_loop:
    mov r1, r4
    xor r3, r4
    mov.l @r1, r5
    cmp/eq r4, r5
    bf full_ram_bad
    add #4, r1
    dt r2
    bf full_ram_verify_loop

    mov.l boot_lit_mainram_base, r1
    mov.l boot_lit_mainram_words, r2
    mov #0, r0
full_ram_clear_loop:
    mov.l r0, @r1
    add #4, r1
    dt r2
    bf full_ram_clear_loop
    mov #1, r0
    rts
    nop
full_ram_bad:
    mov #0, r0
    rts
    nop

    .align 4
boot_lit_stack:              .long STACK_TOP
boot_lit_bcr2_addr:          .long BCR2_ADDR
boot_lit_bcr2_value:         .long BCR2_VALUE
boot_lit_vbl_ack:            .long VBL_ACK
boot_lit_run_simm_crc_tests: .long run_simm_crc_tests
boot_lit_mainram_base:       .long MAINRAM_BASE
boot_lit_mainram_words:      .long MAINRAM_WORDS
boot_lit_result_base:        .long RESULT_BASE
boot_lit_pat_ram:            .long 0xa5a55a5a

vbl_irq_handler:
    sts.l pr, @-r15
    mov.l r0, @-r15
    mov.l r1, @-r15
    mov.l r2, @-r15
    mov.l r3, @-r15
    mov.l r4, @-r15
    mov.l r5, @-r15
    mov.l r6, @-r15
    mov.l r7, @-r15
    bsr update_live_values
    nop
    mov.l irq_lit_vbl_ack, r1
    mov #0, r0
    mov.l r0, @r1
    mov.l @r15+, r7
    mov.l @r15+, r6
    mov.l @r15+, r5
    mov.l @r15+, r4
    mov.l @r15+, r3
    mov.l @r15+, r2
    mov.l @r15+, r1
    mov.l @r15+, r0
    lds.l @r15+, pr
    rte
    nop

    .align 4
irq_lit_vbl_ack:             .long VBL_ACK

clear_results:
    mov.l lit_result_base, r1
    mov #0, r0
    mov #14, r6
clear_results_loop:
    mov.l r0, @r1
    add #4, r1
    dt r6
    bf clear_results_loop
    rts
    nop

init_palette:
    mov.l lit_pal_base, r1
    mov #0, r0
    mov.w r0, @r1
    mov.w lit_col_white, r0
    mov.w r0, @(2,r1)

    mov.l lit_pal_attr_white, r1
    mov.w lit_col_white, r0
    mov.w r0, @r1
    mov.l lit_pal_attr_red, r1
    mov.w lit_col_red, r0
    mov.w r0, @r1
    mov.l lit_pal_attr_green, r1
    mov.w lit_col_green, r0
    mov.w r0, @r1
    mov.l lit_pal_attr_blue, r1
    mov.w lit_col_blue, r0
    mov.w r0, @r1
    mov.l lit_pal_attr_gray, r1
    mov.w lit_col_gray, r0
    mov.w r0, @r1
    rts
    nop

    .align 2
lit_col_white:          .word 0x7fff
lit_col_red:            .word 0x001f
lit_col_green:          .word 0x03e0
lit_col_blue:           .word 0x7c00
lit_col_gray:           .word 0x4210

init_ss_regs:
    mov.l lit_ss_pal_base, r1
    mov #0, r0
    mov.b r0, @r1
    rts
    nop

load_font:
    mov.l lit_font_data, r4
    mov.l lit_sschar_glyph1, r5
    mov #FONT_COUNT, r6
glyph_loop:
    mov #8, r7
row_loop:
    mov.b @r4+, r0
    mov.b r0, @r5
    mov.b @r4+, r0
    mov.b r0, @(2,r5)
    mov.b @r4+, r0
    mov.b r0, @(4,r5)
    mov.b @r4+, r0
    mov.b r0, @(6,r5)
    add #8, r5
    dt r7
    bf row_loop
    dt r6
    bf glyph_loop
    rts
    nop

run_smoke_tests:
    mov.l lit_result_base, r14
    mov #4, r0
    mov.l r0, @r14
    mov #0, r13
    mov #0, r12

    mov.l lit_mainram_test, r1
    mov.l lit_pat_5555aaaa, r2
    mov.l r2, @r1
    mov.l @r1, r3
    cmp/eq r2, r3
    bt test_main_pass
    add #1, r12
    mov.l r1, @(12,r14)
    mov.l r2, @(16,r14)
    mov.l r3, @(20,r14)
    bra test_palette_start
    nop
test_main_pass:
    add #1, r13

test_palette_start:
    mov.l lit_pal_test, r1
    mov.l lit_pat_00001234, r2
    mov.l r2, @r1
    mov.l @r1, r3
    cmp/eq r2, r3
    bt test_pal_pass
    add #1, r12
    tst r12, r12
    bf test_ssmap_start
    mov.l r1, @(12,r14)
    mov.l r2, @(16,r14)
    mov.l r3, @(20,r14)
    bra test_ssmap_start
    nop
test_pal_pass:
    add #1, r13

test_ssmap_start:
    mov.l lit_ssmap_test, r1
    mov.l lit_pat_0000002a, r2
    mov.l r2, @r1
    mov.l @r1, r3
    cmp/eq r2, r3
    bt test_ssmap_pass
    add #1, r12
    tst r12, r12
    bf test_dip_start
    mov.l r1, @(12,r14)
    mov.l r2, @(16,r14)
    mov.l r3, @(20,r14)
    bra test_dip_start
    nop
test_ssmap_pass:
    add #1, r13

test_dip_start:
    mov.l lit_dip_base, r1
    mov.l @r1, r3
    mov.l lit_all_ones, r2
    cmp/eq r2, r3
    bt test_dip_pass
    add #1, r12
    tst r12, r12
    bf tests_done
    mov.l r1, @(12,r14)
    mov.l r2, @(16,r14)
    mov.l r3, @(20,r14)
    bra tests_done
    nop
test_dip_pass:
    add #1, r13

tests_done:
    mov.l r13, @(4,r14)
    mov.l r12, @(8,r14)
    rts
    nop

draw_static_screen:
    sts.l pr, @-r15
    bsr clear_screen
    nop
    mov.l lit_str_syscheck, r4
    mov.l lit_pos_r1c2, r5
    mov #PALH_WHITE, r6
    bsr draw_string
    nop
    mov.l lit_str_run, r4
    mov.l lit_pos_r2c2, r5
    mov #PALH_WHITE, r6
    bsr draw_string
    nop
    mov.l lit_str_pass, r4
    mov.l lit_pos_r4c2, r5
    mov #PALH_GREEN, r6
    bsr draw_string
    nop
    mov.l lit_str_fail, r4
    mov.l lit_pos_r5c2, r5
    mov #PALH_RED, r6
    bsr draw_string
    nop
    mov.l lit_str_ram, r4
    mov.l lit_pos_r6c2, r5
    mov #PALH_WHITE, r6
    bsr draw_string
    nop
    mov.l lit_str_joy, r4
    mov.l lit_pos_r7c2, r5
    mov #PALH_WHITE, r6
    bsr draw_string
    nop
    mov.l lit_str_i0, r4
    mov.l lit_pos_r8c2, r5
    mov #PALH_WHITE, r6
    bsr draw_string
    nop
    mov.l lit_str_i1, r4
    mov.l lit_pos_r9c2, r5
    mov #PALH_WHITE, r6
    bsr draw_string
    nop
    mov.l lit_str_i2, r4
    mov.l lit_pos_r10c2, r5
    mov #PALH_WHITE, r6
    bsr draw_string
    nop
    mov.l lit_str_i3, r4
    mov.l lit_pos_r11c2, r5
    mov #PALH_WHITE, r6
    bsr draw_string
    nop
    mov.l lit_str_dip, r4
    mov.l lit_pos_r13c2, r5
    mov #PALH_WHITE, r6
    bsr draw_string
    nop
    mov.l lit_str_dipsel, r4
    mov.l lit_pos_r14c2, r5
    mov #PALH_WHITE, r6
    bsr draw_string
    nop
    mov.l lit_str_red, r4
    mov.l lit_pos_r16c2, r5
    mov #PALH_RED, r6
    bsr draw_string
    nop
    mov.l lit_str_blue, r4
    mov.l lit_pos_r17c2, r5
    mov #PALH_BLUE, r6
    bsr draw_string
    nop
    mov.l lit_str_green, r4
    mov.l lit_pos_r18c2, r5
    mov #PALH_GREEN, r6
    bsr draw_string
    nop
    mov.l lit_str_white, r4
    mov.l lit_pos_r19c2, r5
    mov #PALH_WHITE, r6
    bsr draw_string
    nop
    mov.l lit_str_gray, r4
    mov.l lit_pos_r20c2, r5
    mov #PALH_GRAY, r6
    bsr draw_string
    nop
    mov.l lit_str_simm1, r4
    mov.l lit_pos_r22c2, r5
    mov #PALH_WHITE, r6
    bsr draw_string
    nop
    mov.l lit_str_simm3, r4
    mov.l lit_pos_r23c2, r5
    mov #PALH_WHITE, r6
    bsr draw_string
    nop
    mov.l lit_str_simm4, r4
    mov.l lit_pos_r24c2, r5
    mov #PALH_WHITE, r6
    bsr draw_string
    nop
    mov.l lit_str_simm5, r4
    mov.l lit_pos_r25c2, r5
    mov #PALH_WHITE, r6
    bsr draw_string
    nop
    lds.l @r15+, pr
    rts
    nop

clear_screen:
    mov.l lit_ssmap_base_odd, r5
    mov #0, r0
    mov.l lit_clear_cells, r6
clear_loop:
    mov.b r0, @r5
    mov.b r0, @(2,r5)
    add #4, r5
    dt r6
    bf clear_loop
    rts
    nop

update_live_values:
    sts.l pr, @-r15
    mov.l lit_result_base, r1
    mov.l @(24,r1), r4
    add #1, r4
    mov.l r4, @(24,r1)
    mov.l lit_pos_r2c7, r5
    mov #PALH_WHITE, r6
    bsr draw_hex16
    nop
    mov.l lit_result_base, r1
    mov.l @(4,r1), r4
    mov.l lit_pos_r4c9, r5
    mov #PALH_GREEN, r6
    bsr draw_hex16
    nop
    mov.l lit_result_base, r1
    mov.l @(8,r1), r4
    mov.l lit_pos_r5c9, r5
    mov #PALH_RED, r6
    bsr draw_hex16
    nop
    mov.l lit_result_base, r1
    mov.l @(28,r1), r0
    tst r0, r0
    bt draw_ram_bad
    mov.l lit_str_ok, r4
    mov #PALH_WHITE, r6
    bra draw_ram_status
    nop
draw_ram_bad:
    mov.l lit_str_bad, r4
    mov #PALH_RED, r6
draw_ram_status:
    mov.l lit_pos_r6c7, r5
    bsr draw_string
    nop
    mov.l lit_input_base, r1
    mov.w @r1, r4
    extu.w r4, r4
    mov.l lit_pos_r8c6, r5
    mov #PALH_WHITE, r6
    bsr draw_hex16
    nop
    mov.l lit_input_base_2, r1
    mov.w @r1, r4
    extu.w r4, r4
    mov.l lit_pos_r9c6, r5
    mov #PALH_WHITE, r6
    bsr draw_hex16
    nop
    mov.l lit_input_base_2, r1
    mov.w @r1, r4
    extu.w r4, r4
    not r4, r4
    mov.l lit_mask_007f, r2
    and r2, r4
    mov.l lit_pos_r7c7, r5
    mov #PALH_WHITE, r6
    bsr draw_hex16
    nop
    mov.l lit_input_base_4, r1
    mov.w @r1, r4
    extu.w r4, r4
    mov.l lit_pos_r10c6, r5
    mov #PALH_WHITE, r6
    bsr draw_hex16
    nop
    mov.l lit_input_base_6, r1
    mov.w @r1, r4
    extu.w r4, r4
    mov.l lit_pos_r11c6, r5
    mov #PALH_WHITE, r6
    bsr draw_hex16
    nop
    mov.l lit_dip_base, r1
    mov.w @r1, r4
    extu.w r4, r4
    mov.l lit_pos_r13c6, r5
    mov #PALH_WHITE, r6
    bsr draw_hex16
    nop
    mov #2, r0
    mov.l lit_pos_r14c10, r5
    mov.b r0, @r5
    mov #PALH_WHITE, r0
    mov.b r0, @(2,r5)

    mov.l lit_result_base, r1
    mov.l @(36,r1), r2
    mov.l @(32,r1), r3
    mov #1, r0
    mov #40, r4
    mov.l lit_pos_r22c9, r5
    bsr draw_status_bit
    nop
    mov #2, r0
    mov #44, r4
    mov.l lit_pos_r23c9, r5
    bsr draw_status_bit
    nop
    mov #4, r0
    mov #48, r4
    mov.l lit_pos_r24c9, r5
    bsr draw_status_bit
    nop
    mov #8, r0
    mov #52, r4
    mov.l lit_pos_r25c9, r5
    bsr draw_status_bit
    nop
    lds.l @r15+, pr
    rts
    nop

draw_status_bit:
    sts.l pr, @-r15
    mov r2, r7
    tst r0, r7
    bt draw_status_blank
    mov r3, r7
    tst r0, r7
    bt draw_status_bad
    mov.l lit_str_ok, r4
    mov #PALH_WHITE, r6
    bra draw_status_write
    nop
draw_status_bad:
    mov r4, r7
    mov.l lit_str_bad, r4
    mov #PALH_RED, r6
    bsr draw_string
    nop
    mov #0, r0
    mov.b r0, @r5
    mov #PALH_RED, r0
    mov.b r0, @(2,r5)
    add #4, r5
    mov.l lit_result_base, r1
    add r7, r1
    mov.l @r1, r4
    mov #PALH_RED, r6
    bsr draw_hex32
    nop
    bra draw_status_done
    nop
draw_status_blank:
    mov.l lit_str_blank3, r4
    mov #PALH_WHITE, r6
draw_status_write:
    bsr draw_string
    nop
draw_status_done:
    lds.l @r15+, pr
    rts
    nop

draw_string:
    mov #-1, r1
draw_string_loop:
    mov.b @r4+, r0
    cmp/eq r1, r0
    bt draw_string_done
    mov.b r0, @r5
    mov r6, r0
    mov.b r0, @(2,r5)
    add #4, r5
    bra draw_string_loop
    nop
draw_string_done:
    rts
    nop

draw_hex32:
    sts.l pr, @-r15
    mov.l r4, @-r15
    shlr8 r4
    shlr8 r4
    bsr draw_hex16
    nop
    mov.l @r15+, r4
    bsr draw_hex16
    nop
    lds.l @r15+, pr
    rts
    nop

draw_hex16:
    sts.l pr, @-r15
    mov r4, r7
    mov r4, r0
    shlr8 r0
    shlr2 r0
    shlr2 r0
    bsr draw_hex_nibble
    nop
    mov r7, r0
    shlr8 r0
    bsr draw_hex_nibble
    nop
    mov r7, r0
    shlr2 r0
    shlr2 r0
    bsr draw_hex_nibble
    nop
    mov r7, r0
    bsr draw_hex_nibble
    nop
    lds.l @r15+, pr
    rts
    nop

draw_hex_nibble:
    and #0x0f, r0
    add #1, r0
    mov.b r0, @r5
    mov r6, r0
    mov.b r0, @(2,r5)
    add #4, r5
    rts
    nop

    .align 4
lit_stack:              .long STACK_TOP
lit_bcr2_addr:          .long BCR2_ADDR
lit_bcr2_value:         .long BCR2_VALUE
lit_vbl_ack:            .long VBL_ACK
lit_run_simm_crc_tests: .long run_simm_crc_tests
lit_mainram_base:       .long MAINRAM_BASE
lit_mainram_words:      .long MAINRAM_WORDS
lit_result_base:        .long RESULT_BASE
lit_pal_base:           .long PAL_BASE
lit_pal_attr_white:     .long PAL_BASE + (((PALH_WHITE >> 1) * 16 + 1) * 2)
lit_pal_attr_red:       .long PAL_BASE + (((PALH_RED >> 1) * 16 + 1) * 2)
lit_pal_attr_green:     .long PAL_BASE + (((PALH_GREEN >> 1) * 16 + 1) * 2)
lit_pal_attr_blue:      .long PAL_BASE + (((PALH_BLUE >> 1) * 16 + 1) * 2)
lit_pal_attr_gray:      .long PAL_BASE + (((PALH_GRAY >> 1) * 16 + 1) * 2)
lit_ss_pal_base:        .long SS_PAL_BASE + 1
lit_sschar_glyph1:      .long SSCHAR_BASE + 64 + 1
lit_font_data:          .long font_data
lit_mainram_test:       .long 0x02001000
lit_pal_test:           .long PAL_BASE + 0x100
lit_ssmap_test:         .long SSMAP_BASE + 0x100
lit_dip_base:           .long DIP_BASE
lit_input_base:         .long INPUT_BASE
lit_input_base_2:       .long INPUT_BASE + 2
lit_input_base_4:       .long INPUT_BASE + 4
lit_input_base_6:       .long INPUT_BASE + 6
lit_ssmap_base_odd:     .long SSMAP_BASE + 1
lit_clear_cells:        .long 2048
lit_pat_5555aaaa:       .long 0x5555aaaa
lit_pat_ram:            .long 0xa5a55a5a
lit_pat_00001234:       .long 0x00001234
lit_pat_0000002a:       .long 0x0000002a
lit_all_ones:           .long 0xffffffff
lit_mask_007f:          .long 0x0000007f

    .align 4
    .macro POS name, row, col
lit_pos_\name: .long SSMAP_BASE + ((\row) * 64 + (\col)) * 4 + 1
    .endm
    POS r1c2, 1, 2
    POS r2c2, 2, 2
    POS r2c7, 2, 7
    POS r4c2, 4, 2
    POS r4c9, 4, 9
    POS r5c2, 5, 2
    POS r5c9, 5, 9
    POS r6c2, 6, 2
    POS r6c7, 6, 7
    POS r7c2, 7, 2
    POS r7c7, 7, 7
    POS r8c2, 8, 2
    POS r8c6, 8, 6
    POS r9c2, 9, 2
    POS r9c6, 9, 6
    POS r10c2, 10, 2
    POS r10c6, 10, 6
    POS r11c2, 11, 2
    POS r11c6, 11, 6
    POS r13c2, 13, 2
    POS r13c6, 13, 6
    POS r14c2, 14, 2
    POS r14c10, 14, 10
    POS r16c2, 16, 2
    POS r17c2, 17, 2
    POS r18c2, 18, 2
    POS r19c2, 19, 2
    POS r20c2, 20, 2
    POS r22c2, 22, 2
    POS r22c9, 22, 9
    POS r23c2, 23, 2
    POS r23c9, 23, 9
    POS r24c2, 24, 2
    POS r24c9, 24, 9
    POS r25c2, 25, 2
    POS r25c9, 25, 9

    .macro CSTR name, chars:vararg
lit_str_\name: .long str_\name
str_\name: .byte \chars, -1
    .align 2
    .endm

    CSTR syscheck, 29,35,29,0,13,18,15,13,21
    CSTR run, 28,31,24,37
    CSTR pass, 26,11,29,29,37
    CSTR fail, 16,11,19,22,37
    CSTR ram, 28,11,23,37
    CSTR ok, 25,21,0
    CSTR bad, 12,11,14
    CSTR blank3, 0,0,0
    CSTR joy, 20,25,35,37
    CSTR i0, 19,1,37
    CSTR i1, 19,2,37
    CSTR i2, 19,3,37
    CSTR i3, 19,4,37
    CSTR dip, 14,19,26,37
    CSTR dipsel, 14,19,26,29,15,22,37
    CSTR red, 28,15,14
    CSTR blue, 12,22,31,15
    CSTR green, 17,28,15,15,24
    CSTR white, 33,18,19,30,15
    CSTR gray, 17,28,11,35
    CSTR simm1, 29,19,23,23,2,37
    CSTR simm3, 29,19,23,23,4,37
    CSTR simm4, 29,19,23,23,5,37
    CSTR simm5, 29,19,23,23,6,37

    .macro row bits
    .byte (((\bits >> 7) & 1) << 4) | ((\bits >> 6) & 1)
    .byte (((\bits >> 5) & 1) << 4) | ((\bits >> 4) & 1)
    .byte (((\bits >> 3) & 1) << 4) | ((\bits >> 2) & 1)
    .byte (((\bits >> 1) & 1) << 4) | ((\bits >> 0) & 1)
    .endm
    .macro glyph r0,r1,r2,r3,r4,r5,r6,r7
    row \r0
    row \r1
    row \r2
    row \r3
    row \r4
    row \r5
    row \r6
    row \r7
    .endm

    .align 4
font_data:
    /* SS character pixels are stored low nibble first in each byte. */
    /* 1: 0 */
    .byte 0x10, 0x11, 0x00, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x10, 0x01, 0x00
    .byte 0x01, 0x01, 0x01, 0x00
    .byte 0x11, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x10, 0x11, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    /* 2: 1 */
    .byte 0x00, 0x01, 0x00, 0x00
    .byte 0x10, 0x01, 0x00, 0x00
    .byte 0x00, 0x01, 0x00, 0x00
    .byte 0x00, 0x01, 0x00, 0x00
    .byte 0x00, 0x01, 0x00, 0x00
    .byte 0x00, 0x01, 0x00, 0x00
    .byte 0x10, 0x11, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    /* 3: 2 */
    .byte 0x10, 0x11, 0x00, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x00, 0x00, 0x01, 0x00
    .byte 0x00, 0x10, 0x00, 0x00
    .byte 0x00, 0x01, 0x00, 0x00
    .byte 0x10, 0x00, 0x00, 0x00
    .byte 0x11, 0x11, 0x01, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    /* 4: 3 */
    .byte 0x10, 0x11, 0x00, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x00, 0x00, 0x01, 0x00
    .byte 0x00, 0x11, 0x00, 0x00
    .byte 0x00, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x10, 0x11, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    /* 5: 4 */
    .byte 0x00, 0x10, 0x00, 0x00
    .byte 0x00, 0x11, 0x00, 0x00
    .byte 0x10, 0x10, 0x00, 0x00
    .byte 0x01, 0x10, 0x00, 0x00
    .byte 0x11, 0x11, 0x01, 0x00
    .byte 0x00, 0x10, 0x00, 0x00
    .byte 0x00, 0x10, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    /* 6: 5 */
    .byte 0x11, 0x11, 0x01, 0x00
    .byte 0x01, 0x00, 0x00, 0x00
    .byte 0x11, 0x11, 0x00, 0x00
    .byte 0x00, 0x00, 0x01, 0x00
    .byte 0x00, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x10, 0x11, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    /* 7: 6 */
    .byte 0x10, 0x11, 0x00, 0x00
    .byte 0x01, 0x00, 0x00, 0x00
    .byte 0x01, 0x00, 0x00, 0x00
    .byte 0x11, 0x11, 0x00, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x10, 0x11, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    /* 8: 7 */
    .byte 0x11, 0x11, 0x01, 0x00
    .byte 0x00, 0x00, 0x01, 0x00
    .byte 0x00, 0x10, 0x00, 0x00
    .byte 0x00, 0x01, 0x00, 0x00
    .byte 0x10, 0x00, 0x00, 0x00
    .byte 0x10, 0x00, 0x00, 0x00
    .byte 0x10, 0x00, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    /* 9: 8 */
    .byte 0x10, 0x11, 0x00, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x10, 0x11, 0x00, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x10, 0x11, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    /* 10: 9 */
    .byte 0x10, 0x11, 0x00, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x10, 0x11, 0x01, 0x00
    .byte 0x00, 0x00, 0x01, 0x00
    .byte 0x00, 0x00, 0x01, 0x00
    .byte 0x10, 0x11, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    /* 11: A */
    .byte 0x10, 0x11, 0x00, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x11, 0x11, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    /* 12: B */
    .byte 0x11, 0x11, 0x00, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x11, 0x11, 0x00, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x11, 0x11, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    /* 13: C */
    .byte 0x10, 0x11, 0x01, 0x00
    .byte 0x01, 0x00, 0x00, 0x00
    .byte 0x01, 0x00, 0x00, 0x00
    .byte 0x01, 0x00, 0x00, 0x00
    .byte 0x01, 0x00, 0x00, 0x00
    .byte 0x01, 0x00, 0x00, 0x00
    .byte 0x10, 0x11, 0x01, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    /* 14: D */
    .byte 0x11, 0x11, 0x00, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x11, 0x11, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    /* 15: E */
    .byte 0x11, 0x11, 0x01, 0x00
    .byte 0x01, 0x00, 0x00, 0x00
    .byte 0x01, 0x00, 0x00, 0x00
    .byte 0x11, 0x11, 0x00, 0x00
    .byte 0x01, 0x00, 0x00, 0x00
    .byte 0x01, 0x00, 0x00, 0x00
    .byte 0x11, 0x11, 0x01, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    /* 16: F */
    .byte 0x11, 0x11, 0x01, 0x00
    .byte 0x01, 0x00, 0x00, 0x00
    .byte 0x01, 0x00, 0x00, 0x00
    .byte 0x11, 0x11, 0x00, 0x00
    .byte 0x01, 0x00, 0x00, 0x00
    .byte 0x01, 0x00, 0x00, 0x00
    .byte 0x01, 0x00, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    /* 17: G */
    .byte 0x10, 0x11, 0x01, 0x00
    .byte 0x01, 0x00, 0x00, 0x00
    .byte 0x01, 0x00, 0x00, 0x00
    .byte 0x01, 0x10, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x10, 0x11, 0x01, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    /* 18: H */
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x11, 0x11, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    /* 19: I */
    .byte 0x11, 0x11, 0x01, 0x00
    .byte 0x00, 0x01, 0x00, 0x00
    .byte 0x00, 0x01, 0x00, 0x00
    .byte 0x00, 0x01, 0x00, 0x00
    .byte 0x00, 0x01, 0x00, 0x00
    .byte 0x00, 0x01, 0x00, 0x00
    .byte 0x11, 0x11, 0x01, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    /* 20: J */
    .byte 0x00, 0x11, 0x01, 0x00
    .byte 0x00, 0x10, 0x00, 0x00
    .byte 0x00, 0x10, 0x00, 0x00
    .byte 0x00, 0x10, 0x00, 0x00
    .byte 0x00, 0x10, 0x00, 0x00
    .byte 0x01, 0x10, 0x00, 0x00
    .byte 0x10, 0x01, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    /* 21: K */
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x10, 0x00, 0x00
    .byte 0x01, 0x01, 0x00, 0x00
    .byte 0x11, 0x00, 0x00, 0x00
    .byte 0x01, 0x01, 0x00, 0x00
    .byte 0x01, 0x10, 0x00, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    /* 22: L */
    .byte 0x01, 0x00, 0x00, 0x00
    .byte 0x01, 0x00, 0x00, 0x00
    .byte 0x01, 0x00, 0x00, 0x00
    .byte 0x01, 0x00, 0x00, 0x00
    .byte 0x01, 0x00, 0x00, 0x00
    .byte 0x01, 0x00, 0x00, 0x00
    .byte 0x11, 0x11, 0x01, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    /* 23: M */
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x11, 0x10, 0x01, 0x00
    .byte 0x01, 0x01, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    /* 24: N */
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x11, 0x00, 0x01, 0x00
    .byte 0x11, 0x00, 0x01, 0x00
    .byte 0x01, 0x01, 0x01, 0x00
    .byte 0x01, 0x10, 0x01, 0x00
    .byte 0x01, 0x10, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    /* 25: O */
    .byte 0x10, 0x11, 0x00, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x10, 0x11, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    /* 26: P */
    .byte 0x11, 0x11, 0x00, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x11, 0x11, 0x00, 0x00
    .byte 0x01, 0x00, 0x00, 0x00
    .byte 0x01, 0x00, 0x00, 0x00
    .byte 0x01, 0x00, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    /* 27: Q */
    .byte 0x10, 0x11, 0x00, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x01, 0x01, 0x00
    .byte 0x01, 0x10, 0x00, 0x00
    .byte 0x10, 0x01, 0x01, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    /* 28: R */
    .byte 0x11, 0x11, 0x00, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x11, 0x11, 0x00, 0x00
    .byte 0x01, 0x01, 0x00, 0x00
    .byte 0x01, 0x10, 0x00, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    /* 29: S */
    .byte 0x10, 0x11, 0x01, 0x00
    .byte 0x01, 0x00, 0x00, 0x00
    .byte 0x01, 0x00, 0x00, 0x00
    .byte 0x10, 0x11, 0x00, 0x00
    .byte 0x00, 0x00, 0x01, 0x00
    .byte 0x00, 0x00, 0x01, 0x00
    .byte 0x11, 0x11, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    /* 30: T */
    .byte 0x11, 0x11, 0x01, 0x00
    .byte 0x00, 0x01, 0x00, 0x00
    .byte 0x00, 0x01, 0x00, 0x00
    .byte 0x00, 0x01, 0x00, 0x00
    .byte 0x00, 0x01, 0x00, 0x00
    .byte 0x00, 0x01, 0x00, 0x00
    .byte 0x00, 0x01, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    /* 31: U */
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x10, 0x11, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    /* 32: V */
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x10, 0x10, 0x00, 0x00
    .byte 0x00, 0x01, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    /* 33: W */
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x01, 0x01, 0x00
    .byte 0x01, 0x01, 0x01, 0x00
    .byte 0x11, 0x10, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    /* 34: X */
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x10, 0x10, 0x00, 0x00
    .byte 0x00, 0x01, 0x00, 0x00
    .byte 0x10, 0x10, 0x00, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    /* 35: Y */
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x01, 0x00, 0x01, 0x00
    .byte 0x10, 0x10, 0x00, 0x00
    .byte 0x00, 0x01, 0x00, 0x00
    .byte 0x00, 0x01, 0x00, 0x00
    .byte 0x00, 0x01, 0x00, 0x00
    .byte 0x00, 0x01, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    /* 36: Z */
    .byte 0x11, 0x11, 0x01, 0x00
    .byte 0x00, 0x00, 0x01, 0x00
    .byte 0x00, 0x10, 0x00, 0x00
    .byte 0x00, 0x01, 0x00, 0x00
    .byte 0x10, 0x00, 0x00, 0x00
    .byte 0x01, 0x00, 0x00, 0x00
    .byte 0x11, 0x11, 0x01, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    /* 37: : */
    .byte 0x00, 0x00, 0x00, 0x00
    .byte 0x00, 0x01, 0x00, 0x00
    .byte 0x00, 0x01, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    .byte 0x00, 0x01, 0x00, 0x00
    .byte 0x00, 0x01, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    /* 38: - */
    .byte 0x00, 0x00, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    .byte 0x11, 0x11, 0x01, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00

    .align 4
run_simm_crc_tests:
    sts.l pr, @-r15
    mov.l crc_lit_result_base, r1
    mov.l @r1, r0
    add #4, r0
    mov.l r0, @r1

    mov.l crc_lit_flash1_base, r8
    mov.l crc_lit_simm1_words, r9
    mov.l crc_lit_crc_init, r10
    mov.l crc_lit_crc32_table, r11
    bsr crc32_words
    nop
    not r10, r2
    mov.l crc_lit_exp_simm1, r3
    mov #1, r4
    mov #40, r5
    bsr record_simm_crc_result
    nop

    mov #2, r12
    mov #8, r14
    bsr crc32_gfx_banks
    nop
    mov r0, r2
    mov.l crc_lit_exp_simm3, r3
    mov #2, r4
    mov #44, r5
    bsr record_simm_crc_result
    nop

    mov #10, r12
    mov #8, r14
    bsr crc32_gfx_banks
    nop
    mov r0, r2
    mov.l crc_lit_exp_simm4, r3
    mov #4, r4
    mov #48, r5
    bsr record_simm_crc_result
    nop

    mov #18, r12
    mov #2, r14
    bsr crc32_gfx_banks
    nop
    mov r0, r2
    mov.l crc_lit_exp_simm5, r3
    mov #8, r4
    mov #52, r5
    bsr record_simm_crc_result
    nop

    lds.l @r15+, pr
    rts
    nop

crc32_gfx_banks:
    sts.l pr, @-r15
    mov.l crc_lit_crc_init, r10
    mov.l crc_lit_crc32_table, r11
crc32_gfx_bank_loop:
    mov.l crc_lit_gfxbank_reg, r1
    mov.w r12, @r1
    nop
    nop
    mov.l crc_lit_gfxflash_base, r8
    mov.l crc_lit_gfxflash_bank_halfwords, r9
    bsr crc32_halfwords
    nop
    add #1, r12
    dt r14
    bf crc32_gfx_bank_loop
    not r10, r0
    lds.l @r15+, pr
    rts
    nop

crc32_halfwords:
    sts.l pr, @-r15
crc32_halfword_loop:
    mov.w @r8, r6
    extu.w r6, r6
    add #2, r8

    mov r6, r4
    shlr8 r4
    bsr crc32_byte
    nop

    mov r6, r4
    bsr crc32_byte
    nop

    dt r9
    bf crc32_halfword_loop
    lds.l @r15+, pr
    rts
    nop

crc32_words:
    sts.l pr, @-r15
crc32_word_loop:
    mov.l @r8, r6
    add #4, r8

    mov r6, r4
    shlr8 r4
    shlr8 r4
    shlr8 r4
    bsr crc32_byte
    nop

    mov r6, r4
    shlr8 r4
    shlr8 r4
    bsr crc32_byte
    nop

    mov r6, r4
    shlr8 r4
    bsr crc32_byte
    nop

    mov r6, r4
    bsr crc32_byte
    nop

    dt r9
    bf crc32_word_loop
    lds.l @r15+, pr
    rts
    nop

crc32_byte:
    extu.b r4, r4
    xor r10, r4
    extu.b r4, r4
    shll2 r4
    add r11, r4
    mov.l @r4, r5
    shlr8 r10
    xor r5, r10
    rts
    nop

record_simm_crc_result:
    mov.l crc_lit_result_base, r1
    mov r1, r0
    add r5, r0
    mov.l r2, @r0
    cmp/eq r3, r2
    bt record_simm_crc_pass
    mov.l @(8,r1), r0
    add #1, r0
    mov.l r0, @(8,r1)
    bra record_simm_crc_done
    nop
record_simm_crc_pass:
    mov.l @(4,r1), r0
    add #1, r0
    mov.l r0, @(4,r1)
    mov.l @(32,r1), r0
    or r4, r0
    mov.l r0, @(32,r1)
record_simm_crc_done:
    mov.l @(36,r1), r0
    or r4, r0
    mov.l r0, @(36,r1)
    rts
    nop


    .align 4
crc_lit_result_base:        .long RESULT_BASE
crc_lit_flash1_base:        .long FLASH1_BASE
crc_lit_simm1_words:        .long 0x00200000
crc_lit_gfxflash_base:      .long GFXFLASH_BASE
crc_lit_gfxflash_bank_halfwords:.long 0x00100000
crc_lit_gfxbank_reg:        .long GFXBANK_REG
crc_lit_crc_init:           .long 0xffffffff
crc_lit_crc32_table:        .long crc32_table
crc_lit_exp_simm1:          .long 0x7aa8ab35
crc_lit_exp_simm3:          .long 0x0b1e3015
crc_lit_exp_simm4:          .long 0xe012fa06
crc_lit_exp_simm5:          .long 0x58933dc2

    .align 4
crc32_table:
    .long 0x00000000
    .long 0x77073096
    .long 0xee0e612c
    .long 0x990951ba
    .long 0x076dc419
    .long 0x706af48f
    .long 0xe963a535
    .long 0x9e6495a3
    .long 0x0edb8832
    .long 0x79dcb8a4
    .long 0xe0d5e91e
    .long 0x97d2d988
    .long 0x09b64c2b
    .long 0x7eb17cbd
    .long 0xe7b82d07
    .long 0x90bf1d91
    .long 0x1db71064
    .long 0x6ab020f2
    .long 0xf3b97148
    .long 0x84be41de
    .long 0x1adad47d
    .long 0x6ddde4eb
    .long 0xf4d4b551
    .long 0x83d385c7
    .long 0x136c9856
    .long 0x646ba8c0
    .long 0xfd62f97a
    .long 0x8a65c9ec
    .long 0x14015c4f
    .long 0x63066cd9
    .long 0xfa0f3d63
    .long 0x8d080df5
    .long 0x3b6e20c8
    .long 0x4c69105e
    .long 0xd56041e4
    .long 0xa2677172
    .long 0x3c03e4d1
    .long 0x4b04d447
    .long 0xd20d85fd
    .long 0xa50ab56b
    .long 0x35b5a8fa
    .long 0x42b2986c
    .long 0xdbbbc9d6
    .long 0xacbcf940
    .long 0x32d86ce3
    .long 0x45df5c75
    .long 0xdcd60dcf
    .long 0xabd13d59
    .long 0x26d930ac
    .long 0x51de003a
    .long 0xc8d75180
    .long 0xbfd06116
    .long 0x21b4f4b5
    .long 0x56b3c423
    .long 0xcfba9599
    .long 0xb8bda50f
    .long 0x2802b89e
    .long 0x5f058808
    .long 0xc60cd9b2
    .long 0xb10be924
    .long 0x2f6f7c87
    .long 0x58684c11
    .long 0xc1611dab
    .long 0xb6662d3d
    .long 0x76dc4190
    .long 0x01db7106
    .long 0x98d220bc
    .long 0xefd5102a
    .long 0x71b18589
    .long 0x06b6b51f
    .long 0x9fbfe4a5
    .long 0xe8b8d433
    .long 0x7807c9a2
    .long 0x0f00f934
    .long 0x9609a88e
    .long 0xe10e9818
    .long 0x7f6a0dbb
    .long 0x086d3d2d
    .long 0x91646c97
    .long 0xe6635c01
    .long 0x6b6b51f4
    .long 0x1c6c6162
    .long 0x856530d8
    .long 0xf262004e
    .long 0x6c0695ed
    .long 0x1b01a57b
    .long 0x8208f4c1
    .long 0xf50fc457
    .long 0x65b0d9c6
    .long 0x12b7e950
    .long 0x8bbeb8ea
    .long 0xfcb9887c
    .long 0x62dd1ddf
    .long 0x15da2d49
    .long 0x8cd37cf3
    .long 0xfbd44c65
    .long 0x4db26158
    .long 0x3ab551ce
    .long 0xa3bc0074
    .long 0xd4bb30e2
    .long 0x4adfa541
    .long 0x3dd895d7
    .long 0xa4d1c46d
    .long 0xd3d6f4fb
    .long 0x4369e96a
    .long 0x346ed9fc
    .long 0xad678846
    .long 0xda60b8d0
    .long 0x44042d73
    .long 0x33031de5
    .long 0xaa0a4c5f
    .long 0xdd0d7cc9
    .long 0x5005713c
    .long 0x270241aa
    .long 0xbe0b1010
    .long 0xc90c2086
    .long 0x5768b525
    .long 0x206f85b3
    .long 0xb966d409
    .long 0xce61e49f
    .long 0x5edef90e
    .long 0x29d9c998
    .long 0xb0d09822
    .long 0xc7d7a8b4
    .long 0x59b33d17
    .long 0x2eb40d81
    .long 0xb7bd5c3b
    .long 0xc0ba6cad
    .long 0xedb88320
    .long 0x9abfb3b6
    .long 0x03b6e20c
    .long 0x74b1d29a
    .long 0xead54739
    .long 0x9dd277af
    .long 0x04db2615
    .long 0x73dc1683
    .long 0xe3630b12
    .long 0x94643b84
    .long 0x0d6d6a3e
    .long 0x7a6a5aa8
    .long 0xe40ecf0b
    .long 0x9309ff9d
    .long 0x0a00ae27
    .long 0x7d079eb1
    .long 0xf00f9344
    .long 0x8708a3d2
    .long 0x1e01f268
    .long 0x6906c2fe
    .long 0xf762575d
    .long 0x806567cb
    .long 0x196c3671
    .long 0x6e6b06e7
    .long 0xfed41b76
    .long 0x89d32be0
    .long 0x10da7a5a
    .long 0x67dd4acc
    .long 0xf9b9df6f
    .long 0x8ebeeff9
    .long 0x17b7be43
    .long 0x60b08ed5
    .long 0xd6d6a3e8
    .long 0xa1d1937e
    .long 0x38d8c2c4
    .long 0x4fdff252
    .long 0xd1bb67f1
    .long 0xa6bc5767
    .long 0x3fb506dd
    .long 0x48b2364b
    .long 0xd80d2bda
    .long 0xaf0a1b4c
    .long 0x36034af6
    .long 0x41047a60
    .long 0xdf60efc3
    .long 0xa867df55
    .long 0x316e8eef
    .long 0x4669be79
    .long 0xcb61b38c
    .long 0xbc66831a
    .long 0x256fd2a0
    .long 0x5268e236
    .long 0xcc0c7795
    .long 0xbb0b4703
    .long 0x220216b9
    .long 0x5505262f
    .long 0xc5ba3bbe
    .long 0xb2bd0b28
    .long 0x2bb45a92
    .long 0x5cb36a04
    .long 0xc2d7ffa7
    .long 0xb5d0cf31
    .long 0x2cd99e8b
    .long 0x5bdeae1d
    .long 0x9b64c2b0
    .long 0xec63f226
    .long 0x756aa39c
    .long 0x026d930a
    .long 0x9c0906a9
    .long 0xeb0e363f
    .long 0x72076785
    .long 0x05005713
    .long 0x95bf4a82
    .long 0xe2b87a14
    .long 0x7bb12bae
    .long 0x0cb61b38
    .long 0x92d28e9b
    .long 0xe5d5be0d
    .long 0x7cdcefb7
    .long 0x0bdbdf21
    .long 0x86d3d2d4
    .long 0xf1d4e242
    .long 0x68ddb3f8
    .long 0x1fda836e
    .long 0x81be16cd
    .long 0xf6b9265b
    .long 0x6fb077e1
    .long 0x18b74777
    .long 0x88085ae6
    .long 0xff0f6a70
    .long 0x66063bca
    .long 0x11010b5c
    .long 0x8f659eff
    .long 0xf862ae69
    .long 0x616bffd3
    .long 0x166ccf45
    .long 0xa00ae278
    .long 0xd70dd2ee
    .long 0x4e048354
    .long 0x3903b3c2
    .long 0xa7672661
    .long 0xd06016f7
    .long 0x4969474d
    .long 0x3e6e77db
    .long 0xaed16a4a
    .long 0xd9d65adc
    .long 0x40df0b66
    .long 0x37d83bf0
    .long 0xa9bcae53
    .long 0xdebb9ec5
    .long 0x47b2cf7f
    .long 0x30b5ffe9
    .long 0xbdbdf21c
    .long 0xcabac28a
    .long 0x53b39330
    .long 0x24b4a3a6
    .long 0xbad03605
    .long 0xcdd70693
    .long 0x54de5729
    .long 0x23d967bf
    .long 0xb3667a2e
    .long 0xc4614ab8
    .long 0x5d681b02
    .long 0x2a6f2b94
    .long 0xb40bbe37
    .long 0xc30c8ea1
    .long 0x5a05df1b
    .long 0x2d02ef8d

