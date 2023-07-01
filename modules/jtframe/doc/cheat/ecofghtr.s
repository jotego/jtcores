; use "cheatzip" script to assemble and send to MiSTer

; The LED will blink if the cheat bits 7:0 are enabled
; CPSx work RAM offset = 30'0000h

; Register use
; SA = frame counter
; SB = LED

    ; enable interrupt
    load sa,0   ; SA = frame counter, modulo 60
    load sb,0
BEGIN:
    output s0,0x40

    ; Detect blanking
    input s0,0x80
    and   s0,0x20;   test for blanking
    jump z,inblank
    jump notblank
inblank:
    fetch s1,0
    test s1,0x20
    jump z,notblank
    store s0,0  ; stores last LVBL
    call ISR ; do blank procedure
    jump BEGIN
notblank:
    store s0,0
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
    ; Infinite Credits
    ; FF02E8=09 -> (02E8/2+30'0000) = 300174
    load  s0,0x74
    load  s1,0x01
    load  s2,0x30
    load  s3,0
    load  s4,9
    load  s5,1
    call  WRITE_SDRAM

TEST_FLAG1:
    input sf,0x10
    test  sf,2      ; bit 1
    jump Z,TEST_FLAG2
    ; Infinite Lives
    ; FFF5F2=09  -> (F5F2/2+30'0000) = 307AF9
    load  s0,0xf9
    load  s1,0x7A
    load  s2,0x30
    load  s3,0
    load  s4,9
    load  s5,1
    call  WRITE_SDRAM

TEST_FLAG2:
    input sf,0x10
    test  sf,4      ; bit 1
    jump Z,TEST_FLAG3
    ; Invincibility
    ; FF877A=FF -> 3043BD once per second
    compare sa,0
    jump nz,TEST_FLAG3
    load  s0,0xBD
    load  s1,0x43
    load  s2,0x30
    load  s3,0
    load  s4,0xff
    load  s5,1
    call  WRITE_SDRAM

TEST_FLAG3:
CLOSE_FRAME:
    output sb,6     ; LED
    ; Frame counter
    add sa,1
    compare sa,59'd
    jump nz,.else
    load sa,0
.else:
    return
    ;returni ENABLE

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

default_jump fatal_error
fatal_error:
    jump fatal_error

    address 3FF    ; interrupt vector
    jump ISR