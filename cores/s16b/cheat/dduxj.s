; use "cheatzip" script to assemble and send to MiSTer
; cheatzip dduxj.s -rename debug

constant LED, 6
constant FRAMECNT, 0x2c
constant WATCHDOG, 0x40
constant STATUS, 0x80
constant VRAM_CTRL, 0xB
constant VRAM_COL, 8
constant VRAM_ROW, 9
constant VRAM_DATA, A
constant DEBUG_BUS, F
constant GAMERAM, 12

    ; enable interrupt
    load sb,0
    outputk 1,VRAM_CTRL
    call CLS
BEGIN:
    output s0,WATCHDOG

    ; Detect blanking
    input s0,STATUS
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
    ; infinite energy
    ; FFD471 -> 2A38 -> 0A38
    load s2,GAMERAM
    load s1,0A
    load s0,38
    load s4,1c
    load s3,1C
    load s5,2
    call WRITE_SDRAM

    ; infinite ammo
    ; FFDA01 -> d00
    load s2,GAMERAM
    load s1,0d
    load s0,00
    load s3,b
    load s5,2
    call WRITE_SDRAM
    ; FFDA77 -> d3b
    load s2,GAMERAM
    load s1,0d
    load s0,3b
    load s3,b
    load s5,2
    call WRITE_SDRAM
    ; FFDAed -> d76
    load s2,GAMERAM
    load s1,0d
    load s0,76
    load s3,b
    load s5,2
    call WRITE_SDRAM
    ; ffd98b -> 198b
    load s2,GAMERAM
    load s1,19
    load s0,8b
    load s3,31
    load s5,2
    call WRITE_SDRAM

    ; start screen
    ;load s2,GAMERAM
    ;load s1,0A
    ;load s0,18
    ;input s3,DEBUG_BUS
    ;load s5,2
    ;call WRITE_SDRAM

    ;load s2,GAMERAM
    ;load s1,00
    ;load s0,00
    ;call READ_SDRAM

    outputk 4,VRAM_ROW
    load s0,2
    input s1,DEBUG_BUS
    call WRITE_HEX


CLOSE_FRAME:
    output sb,6     ; LED
    ; Frame counter
    input sa,FRAMECNT
    ; compare sa,59'd
    test sa,8
    jump nz,.else
    add  sb,1
.else:
    return

WRITE_PAIR:
    fetch s0,0
    fetch s1,7
    call WRITE_HEX
    fetch s1,6
    call WRITE_HEX
    add s0,1
    store s0,0
    return

    ; SDRAM address in s2-s0
    ; SDRAM data out in s4-s3
    ; SDRAM data mask in s5
    ; Modifies se, sf
WRITE_SDRAM:
    output s5, 5
    output s4, 4
    output s3, 3
    output s2, 2
    output s1, 1
    output s0, 0
    output s1, 0xC0   ; s1 value doesn't matter
    load   se, ff
.loop:
    input  sf, 0x80
    compare sf, 0xC0
    return z
    sub se,1
    return z    ; timeout
    jump .loop

    ; Modifies se, sf
    ; Read data in (s2,s1,s0) into (s7,s6)
READ_SDRAM:
    output s2, 2
    output s1, 1
    output s0, 0
    output s1, 0x80   ; s1 value doesn't matter
    load   se, ff
.loop:
    input  sf, 0x80
    compare sf, 0xC0
    jump nz,.loop
    jump z,.good
    sub se,1
    jump nz,.loop    ; timeout
.good:
    input s6,6
    input s7,7
    store s6,6
    store s7,7
    return


    ; s0 screen row address
    ; s1 number to write
    ; modifies s2
    ; s0 updated to point to the next column
WRITE_HEX:
    output s0,8
    load s2,s1
    sr0 s2
    sr0 s2
    sr0 s2
    sr0 s2
    call WRITE_HEX4
    add s0,1
    output s0,8
    load s2,s1
    call WRITE_HEX4
    add s0,1    ; leave the cursor at the next column
    return

    ; s2 number to write
    ; modifies s2
WRITE_HEX4:
    and s2,f
    compare s2,a
    jump nc,.over10
    jump z,.over10
    add s2,16'd
    jump .write
.over10:
    add s2,23'd
.write:
    output s2,a
    return

    ; clear screen
    ; modifies s0,s1,s2
CLS:
    load s0,31
    load s1,31
    load s2,0
.loop_row:
    load s1,31
    output s0,8
.loop_col:
    output s1,9
    output s2,a
    sub s1,1
    jump nc,.loop_col
    sub s0,1
    jump nc,.loop_row
    return

default_jump fatal_error
fatal_error:
    jump fatal_error

    address 3FF    ; interrupt vector
    jump ISR