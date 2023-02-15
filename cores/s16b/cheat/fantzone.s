; use "cheatzip" script to assemble and send to MiSTer

; The LED will blink if the cheat bits 7:0 are enabled
; CPSx work RAM offset = 30'0000h

; Register use
; SA = frame counter
; SB = LED

; <dip name="Invincibility" bits="0" ids="No,Yes"/>
; <dip name="Rapid Fire - Shot" bits="1" ids="No,Yes"/>
; <dip name="Stage clear in 7 seconds Now!" bits="2" ids="No,Yes"/>

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
    compare sa,0
    jump nz,CHEAT
    ; invert LED signal
    add sb,1
CHEAT:
    ; Directly apply cheats
    ; invencibility
    ; 8582 -> 10'42c1 set to 4e71
    load s2,10
    load s1,42
    load s0,c1
    load s3,4e
    load s4,71
    load s5,0
    call WRITE_SDRAM
    ; b134 -> 10'589a set to 4e75
    load s2,9a
    load s1,58
    load s4,75
    call WRITE_SDRAM
    ; rapid fire
    ; ff03bb=1 -> 10'01dd set low byte to 1
    load s2,01
    load s1,01
    load s4,1
    load s5,1
    call WRITE_SDRAM

    ; Read joystick
    input s8,18
    test s8,40
    jump z,.nojoy
    test s9,40
    jump nz,.nojoy
    ; button 3 was pressed, trigger level end
    ; FFc23b -> 10'611d (LSB)
    load s2,10
    load s1,61
    load s0,1d
    call READ_SDRAM
    or s7,10
    load s4,s7
    load s5,1
    call WRITE_SDRAM

.nojoy:
    load s9,s8

CLOSE_FRAME:
    output sb,6     ; LED
    ; Frame counter
    add sa,1
    compare sa,59'd
    jump nz,.else
    load sa,0
.else:
    return

    ; writes 16-bit status data
    ; s3 points to the MSB st_addr, the LSB is meant to be in s3-1
    ; s2 is modified
    ; s0 is updated to point to the next column
write_st16:
    output s3,c
    add s3,0   ; nop
    add s3,0   ; nop
    input s1,d
    call WRITE_SDRAM
    sub s3,1
    output s3,c
    add s3,0   ; nop
    add s3,0   ; nop
    input s1,d
    call WRITE_SDRAM
    return


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