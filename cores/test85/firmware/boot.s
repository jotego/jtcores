; Minimal 65C02 boot program for TEST85.
; It clears the 32x32 text RAM at $2000-$23ff and prints TEST85.

        .org    $c000

reset:
        sei
        cld
        ldx     #$00

clear:
        lda     #$20
        sta     $2000,x
        sta     $2100,x
        sta     $2200,x
        sta     $2300,x
        inx
        bne     clear

        ldx     #$00
print:
        lda     title,x
        beq     done
        sta     $2000,x
        inx
        bne     print

done:
        jmp     done

title:
        .byte   "TEST85",0

        .org    $fffa
        .word   reset
        .word   reset
        .word   reset
