; use "cheatzip" script to assemble and send to MiSTer

; The LED will blink if the cheat bits 7:0 are enabled
; CPSx work RAM offset = 30'0000h

; Register use
; SA = frame counter
; SB = LED

    enable interrupt
    load sa,0   ; SA = frame counter, modulo 60
    load sb,0
BEGIN:
    output s0,0x40  ; watchdog
    jump BEGIN

ISR:
    input sf,0x10
    test sf,0xff
    jump z,.nothing

    compare sa,0
    jump nz,PARSE_FLAGS
    ; invert LED signal
    add sb,1
    jump PARSE_FLAGS
.nothing:
    load sb,0      ; turn off LED
    jump CLOSE_FRAME

PARSE_FLAGS:
    ; interrupt routine
    input sf,0x10
    test  sf,1      ; bit 0
    jump Z,TEST_FLAG1
    ; Infinite Time
    ; Read FF8AC2 => 304561 and check that its zero
    load  s0,0x61
    load  s1,0x45
    load  s2,0x30
    call  READ_SDRAM
    compare s7,0
    jump nz,char_select
    ; Read FF8Abe => 30455f and check that its greater than one
    load  s0,0x5f
    load  s1,0x45
    load  s2,0x30
    call  READ_SDRAM
    compare s7,1
    jump z,char_select  ; zero flag set, so the value was equal to 1
    jump c,char_select  ; carry flag set, so the value was below 1

    ; FF8ABE=9928 -> (8ABE/2+30'0000) = 30455F (round time)
    load  s0,0x5F
    load  s1,0x45
    load  s2,0x30
    load  s3,99 ; For M68000, the upper byte goes in s3
    load  s4,28
    load  s5,0
    call  WRITE_SDRAM

char_select:
    ; always write this value
    ; FFDDA2=203C -> (DDA2/2+30'0000) = 306ED1 (char select time)
    load  s0,0xD1
    load  s1,0x6E
    load  s2,0x30
    load  s3,20
    load  s4,3C
    load  s5,0
    call  WRITE_SDRAM

TEST_FLAG1:

TEST_FLAG2:

TEST_FLAG3:
CLOSE_FRAME:
    output sb,6     ; LED
    ; Frame counter
    add sa,1
    compare sa,59'd
    jump nz,.else
    load sa,0
.else:
    returni ENABLE

    ; SDRAM address in s2-s0
    ; SDRAM data out in s4-s3
    ; SDRAM data mask in s5
    ; Modifies sf
WRITE_SDRAM:
    output s5, 5
    output s4, 4
    output s3, 3
    output s2, 2
    output s1, 1
    output s0, 0
    output s1, 0xC0   ; s1 value doesn't matter
.loop:
    input  sf, 0x80
    compare sf, 0xC0
    return z
    jump .loop

    ; Modifies sf
    ; Read data in s7,s6
READ_SDRAM:
    output s2, 2
    output s1, 1
    output s0, 0
    output s1, 0x80   ; s1 value doesn't matter
.loop:
    input  sf, 0x80
    compare sf, 0xC0
    jump nz,.loop
    input s6,6
    input s7,7
    return

default_jump fatal_error
fatal_error:
    jump fatal_error

    address 3FF    ; interrupt vector
    jump ISR