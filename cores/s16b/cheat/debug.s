; use "cheatzip" script to assemble and send to MiSTer

; Shows the scroll settings and the debug bus

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
constant KEYS, 30

; Register use
; SA = frame counter
; SB = LED
; Memory use
; 0 = last LVBL
; 1 => frame cnt (MSB)

    ; enable interrupt
    load sa,0   ; SA = frame counter, modulo 60
    load sb,0
    load s0,1
    output s0,b ; enable display
    call CLS
    ; Reset second counter
    load s0,0
    store s0,1
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
    ; count the number of seconds elapsed
    input s0,FRAMECNT
    compare s0,3b   ; 59d
    jump nz,.else
    fetch s0,1      ; increase the second counter
    add s0,1
    store s0,1
.else:

    compare sa,0
    jump nz,SCREEN
    ; invert LED signal
    add sb,1


    ; count frames

SCREEN:
    ; Show scroll data
    ; Scroll 1 pages
    load  s0,3
    output s0,9 ; row
    load  s0,2
    load  s3,1
    call  write_st16
    ; Scroll 1 Hpos
    add   s0,2
    load  s3,9
    call  write_st16
    ; Scroll 1 Vpos
    add   s0,2
    load  s3,5
    call  write_st16

    ; second counter
    add s0,4
    fetch s1,1
    call WRITE_HEX

    ; Scroll 2 pages
    load  s0,4
    output s0,9 ; row
    load  s0,2
    load  s3,3
    call  write_st16
    ; Scroll 2 Hpos
    add   s0,2
    load  s3,11'd
    call  write_st16
    ; Scroll 2 Vpos
    add   s0,2
    load  s3,7
    call  write_st16

    ; Debug byte
    load s0,5
    output s0,9 ; row
    load s0,2
    input  s1,f ; debug bus
    call WRITE_HEX

    ; Sound latch
    add s0,2
    load s3,10
    call  write_st8

    ; Tile bank
    add s0,2
    load s3,11
    call  write_st8

    ; Game ID
    add s0,2
    load s3,12
    call  write_st8

    ; Row/Col scroll
    add s0,2
    load s3,c
    call  write_st8

    ; Average CPU frequency
    outputk 6,VRAM_ROW
    load s0,2
    load s3,31
    call write_st8
    load s3,30
    call write_st8
    add s0,2
    load s3,33
    call write_st8
    load s3,32
    call write_st8

    ; Lock keys
    jump .bypass
    outputk 8,VRAM_ROW
    load s0,2
    input s1,33
    call WRITE_HEX
    input s1,32
    call WRITE_HEX
    input s1,31
    call WRITE_HEX
    input s1,30
    call WRITE_HEX
.bypass:

    ; Memory map
    jump CLOSE_FRAME ; SKIPPING IT!
    outputk 7,VRAM_ROW
    load s0,2

    load s3,28
    call  write_st8
    add s0,1
    load s3,29
    call  write_st8
    add s0,1
    load s3,2a
    call  write_st8
    add s0,1
    load s3,2b
    call  write_st8
    add s0,1
    load s3,2c
    call  write_st8
    add s0,1
    load s3,2d
    call  write_st8
    add s0,1
    load s3,2e
    call  write_st8
    add s0,1
    load s3,2f
    call  write_st8

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
    call WRITE_HEX
    sub s3,1
    output s3,c
    add s3,0   ; nop
    add s3,0   ; nop
    input s1,d
    call WRITE_HEX
    return

    ; writes 16-bit status data
    ; s3 sets st_addr
    ; s2 is modified
    ; s0 is updated to point to the next column
write_st8:
    output s3,c
    add s3,0   ; nop
    add s3,0   ; nop
    input s1,d
    call WRITE_HEX
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
    test sf, 0xC0
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
    test sf, 0xC0
    jump nz,.loop
    input s6,6
    input s7,7
    return

default_jump fatal_error
fatal_error:
    jump fatal_error

    address 3FF    ; interrupt vector
    jump ISR