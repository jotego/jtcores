; Diet Go Go HuC6280A resident YM2151 measurement monitor.
; ROM bank 0 boots at E000. No stack/RAM variables until RAM has been tested.
.setcpu "huc6280"
.export boot, monitor, idle, generation
.import __MONITOR_LOAD__, __MONITOR_SIZE__
YM = $4000                  ; MPR2=$88 -> physical $110000
CONTROL = $6000             ; MPR3=$01 -> PicoROM physical $2000
COMMS = $7c00               ; physical $3c00, stock PicoROM 1 KiB window
TABLE = $8000               ; MPR4=$02 -> PicoROM physical $4000
pointer = $00               ; HuC6280 direct page is in MPR1, at $2000
generation = $02
delay_lo = $03
delay_hi = $04
status = $05
out_seq = $06

.segment "BOOT"
boot:
    sei
    cld
    csh
    lda #$00
    tam #$80
    lda #$f8
    tam #$02
    ; Test every RAM byte with complementary address-dependent patterns.
    ; Absolute indexed addressing avoids using the untested direct page.
    .repeat 2, pass
      .scope
        ldx #0
write_loop:
        .repeat 32, page
            txa
            eor #(page ^ (pass * $ff))
            sta $2000 + page * $100,x
        .endrepeat
        inx
        beq :+
        jmp write_loop
:
        ldx #0
read_loop:
        .repeat 32, page
            txa
            eor #(page ^ (pass * $ff))
            cmp $2000 + page * $100,x
            beq :+
            jmp ram_fail
:
        .endrepeat
        inx
        beq :+
        jmp read_loop
:
      .endscope
    .endrepeat
    ldx #$ff
    txs
    lda #$88
    tam #$04
    lda #$01
    tam #$08
    lda #$02
    tam #$10
    tii __MONITOR_LOAD__, monitor, __MONITOR_SIZE__
    jmp monitor
ram_fail:
    bra ram_fail

.segment "MONITOR"
monitor:
    lda CONTROL
    sta generation
    lda #$b0
    jsr send
    lda generation
    jsr send
    lda YM+1
    jsr send
idle:
    lda CONTROL
    cmp generation
    beq idle
    eor CONTROL+1
    cmp #$ff
    bne idle
    lda CONTROL
    sta generation
    stz pointer
    lda #>TABLE
    sta pointer+1
    stz status
dispatch:
    jsr get_byte
    cmp #0
    beq done
    cmp #1
    beq write_reg
    cmp #2
    beq delay
    cmp #3
    beq read_status
    lda #$ff
    sta status
done:
    lda #$d0
    jsr send
    lda generation
    jsr send
    lda status
    jsr send
    bra idle
write_reg:
    jsr wait_ym
    jsr get_byte
    sta YM
    jsr wait_ym
    jsr get_byte
    sta YM+1
    bra dispatch
delay:
    jsr get_byte
    sta delay_lo
    jsr get_byte
    sta delay_hi
:
    lda delay_lo
    ora delay_hi
    beq dispatch
    lda delay_lo
    bne :+
    dec delay_hi
:
    dec delay_lo
    bra :--
read_status:
    lda YM+1
    sta status
    bra dispatch
wait_ym:
    lda YM+1
    bmi wait_ym
    rts
get_byte:
    lda (pointer)
    inc pointer
    bne :+
    inc pointer+1
:
    rts
send:
    tax
    lda COMMS+$10
    sta out_seq
    lda COMMS+$300,x        ; read address encodes outgoing byte
:
    lda COMMS+$10
    cmp out_seq
    beq :-
    rts

.segment "VECTORS"
    .word boot, boot, boot, boot, boot
