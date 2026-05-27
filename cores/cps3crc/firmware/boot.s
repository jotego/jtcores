; 65C02 boot program for CPS3CRC.
; Read-only SDRAM CRC checker for the CPS3 MiSTer download path.

        cpu     65c02

TEXT    =       $2000
CL0     =       $2000
CL1     =       $2100
CL2     =       $2200
CL3     =       $2300
ROW_TITLE =     TEXT+$000
ROW_B0  =       TEXT+$040
ROW_B1  =       TEXT+$060
ROW_B2  =       TEXT+$080
ROW_B3  =       TEXT+$0a0
ROW_DET =       TEXT+$0e0
ROW_TIME =       TEXT+$120

REGAL   =       $3000
REGAH   =       $3001
REGAB   =       $3002
REGDATA =       $3003
REGCMD  =       $3004
REGVBL  =       $3005
REGAX   =       $3006

DET_CHECKING =  $00
DET_SFIIIN =    $01
DET_REDEARTHN = $02
DET_FAIL =      $03

INIT    =       $00
CURBANK =       $01
ADDR0   =       $02
ADDR1   =       $03
ADDR2   =       $04
END0    =       $05
END1    =       $06
END2    =       $07
FULL    =       $08
CRC0    =       $09
CRC1    =       $0a
CRC2    =       $0b
CRC3    =       $0c
TMP0    =       $0d
TMP1    =       $0e
TMP2    =       $0f
TMP3    =       $10
PTRLO   =       $11
PTRHI   =       $12
HEXHI   =       $13
HEXLO   =       $14
COLOR   =       $15
DETECT  =       $16
DONE    =       $17
CAND    =       $18
FRAME   =       $19
SEC     =       $1a
MIN     =       $1b
HOUR    =       $1c
BANKOFF =       $1d
EXPECTG =       $1e

FOUND   =       $30            ; 16 bytes, low byte first per bank
MATCH   =       $40            ; bit 0 sfiiin, bit 1 redearthn per bank

        org     $c000

reset:
        sei
        cld
        ldx     #$ff
        txs
        lda     #$00
        ldx     #$4f
clear_zp:
        sta     $00,x
        dex
        bpl     clear_zp
        lda     REGVBL
        cli

main_loop:
        lda     #$00
        sta     DONE
        ldx     #$00
clear_matches:
        sta     MATCH,x
        inx
        cpx     #$04
        bne     clear_matches

        lda     #$00
        jsr     check_bank
        lda     #$01
        jsr     check_bank
        lda     #$02
        jsr     check_bank
        lda     #$03
        jsr     check_bank
        jsr     detect_game
        bra     main_loop

irq:
        pha
        phx
        phy
        lda     CURBANK
        pha
        lda     BANKOFF
        pha
        lda     REGVBL
        jsr     wait_blank
        jsr     tick_clock
        lda     INIT
        bne     irq_update
        jsr     init_screen
        lda     #$01
        sta     INIT
irq_update:
        jsr     update_screen
        pla
        sta     BANKOFF
        pla
        sta     CURBANK
        ply
        plx
        pla
        rti

check_bank:
        sta     CURBANK
        jsr     clear_bank_state
        jsr     load_bank_end
        lda     #$00
        sta     ADDR0
        sta     ADDR1
        sta     ADDR2
        lda     #$ff
        sta     CRC0
        sta     CRC1
        sta     CRC2
        sta     CRC3
read_loop:
        jsr     set_addr_regs
        jsr     cache_read
        bcs     read_error
        jsr     crc_update
        jsr     inc_addr
        jsr     bank_done
        bcc     read_loop
        sei
        jsr     finish_crc
        jsr     save_crc
        jsr     check_crc_match
        jsr     set_done_bit
        cli
        rts
read_error:
        jsr     zero_found
        lda     #$00
        ldx     CURBANK
        sta     MATCH,x
        jsr     set_done_bit
        lda     #DET_FAIL
        sta     DETECT
        jsr     cache_abort
        jsr     delay_retry
        lda     CURBANK
        jmp     check_bank

clear_bank_state:
        ldx     CURBANK
        lda     bank_bit,x
        eor     #$ff
        and     DONE
        sta     DONE
        lda     #$00
        sta     MATCH,x
        rts

load_bank_end:
        ldx     CURBANK
        lda     bank_end0,x
        sta     END0
        lda     bank_end1,x
        sta     END1
        lda     bank_end2,x
        sta     END2
        lda     bank_full,x
        sta     FULL
        rts

set_addr_regs:
        lda     ADDR0
        sta     REGAL
        lda     ADDR1
        sta     REGAH
        lda     ADDR2
        sta     REGAB
        lda     CURBANK
        sta     REGAX
        rts

cache_read:
        lda     #$02
        sta     REGCMD
        jsr     wait_done
        bcs     cache_read_done
        lda     REGDATA
cache_read_done:
        rts

cache_abort:
        lda     #$80
        sta     REGCMD
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

crc_update:
        eor     CRC0
        sta     CRC0
        ldx     #$08
crc_bit:
        lda     CRC0
        and     #$01
        sta     TMP0
        lsr     CRC3
        ror     CRC2
        ror     CRC1
        ror     CRC0
        lda     TMP0
        beq     crc_no_xor
        lda     CRC0
        eor     #$20
        sta     CRC0
        lda     CRC1
        eor     #$83
        sta     CRC1
        lda     CRC2
        eor     #$b8
        sta     CRC2
        lda     CRC3
        eor     #$ed
        sta     CRC3
crc_no_xor:
        dex
        bne     crc_bit
        rts

inc_addr:
        inc     ADDR0
        bne     inc_addr_done
        inc     ADDR1
        bne     inc_addr_done
        inc     ADDR2
inc_addr_done:
        rts

bank_done:
        lda     FULL
        beq     bank_done_partial
        lda     ADDR0
        ora     ADDR1
        ora     ADDR2
        beq     bank_is_done
        clc
        rts
bank_done_partial:
        lda     ADDR0
        cmp     END0
        bne     bank_not_done
        lda     ADDR1
        cmp     END1
        bne     bank_not_done
        lda     ADDR2
        cmp     END2
        bne     bank_not_done
bank_is_done:
        sec
        rts
bank_not_done:
        clc
        rts

finish_crc:
        lda     CRC0
        eor     #$ff
        sta     CRC0
        lda     CRC1
        eor     #$ff
        sta     CRC1
        lda     CRC2
        eor     #$ff
        sta     CRC2
        lda     CRC3
        eor     #$ff
        sta     CRC3
        rts

bank_offset:
        lda     CURBANK
        asl
        asl
        sta     BANKOFF
        rts

save_crc:
        jsr     bank_offset
        ldx     BANKOFF
        lda     CRC0
        sta     FOUND,x
        inx
        lda     CRC1
        sta     FOUND,x
        inx
        lda     CRC2
        sta     FOUND,x
        inx
        lda     CRC3
        sta     FOUND,x
        rts

zero_found:
        jsr     bank_offset
        ldx     BANKOFF
        lda     #$00
        sta     FOUND,x
        inx
        sta     FOUND,x
        inx
        sta     FOUND,x
        inx
        sta     FOUND,x
        rts

check_crc_match:
        jsr     bank_offset
        lda     #$00
        sta     TMP0
        jsr     compare_sfiiin
        bcs     no_sf_match
        lda     TMP0
        ora     #$01
        sta     TMP0
no_sf_match:
        jsr     compare_redearthn
        bcs     no_re_match
        lda     TMP0
        ora     #$02
        sta     TMP0
no_re_match:
        ldx     CURBANK
        lda     TMP0
        sta     MATCH,x
        rts

compare_sfiiin:
        ldx     BANKOFF
        lda     FOUND,x
        cmp     exp_sfiiin,x
        bne     compare_bad
        inx
        lda     FOUND,x
        cmp     exp_sfiiin,x
        bne     compare_bad
        inx
        lda     FOUND,x
        cmp     exp_sfiiin,x
        bne     compare_bad
        inx
        lda     FOUND,x
        cmp     exp_sfiiin,x
        bne     compare_bad
        clc
        rts

compare_redearthn:
        ldx     BANKOFF
        lda     FOUND,x
        cmp     exp_redearthn,x
        bne     compare_bad
        inx
        lda     FOUND,x
        cmp     exp_redearthn,x
        bne     compare_bad
        inx
        lda     FOUND,x
        cmp     exp_redearthn,x
        bne     compare_bad
        inx
        lda     FOUND,x
        cmp     exp_redearthn,x
        bne     compare_bad
        clc
        rts
compare_bad:
        sec
        rts

set_done_bit:
        ldx     CURBANK
        lda     bank_bit,x
        ora     DONE
        sta     DONE
        rts

detect_game:
        lda     #$03
        sta     CAND
        ldx     #$00
detect_loop:
        lda     CAND
        and     MATCH,x
        sta     CAND
        inx
        cpx     #$04
        bne     detect_loop
        lda     CAND
        and     #$01
        beq     detect_try_re
        lda     #DET_SFIIIN
        sta     DETECT
        rts
detect_try_re:
        lda     CAND
        and     #$02
        beq     detect_fail
        lda     #DET_REDEARTHN
        sta     DETECT
        rts
detect_fail:
        lda     #DET_FAIL
        sta     DETECT
        rts

wait_blank:
        lda     REGVBL
        and     #$02
        beq     wait_blank
        rts

tick_clock:
        inc     FRAME
        lda     FRAME
        cmp     #$3c
        bne     tick_done
        lda     #$00
        sta     FRAME
        inc     SEC
        lda     SEC
        cmp     #$3c
        bne     tick_done
        lda     #$00
        sta     SEC
        inc     MIN
        lda     MIN
        cmp     #$3c
        bne     tick_done
        lda     #$00
        sta     MIN
        inc     HOUR
tick_done:
        rts

delay_retry:
        lda     #$04
        sta     TMP3
delay_retry_sec:
        lda     SEC
delay_retry_wait:
        cmp     SEC
        beq     delay_retry_wait
        dec     TMP3
        bne     delay_retry_sec
        rts

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
        rts

update_screen:
        jsr     print_title
        lda     #$00
        jsr     print_bank_row
        lda     #$01
        jsr     print_bank_row
        lda     #$02
        jsr     print_bank_row
        lda     #$03
        jsr     print_bank_row
        jsr     print_detect
        jsr     print_time
        rts

print_title:
        ldx     #$00
title_loop:
        lda     title_msg,x
        beq     title_bank
        sta     ROW_TITLE,x
        inx
        bne     title_loop
title_bank:
        lda     CURBANK
        clc
        adc     #'0'
        sta     ROW_TITLE+14
        rts

print_bank_row:
        sta     CURBANK
        jsr     bank_offset
        ldx     CURBANK
        lda     row_lo,x
        sta     PTRLO
        lda     row_hi,x
        sta     PTRHI
        ldy     #$00
        lda     #'B'
        sta     (PTRLO),y
        iny
        lda     #'A'
        sta     (PTRLO),y
        iny
        lda     #'N'
        sta     (PTRLO),y
        iny
        lda     #'K'
        sta     (PTRLO),y
        iny
        lda     CURBANK
        clc
        adc     #'0'
        sta     (PTRLO),y
        ldy     #$05
        lda     #' '
space_before_found:
        sta     (PTRLO),y
        iny
        cpy     #$09
        bne     space_before_found
        jsr     select_row_color
        ldy     #$09
        ldx     BANKOFF
        lda     FOUND+3,x
        jsr     print_hex_at_y
        lda     FOUND+2,x
        jsr     print_hex_at_y
        lda     FOUND+1,x
        jsr     print_hex_at_y
        lda     FOUND+0,x
        jsr     print_hex_at_y
        lda     #' '
        sta     (PTRLO),y
        iny
        lda     #'V'
        sta     (PTRLO),y
        iny
        lda     #'S'
        sta     (PTRLO),y
        iny
        lda     #' '
        sta     (PTRLO),y
        iny
        jsr     select_expected_game
        ldx     BANKOFF
        lda     EXPECTG
        beq     print_exp_sf
        lda     exp_redearthn+3,x
        jsr     print_hex_at_y
        lda     exp_redearthn+2,x
        jsr     print_hex_at_y
        lda     exp_redearthn+1,x
        jsr     print_hex_at_y
        lda     exp_redearthn+0,x
        jsr     print_hex_at_y
        rts
print_exp_sf:
        lda     exp_sfiiin+3,x
        jsr     print_hex_at_y
        lda     exp_sfiiin+2,x
        jsr     print_hex_at_y
        lda     exp_sfiiin+1,x
        jsr     print_hex_at_y
        lda     exp_sfiiin+0,x
        jsr     print_hex_at_y
        rts

select_row_color:
        lda     #$00
        sta     COLOR
        ldx     CURBANK
        lda     bank_bit,x
        and     DONE
        beq     color_done
        lda     MATCH,x
        bne     color_done
        lda     #$80
        sta     COLOR
color_done:
        rts

select_expected_game:
        lda     #$00
        sta     EXPECTG
        lda     DETECT
        cmp     #DET_REDEARTHN
        beq     expect_re
        cmp     #DET_SFIIIN
        beq     expect_done
        ldx     CURBANK
        lda     MATCH,x
        and     #$01
        bne     expect_done
        lda     MATCH,x
        and     #$02
        beq     expect_done
expect_re:
        lda     #$01
        sta     EXPECTG
expect_done:
        rts

print_detect:
        ldx     #$00
clear_detect:
        lda     #$20
        sta     ROW_DET,x
        inx
        cpx     #$20
        bne     clear_detect
        lda     DETECT
        cmp     #DET_SFIIIN
        beq     detect_sf_msg
        cmp     #DET_REDEARTHN
        beq     detect_re_msg
        cmp     #DET_FAIL
        beq     detect_fail_msg
        ldx     #$00
        beq     detect_check_loop
detect_sf_msg:
        ldx     #$00
        bra     detect_sf_loop
detect_re_msg:
        ldx     #$00
        bra     detect_re_loop
detect_fail_msg:
        ldx     #$00
        bra     detect_fail_loop
detect_check_loop:
        lda     detect_checking_msg,x
        beq     detect_done
        sta     ROW_DET,x
        inx
        bne     detect_check_loop
detect_sf_loop:
        lda     detect_sfiiin_msg,x
        beq     detect_done
        sta     ROW_DET,x
        inx
        bne     detect_sf_loop
detect_re_loop:
        lda     detect_redearthn_msg,x
        beq     detect_done
        sta     ROW_DET,x
        inx
        bne     detect_re_loop
detect_fail_loop:
        lda     detect_fail_text,x
        beq     detect_done
        ora     #$80
        sta     ROW_DET,x
        inx
        bne     detect_fail_loop
detect_done:
        rts

print_time:
        ldx     #$00
print_time_label:
        lda     time_msg,x
        beq     print_time_value
        sta     ROW_TIME,x
        inx
        bne     print_time_label
print_time_value:
        lda     HOUR
        jsr     print_dec2_time
        lda     #':'
        sta     ROW_TIME+7
        lda     MIN
        jsr     print_dec2_min
        lda     #':'
        sta     ROW_TIME+10
        lda     SEC
        jsr     print_dec2_sec
        rts

print_dec2_time:
        ldy     #$05
        bra     print_dec2
print_dec2_min:
        ldy     #$08
        bra     print_dec2
print_dec2_sec:
        ldy     #$0b
print_dec2:
        ldx     #$00
print_dec2_tens:
        cmp     #$0a
        bcc     print_dec2_digits
        sec
        sbc     #$0a
        inx
        bra     print_dec2_tens
print_dec2_digits:
        pha
        txa
        clc
        adc     #'0'
        sta     ROW_TIME,y
        iny
        pla
        clc
        adc     #'0'
        sta     ROW_TIME,y
        rts

print_hex_at_y:
        phx
        jsr     byte_to_hex
        lda     HEXHI
        ora     COLOR
        sta     (PTRLO),y
        iny
        lda     HEXLO
        ora     COLOR
        sta     (PTRLO),y
        iny
        plx
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

bank_end0:
        db      $00,$00,$00,$00
bank_end1:
        db      $20,$20,$20,$20
bank_end2:
        db      $00,$00,$00,$00
bank_full:
        db      $00,$00,$00,$00
bank_bit:
        db      $01,$02,$04,$08
row_lo:
        db      $40,$60,$80,$a0
row_hi:
        db      $20,$20,$20,$20

; Stored low byte first for comparisons, displayed high byte first.
exp_sfiiin:
        db      $94,$a6,$ee,$3d
        db      $8c,$de,$ff,$c7
        db      $d0,$50,$20,$54
        db      $98,$eb,$cc,$fb
exp_redearthn:
        db      $15,$68,$61,$32
        db      $b8,$fb,$b7,$99
        db      $95,$3b,$6d,$83
        db      $0e,$94,$4a,$f3

title_msg:
        db      "CHECKING BANK 0",0
detect_checking_msg:
        db      "DETECTED CHECKING",0
detect_sfiiin_msg:
        db      "DETECTED SFIIIN",0
detect_redearthn_msg:
        db      "DETECTED REDEARTHN",0
detect_fail_text:
        db      "DETECTED FAIL",0
time_msg:
        db      "HOUR ",0
hex_digits:
        db      "0123456789ABCDEF"

        org     $fffa
        dw      reset
        dw      reset
        dw      irq
