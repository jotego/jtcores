; Minimal 65C02 boot program for TEST85.
; It clears the 32x32 text RAM, prints TEST85, then loops over the
; CPU-facing SDRAM cache registers.

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

ITER    =       $00
EXPECT  =       $01

        org     $c000

reset:
        sei
        cld
        ldx     #$ff
        txs
        ldx     #$00
        stx     ITER

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
        beq     test_loop
        sta     TEXT+$40,x
        inx
        bne     print_loop_label

test_loop:
        lda     ITER
        eor     #$5a
        sta     EXPECT

        lda     ITER
        sta     REGAL
        lda     #$00
        sta     REGAH
        sta     REGAB
        lda     EXPECT
        sta     REGDATA
        lda     #$01
        sta     REGCMD
wait_write:
        lda     REGCMD
        and     #$01
        beq     wait_write

        lda     #$04
        sta     REGCMD
wait_flush:
        lda     REGCMD
        and     #$01
        beq     wait_flush

        lda     #$00
        sta     REGAL
        lda     #$04
        sta     REGAH
        lda     #$00
        sta     REGAB
        lda     #$02
        sta     REGCMD
wait_evict:
        lda     REGCMD
        and     #$01
        beq     wait_evict

        lda     ITER
        sta     REGAL
        lda     #$00
        sta     REGAH
        sta     REGAB
        lda     #$02
        sta     REGCMD
wait_read:
        lda     REGCMD
        and     #$01
        beq     wait_read

        lda     REGDATA
        cmp     EXPECT
        beq     test_pass
        ldx     #$00
print_fail:
        lda     fail_msg,x
        beq     update_count
        sta     TEXT+$80,x
        inx
        bne     print_fail

test_pass:
        ldx     #$00
print_pass:
        lda     pass_msg,x
        beq     update_count
        sta     TEXT+$80,x
        inx
        bne     print_pass

update_count:
        lda     ITER
        lsr
        lsr
        lsr
        lsr
        tax
        lda     hex_digits,x
        sta     TEXT+$8a
        lda     ITER
        and     #$0f
        tax
        lda     hex_digits,x
        sta     TEXT+$8b
        inc     ITER
        jmp     test_loop


title:
        db      "TEST85",0
loop_label:
        db      "SDRAM CACHE LOOP",0
pass_msg:
        db      "PASS ITER ",0
fail_msg:
        db      "FAIL ITER ",0
hex_digits:
        db      "0123456789ABCDEF"

        org     $fffa
        dw      reset
        dw      reset
        dw      reset
