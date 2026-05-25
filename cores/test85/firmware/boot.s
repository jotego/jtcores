; 65C02 boot program for TEST85.
; The main CPU loop validates the downloaded SDRAM payload first, then
; destructively tags the full 64MB SDRAM area and continuously checks random
; 128-byte pages. The IRQ handler is only responsible for blanking-time display
; updates.

        cpu     65c02

TEXT    =       $2000
CL0     =       $2000
CL1     =       $2100
CL2     =       $2200
CL3     =       $2300
ROW_TITLE =     TEXT+$000
ROW_ROM =       TEXT+$040
ROW_FILL =      TEXT+$080
ROW_CHECK =     TEXT+$0c0
ROW_FAIL =      TEXT+$100
ROW_FAIL2 =     TEXT+$120

REGAL   =       $3000
REGAH   =       $3001
REGAB   =       $3002
REGDATA =       $3003
REGCMD  =       $3004
REGVBL  =       $3005
REGAX   =       $3006

STAGE_ROM =     $00
STAGE_FILL =    $01
STAGE_CHECK =   $02
STAGE_FAIL =    $03

FAIL_ROM =      $01
FAIL_FILL =     $02
FAIL_CHECK =    $03

STAGE   =       $00
INIT    =       $01
FAILED  =       $02
FAILK   =       $03
ROMIDX  =       $04
ADDR0   =       $05
ADDR1   =       $06
ADDR2   =       $07
ADDR3   =       $08
PAGE0   =       $09
PAGE1   =       $0a
PAGE2   =       $0b
RAND0   =       $0c
RAND1   =       $0d
RAND2   =       $0e
CHECK0  =       $0f
CHECK1  =       $10
CHECK2  =       $11
CHECK3  =       $12
READ0   =       $13
READ1   =       $14
READ2   =       $15
EXP0    =       $16
EXP1    =       $17
EXP2    =       $18
FADDR0  =       $19
FADDR1  =       $1a
FADDR2  =       $1b
FADDR3  =       $1c
FREAD0  =       $1d
FREAD1  =       $1e
FREAD2  =       $1f
FEXP0   =       $20
FEXP1   =       $21
FEXP2   =       $22
HEXHI   =       $23
HEXLO   =       $24
TMP0    =       $25
TMP1    =       $26
TMP2    =       $27
ROMOK   =       $28
FILL0   =       $29
FILL1   =       $2a
FILL2   =       $2b
FILL3   =       $2c

        org     $c000

reset:
        sei
        cld
        ldx     #$ff
        txs
        lda     #$00
        ldx     #$2c
clear_zp:
        sta     $00,x
        dex
        bpl     clear_zp
        lda     #$5a
        sta     RAND0
        lda     #$c3
        sta     RAND1
        lda     #$01
        sta     RAND2
        lda     REGVBL
        cli

        jsr     test_rom
        bcc     reset_rom_ok
        jsr     test_reusable_tags
        bcs     main_stop
        lda     #$02
        bra     reset_rom_done
reset_rom_ok:
        lda     #$01
reset_rom_done:
        sta     ROMOK
        lda     #STAGE_FILL
        sta     STAGE

        jsr     fill_sdram
        bcs     main_stop
        jsr     save_fill_done_addr
        jsr     evict_cache_after_fill
        bcs     main_stop
        lda     #STAGE_CHECK
        sta     STAGE

check_forever:
        jsr     check_random_tag
        bcs     main_stop
        jsr     inc_check_count
        bra     check_forever

main_stop:
        lda     #STAGE_FAIL
        sta     STAGE
        lda     #$01
        sta     FAILED
halt:
        bra     halt

irq:
        pha
        phx
        phy
        lda     REGVBL
        jsr     wait_blank
        lda     INIT
        bne     irq_update
        jsr     init_screen
        lda     #$01
        sta     INIT
irq_update:
        jsr     update_screen
        ply
        plx
        pla
        rti

init_screen:
        ldx     #$00
clear_screen:
        lda     #$20
        sta     CL0,x
        sta     CL1,x
        sta     CL2,x
        sta     CL3,x
        inx
        bne     clear_screen

        ldx     #$00
title_loop:
        lda     title_msg,x
        beq     init_done
        sta     ROW_TITLE,x
        inx
        bne     title_loop
init_done:
        rts

update_screen:
        jsr     print_rom_row
        jsr     print_fill_row
        jsr     print_check_row
        lda     FAILED
        beq     update_done
        jsr     print_fail_rows
update_done:
        rts

test_rom:
        lda     #STAGE_ROM
        sta     STAGE
        lda     #$00
        sta     ROMIDX
rom_loop:
        lda     ROMIDX
        sta     REGAL
        lda     #$00
        sta     REGAH
        sta     REGAB
        sta     REGAX
        jsr     cache_read
        bcs     rom_timeout
        sta     READ0
        ldx     ROMIDX
        cmp     rom_payload,x
        bne     rom_mismatch
        inc     ROMIDX
        lda     ROMIDX
        cmp     #ROM_LEN
        bne     rom_loop
        clc
        rts

rom_timeout:
        lda     #$00
        sta     READ0
rom_mismatch:
        lda     #FAIL_ROM
        sta     FAILK
        lda     ROMIDX
        sta     FADDR0
        lda     #$00
        sta     FADDR1
        sta     FADDR2
        sta     FADDR3
        ldx     ROMIDX
        lda     rom_payload,x
        sta     FEXP0
        lda     READ0
        sta     FREAD0
        lda     #$00
        sta     FEXP1
        sta     FEXP2
        sta     FREAD1
        sta     FREAD2
        sec
        rts

test_reusable_tags:
        lda     #$00
        sta     REGAH
        sta     REGAB
        sta     REGAX
        sta     REGAL
        jsr     cache_read
        bcs     reusable_tags_fail
        cmp     #$00
        bne     reusable_tags_fail
        lda     #$01
        sta     REGAL
        jsr     cache_read
        bcs     reusable_tags_fail
        cmp     #$00
        bne     reusable_tags_fail
        lda     #$02
        sta     REGAL
        jsr     cache_read
        bcs     reusable_tags_fail
        cmp     #$00
        bne     reusable_tags_fail

        lda     #$80
        sta     REGAL
        jsr     cache_read
        bcs     reusable_tags_fail
        cmp     #$01
        bne     reusable_tags_fail
        lda     #$81
        sta     REGAL
        jsr     cache_read
        bcs     reusable_tags_fail
        cmp     #$00
        bne     reusable_tags_fail
        lda     #$82
        sta     REGAL
        jsr     cache_read
        bcs     reusable_tags_fail
        cmp     #$00
        bne     reusable_tags_fail
        lda     #$00
        sta     FAILK
        clc
        rts
reusable_tags_fail:
        sec
        rts

fill_sdram:
        lda     #$00
        sta     ADDR0
        sta     ADDR1
        sta     ADDR2
        sta     ADDR3
        sta     PAGE0
        sta     PAGE1
        sta     PAGE2
fill_loop:
        jsr     write_page_tag
        bcs     fill_fail
        lda     PAGE0
        and     #$07
        cmp     #$07
        bne     fill_inc
        jsr     cache_flush
        bcs     fill_fail
fill_inc:
        jsr     inc_page_addr
        lda     PAGE2
        cmp     #$08
        bne     fill_loop
        jsr     set_final_fill_addr
        clc
        rts
fill_fail:
        lda     #FAIL_FILL
        sta     FAILK
        jsr     save_fail_addr
        lda     PAGE0
        sta     FEXP0
        lda     PAGE1
        sta     FEXP1
        lda     PAGE2
        sta     FEXP2
        lda     #$00
        sta     FREAD0
        sta     FREAD1
        sta     FREAD2
        sec
        rts

write_page_tag:
        jsr     set_addr_regs
        lda     PAGE0
        jsr     cache_write
        bcs     write_page_done
        lda     ADDR0
        clc
        adc     #$01
        sta     REGAL
        lda     PAGE1
        jsr     cache_write
        bcs     write_page_done
        lda     ADDR0
        clc
        adc     #$02
        sta     REGAL
        lda     PAGE2
        jsr     cache_write
write_page_done:
        rts

check_random_tag:
        lda     #$00
        sta     READ0
        sta     READ1
        sta     READ2
        jsr     next_random
        jsr     random_page_addr
        jsr     set_addr_regs
        jsr     cache_read
        bcs     check_fail
        sta     READ0
        lda     ADDR0
        clc
        adc     #$01
        sta     REGAL
        jsr     cache_read
        bcs     check_fail
        sta     READ1
        lda     ADDR0
        clc
        adc     #$02
        sta     REGAL
        jsr     cache_read
        bcs     check_fail
        sta     READ2

        lda     READ0
        cmp     EXP0
        bne     check_fail
        lda     READ1
        cmp     EXP1
        bne     check_fail
        lda     READ2
        cmp     EXP2
        bne     check_fail
        clc
        rts

check_fail:
        lda     #FAIL_CHECK
        sta     FAILK
        jsr     save_fail_addr
        lda     READ0
        sta     FREAD0
        lda     READ1
        sta     FREAD1
        lda     READ2
        sta     FREAD2
        lda     EXP0
        sta     FEXP0
        lda     EXP1
        sta     FEXP1
        lda     EXP2
        sta     FEXP2
        sec
        rts

set_addr_regs:
        lda     ADDR0
        sta     REGAL
        lda     ADDR1
        sta     REGAH
        lda     ADDR2
        sta     REGAB
        lda     ADDR3
        sta     REGAX
        rts

cache_write:
        sta     REGDATA
        lda     #$01
        sta     REGCMD
        jsr     wait_done
        rts

cache_read:
        lda     #$02
        sta     REGCMD
        jsr     wait_done
        bcs     cache_read_done
        lda     REGDATA
cache_read_done:
        rts

cache_flush:
        lda     #$04
        sta     REGCMD
        jsr     wait_done
        rts

wait_done:
        ldy     #$ff
wait_done_y:
        ldx     #$ff
wait_done_x:
        lda     REGCMD
        and     #$01
        bne     wait_done_ok
        dex
        bne     wait_done_x
        dey
        bne     wait_done_y
        sec
        rts
wait_done_ok:
        clc
        rts

wait_blank:
        lda     REGVBL
        and     #$02
        beq     wait_blank
        rts

inc_page_addr:
        inc     PAGE0
        bne     inc_addr
        inc     PAGE1
        bne     inc_addr
        inc     PAGE2
inc_addr:
        lda     ADDR0
        clc
        adc     #$80
        sta     ADDR0
        bcc     inc_page_done
        inc     ADDR1
        bne     inc_page_done
        inc     ADDR2
        bne     inc_page_done
        inc     ADDR3
inc_page_done:
        rts

next_random:
        lda     RAND0
        sta     TMP0
        lda     RAND1
        sta     TMP1
        lda     RAND2
        sta     TMP2
        asl     TMP0
        rol     TMP1
        rol     TMP2
        asl     TMP0
        rol     TMP1
        rol     TMP2
        clc
        lda     TMP0
        adc     RAND0
        sta     RAND0
        lda     TMP1
        adc     RAND1
        sta     RAND1
        lda     TMP2
        adc     RAND2
        sta     RAND2
        inc     RAND0
        bne     next_random_done
        inc     RAND1
        bne     next_random_done
        inc     RAND2
next_random_done:
        rts

random_page_addr:
        lda     RAND0
        sta     PAGE0
        sta     EXP0
        lda     RAND1
        sta     PAGE1
        sta     EXP1
        lda     RAND2
        and     #$07
        sta     PAGE2
        sta     EXP2

        lda     PAGE0
        and     #$01
        beq     rand_addr0_zero
        lda     #$80
        bra     rand_addr0_store
rand_addr0_zero:
        lda     #$00
rand_addr0_store:
        sta     ADDR0

        lda     PAGE0
        lsr
        sta     ADDR1
        lda     PAGE1
        and     #$01
        beq     rand_addr1_done
        lda     ADDR1
        ora     #$80
        sta     ADDR1
rand_addr1_done:
        lda     PAGE1
        lsr
        sta     ADDR2
        lda     PAGE2
        and     #$01
        beq     rand_addr2_done
        lda     ADDR2
        ora     #$80
        sta     ADDR2
rand_addr2_done:
        lda     PAGE2
        lsr
        sta     ADDR3
        rts

inc_check_count:
        inc     CHECK0
        bne     inc_check_done
        inc     CHECK1
        bne     inc_check_done
        inc     CHECK2
        bne     inc_check_done
        inc     CHECK3
inc_check_done:
        rts

save_fail_addr:
        lda     ADDR0
        sta     FADDR0
        lda     ADDR1
        sta     FADDR1
        lda     ADDR2
        sta     FADDR2
        lda     ADDR3
        sta     FADDR3
        rts

save_fill_done_addr:
        lda     ADDR0
        sta     FILL0
        lda     ADDR1
        sta     FILL1
        lda     ADDR2
        sta     FILL2
        lda     ADDR3
        sta     FILL3
        rts

set_final_fill_addr:
        lda     #$80
        sta     ADDR0
        lda     #$ff
        sta     ADDR1
        sta     ADDR2
        lda     #$03
        sta     ADDR3
        rts

evict_cache_after_fill:
        lda     #$00
        sta     ADDR0
        sta     ADDR1
        sta     ADDR2
        sta     ADDR3
        jsr     set_addr_regs
        jsr     cache_read
        rts

print_rom_row:
        ldx     #$00
        lda     FAILED
        beq     print_rom_not_failed
        lda     FAILK
        cmp     #FAIL_ROM
        beq     print_rom_fail
print_rom_not_failed:
        lda     ROMOK
        cmp     #$01
        beq     print_rom_pass
        cmp     #$02
        beq     print_rom_tagged
print_rom_run_loop:
        lda     rom_run_msg,x
        beq     print_rom_idx
        sta     ROW_ROM,x
        inx
        bne     print_rom_run_loop
print_rom_idx:
        lda     ROMIDX
        jsr     byte_to_hex
        lda     HEXHI
        sta     ROW_ROM+9
        lda     HEXLO
        sta     ROW_ROM+10
        rts
print_rom_pass:
        lda     rom_pass_msg,x
        beq     print_rom_pass_count
        sta     ROW_ROM,x
        inx
        bne     print_rom_pass
print_rom_pass_count:
        lda     #ROM_LEN-1
        jsr     byte_to_hex
        lda     HEXHI
        sta     ROW_ROM+9
        lda     HEXLO
        sta     ROW_ROM+10
        rts
print_rom_tagged:
        lda     rom_tagged_msg,x
        beq     print_rom_tagged_done
        sta     ROW_ROM,x
        inx
        bne     print_rom_tagged
print_rom_tagged_done:
        rts
print_rom_fail:
        lda     rom_fail_msg,x
        beq     print_rom_fail_count
        ora     #$80
        sta     ROW_ROM,x
        inx
        bne     print_rom_fail
print_rom_fail_count:
        lda     ROMIDX
        jsr     byte_to_hex
        lda     HEXHI
        ora     #$80
        sta     ROW_ROM+9
        lda     HEXLO
        ora     #$80
        sta     ROW_ROM+10
        rts

print_fill_row:
        ldx     #$00
        lda     STAGE
        cmp     #STAGE_FILL
        beq     print_fill_active
print_fill_done_loop:
        lda     fill_done_msg,x
        beq     print_fill_done_addr
        sta     ROW_FILL,x
        inx
        bne     print_fill_done_loop
print_fill_done_addr:
        lda     FILL3
        sta     TMP0
        lda     FILL2
        sta     TMP1
        lda     FILL1
        sta     TMP2
        lda     FILL0
        bra     print_fill_addr_from_tmp
print_fill_active:
        lda     fill_msg,x
        beq     print_fill_active_addr
        sta     ROW_FILL,x
        inx
        bne     print_fill_active
print_fill_active_addr:
        lda     ADDR3
        sta     TMP0
        lda     ADDR2
        sta     TMP1
        lda     ADDR1
        sta     TMP2
        lda     ADDR0
print_fill_addr_from_tmp:
        pha
        lda     TMP0
        jsr     byte_to_hex
        lda     HEXHI
        sta     ROW_FILL+10
        lda     HEXLO
        sta     ROW_FILL+11
        lda     TMP1
        jsr     byte_to_hex
        lda     HEXHI
        sta     ROW_FILL+12
        lda     HEXLO
        sta     ROW_FILL+13
        lda     TMP2
        jsr     byte_to_hex
        lda     HEXHI
        sta     ROW_FILL+14
        lda     HEXLO
        sta     ROW_FILL+15
        pla
        jsr     byte_to_hex
        lda     HEXHI
        sta     ROW_FILL+16
        lda     HEXLO
        sta     ROW_FILL+17
        rts

print_check_row:
        ldx     #$00
print_check_loop:
        lda     check_msg,x
        beq     print_check_count
        sta     ROW_CHECK,x
        inx
        bne     print_check_loop
print_check_count:
        lda     CHECK3
        jsr     byte_to_hex
        lda     HEXHI
        sta     ROW_CHECK+6
        lda     HEXLO
        sta     ROW_CHECK+7
        lda     CHECK2
        jsr     byte_to_hex
        lda     HEXHI
        sta     ROW_CHECK+8
        lda     HEXLO
        sta     ROW_CHECK+9
        lda     CHECK1
        jsr     byte_to_hex
        lda     HEXHI
        sta     ROW_CHECK+10
        lda     HEXLO
        sta     ROW_CHECK+11
        lda     CHECK0
        jsr     byte_to_hex
        lda     HEXHI
        sta     ROW_CHECK+12
        lda     HEXLO
        sta     ROW_CHECK+13
        lda     ADDR3
        jsr     byte_to_hex
        lda     HEXHI
        sta     ROW_CHECK+15
        lda     HEXLO
        sta     ROW_CHECK+16
        lda     ADDR2
        jsr     byte_to_hex
        lda     HEXHI
        sta     ROW_CHECK+17
        lda     HEXLO
        sta     ROW_CHECK+18
        lda     ADDR1
        jsr     byte_to_hex
        lda     HEXHI
        sta     ROW_CHECK+19
        lda     HEXLO
        sta     ROW_CHECK+20
        lda     ADDR0
        jsr     byte_to_hex
        lda     HEXHI
        sta     ROW_CHECK+21
        lda     HEXLO
        sta     ROW_CHECK+22
        rts

print_fail_rows:
        ldx     #$00
print_fail_addr_loop:
        lda     fail_addr_msg,x
        beq     print_fail_addr_value
        ora     #$80
        sta     ROW_FAIL,x
        inx
        bne     print_fail_addr_loop
print_fail_addr_value:
        lda     FADDR3
        jsr     byte_to_hex
        lda     HEXHI
        ora     #$80
        sta     ROW_FAIL+10
        lda     HEXLO
        ora     #$80
        sta     ROW_FAIL+11
        lda     FADDR2
        jsr     byte_to_hex
        lda     HEXHI
        ora     #$80
        sta     ROW_FAIL+12
        lda     HEXLO
        ora     #$80
        sta     ROW_FAIL+13
        lda     FADDR1
        jsr     byte_to_hex
        lda     HEXHI
        ora     #$80
        sta     ROW_FAIL+14
        lda     HEXLO
        ora     #$80
        sta     ROW_FAIL+15
        lda     FADDR0
        jsr     byte_to_hex
        lda     HEXHI
        ora     #$80
        sta     ROW_FAIL+16
        lda     HEXLO
        ora     #$80
        sta     ROW_FAIL+17

        ldx     #$00
print_fail_data_loop:
        lda     fail_data_msg,x
        beq     print_fail_data_value
        ora     #$80
        sta     ROW_FAIL2,x
        inx
        bne     print_fail_data_loop
print_fail_data_value:
        lda     FREAD2
        jsr     byte_to_hex
        lda     HEXHI
        ora     #$80
        sta     ROW_FAIL2+5
        lda     HEXLO
        ora     #$80
        sta     ROW_FAIL2+6
        lda     FREAD1
        jsr     byte_to_hex
        lda     HEXHI
        ora     #$80
        sta     ROW_FAIL2+7
        lda     HEXLO
        ora     #$80
        sta     ROW_FAIL2+8
        lda     FREAD0
        jsr     byte_to_hex
        lda     HEXHI
        ora     #$80
        sta     ROW_FAIL2+9
        lda     HEXLO
        ora     #$80
        sta     ROW_FAIL2+10
        lda     FEXP2
        jsr     byte_to_hex
        lda     HEXHI
        ora     #$80
        sta     ROW_FAIL2+17
        lda     HEXLO
        ora     #$80
        sta     ROW_FAIL2+18
        lda     FEXP1
        jsr     byte_to_hex
        lda     HEXHI
        ora     #$80
        sta     ROW_FAIL2+19
        lda     HEXLO
        ora     #$80
        sta     ROW_FAIL2+20
        lda     FEXP0
        jsr     byte_to_hex
        lda     HEXHI
        ora     #$80
        sta     ROW_FAIL2+21
        lda     HEXLO
        ora     #$80
        sta     ROW_FAIL2+22
        rts

byte_to_hex:
        pha
        lsr
        lsr
        lsr
        lsr
        tax
        lda     hex_digits,x
        sta     HEXHI
        pla
        and     #$0f
        tax
        lda     hex_digits,x
        sta     HEXLO
        rts

title_msg:
        db      "TEST85",0
rom_run_msg:
        db      "ROM      ",0
rom_pass_msg:
        db      "PASS ROM ",0
rom_tagged_msg:
        db      "ROM TAGGED",0
rom_fail_msg:
        db      "FAIL ROM ",0
fill_msg:
        db      "FILL      ",0
fill_done_msg:
        db      "FILL DONE ",0
check_msg:
        db      "CHECK          ",0
fail_addr_msg:
        db      "FAIL ADDR ",0
fail_data_msg:
        db      "READ         EXP ",0
hex_digits:
        db      "0123456789ABCDEF"

        include "payload.inc"

        org     $fffa
        dw      reset
        dw      reset
        dw      irq
