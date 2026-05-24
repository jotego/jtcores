; Minimal 65C02 boot program for TEST85.
; It updates the screen and runs CPU-facing SDRAM cache and ROM
; download tests from frame interrupts.

        cpu     65c02

TEXT    =       $2000
CL0     =       $2000
CL1     =       $2100
CL2     =       $2200
CL3     =       $2300
REGAL   =       $3000
REGAH   =       $3001
REGAB   =       $3002
REGDATA =       $3003
REGCMD  =       $3004
REGVBL  =       $3005

ITER    =       $00
EXPECT  =       $01
INIT    =       $02
FAILED  =       $03
DONE    =       $04
ROMIDX  =       $05

        org     $c000

reset:
        sei
        cld
        ldx     #$ff
        txs
        ldx     #$00
        stx     ITER
        stx     INIT
        stx     FAILED
        stx     DONE
        stx     ROMIDX
        lda     REGVBL
        cli

idle:
        jmp     idle

irq:
        pha
        phx
        phy
        lda     REGVBL
        lda     FAILED
        bne     irq_done
        lda     DONE
        bne     irq_done
        jsr     wait_blank
        lda     INIT
        bne     irq_test
        jsr     init_screen
        inc     INIT

irq_test:
        lda     ITER
        cmp     #30
        bcs     irq_rom
        jsr     test_cache
        jsr     wait_blank
        bcs     irq_cache_fail
        jsr     print_cache_pass
        inc     ITER
        bra     irq_done

irq_rom:
        jsr     test_rom
        jsr     wait_blank
        bcs     irq_rom_fail
        jsr     print_rom_pass
        inc     DONE
        bra     irq_done

irq_cache_fail:
        jsr     print_cache_fail
        inc     FAILED
        bra     irq_done

irq_rom_fail:
        jsr     print_rom_fail
        inc     FAILED

irq_done:
        ply
        plx
        pla
        rti

init_screen:
        ldx     #$00
clear:
        lda     #$20
        sta     CL0,x
        sta     CL1,x
        sta     CL2,x
        sta     CL3,x
        inx
        bne     clear
        ldx     #$00
print_title:
        lda     title,x
        beq     init_lines
        sta     TEXT,x
        inx
        bne     print_title
init_lines:
        ldx     #$00
print_loop_label:
        lda     loop_label,x
        beq     init_done
        sta     TEXT+$40,x
        inx
        bne     print_loop_label
init_done:
        rts

test_cache:
        lda     ITER
        eor     #$5a
        sta     EXPECT

        lda     ITER
        sta     REGAL
        lda     #$10
        sta     REGAH
        lda     #$00
        sta     REGAB
        lda     EXPECT
        sta     REGDATA
        lda     #$01
        sta     REGCMD
        jsr     wait_done
        bcs     test_done

        lda     #$04
        sta     REGCMD
        jsr     wait_done
        bcs     test_done

        lda     #$00
        sta     REGAL
        lda     #$14
        sta     REGAH
        lda     #$00
        sta     REGAB
        lda     #$02
        sta     REGCMD
        jsr     wait_done
        bcs     test_done

        lda     ITER
        sta     REGAL
        lda     #$10
        sta     REGAH
        lda     #$00
        sta     REGAB
        lda     #$02
        sta     REGCMD
        jsr     wait_done
        bcs     test_done

        lda     REGDATA
        cmp     EXPECT
        beq     test_pass
        sec
        rts

test_pass:
        clc
test_done:
        rts

test_rom:
        lda     #$00
        sta     ROMIDX
test_rom_loop:
        ldx     ROMIDX
        stx     REGAL
        lda     #$00
        sta     REGAH
        sta     REGAB
        lda     #$02
        sta     REGCMD
        jsr     wait_done
        bcs     test_rom_done

        ldx     ROMIDX
        lda     REGDATA
        cmp     rom_payload,x
        bne     test_rom_fail
        inc     ROMIDX
        lda     ROMIDX
        cmp     #ROM_LEN
        bne     test_rom_loop
        clc
        rts

test_rom_fail:
        sec
test_rom_done:
        rts

wait_done:
        ldy     #$20
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

print_cache_fail:
        ldx     #$00
print_cache_fail_loop:
        lda     fail_cache_msg,x
        beq     update_cache_fail_count
        ora     #$80
        sta     TEXT+$80,x
        inx
        bne     print_cache_fail_loop
update_cache_fail_count:
        lda     ITER
        jsr     print_cache_count_red
        rts

print_cache_pass:
        ldx     #$00
print_cache_pass_loop:
        lda     pass_cache_msg,x
        beq     update_cache_pass_count
        sta     TEXT+$80,x
        inx
        bne     print_cache_pass_loop
update_cache_pass_count:
        lda     ITER
        jsr     print_cache_count_white
        rts

print_rom_fail:
        ldx     #$00
print_rom_fail_loop:
        lda     fail_rom_msg,x
        beq     update_rom_fail_count
        ora     #$80
        sta     TEXT+$c0,x
        inx
        bne     print_rom_fail_loop
update_rom_fail_count:
        lda     ROMIDX
        jsr     print_rom_count_red
        rts

print_rom_pass:
        ldx     #$00
print_rom_pass_loop:
        lda     pass_rom_msg,x
        beq     update_rom_pass_count
        sta     TEXT+$c0,x
        inx
        bne     print_rom_pass_loop
update_rom_pass_count:
        lda     #ROM_LEN-1
        jsr     print_rom_count_white
        rts

print_cache_count_white:
        pha
        lsr
        lsr
        lsr
        lsr
        tax
        lda     hex_digits,x
        sta     TEXT+$8b
        pla
        and     #$0f
        tax
        lda     hex_digits,x
        sta     TEXT+$8c
        rts

print_cache_count_red:
        pha
        lsr
        lsr
        lsr
        lsr
        tax
        lda     hex_digits,x
        ora     #$80
        sta     TEXT+$8b
        pla
        and     #$0f
        tax
        lda     hex_digits,x
        ora     #$80
        sta     TEXT+$8c
        rts

print_rom_count_white:
        pha
        lsr
        lsr
        lsr
        lsr
        tax
        lda     hex_digits,x
        sta     TEXT+$c9
        pla
        and     #$0f
        tax
        lda     hex_digits,x
        sta     TEXT+$ca
        rts

print_rom_count_red:
        pha
        lsr
        lsr
        lsr
        lsr
        tax
        lda     hex_digits,x
        ora     #$80
        sta     TEXT+$c9
        pla
        and     #$0f
        tax
        lda     hex_digits,x
        ora     #$80
        sta     TEXT+$ca
        rts


title:
        db      "TEST85",0
loop_label:
        db      "30X CACHE, THEN ROM DATA",0
pass_cache_msg:
        db      "PASS CACHE ",0
fail_cache_msg:
        db      "FAIL CACHE ",0
pass_rom_msg:
        db      "PASS ROM ",0
fail_rom_msg:
        db      "FAIL ROM ",0
hex_digits:
        db      "0123456789ABCDEF"

        include "payload.inc"

        org     $fffa
        dw      reset
        dw      reset
        dw      irq
