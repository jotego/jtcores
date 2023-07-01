;    This file is part of JT_FRAME.
;    JTFRAME program is free software: you can redistribute it and/or modify
;    it under the terms of the GNU General Public License as published by
;    the Free Software Foundation, either version 3 of the License, or
;    (at your option) any later version.
;
;    JTFRAME program is distributed in the hope that it will be useful,
;    but WITHOUT ANY WARRANTY; without even the implied warranty of
;    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;    GNU General Public License for more details.
;
;    You should have received a copy of the GNU General Public License
;    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.
;
;    Author: Jose Tejada Gomez. Twitter: @topapate
;    Version: 1.0
;    Date: 24-1-2023


; Displays a message if the core is locked because of
; missing jtbeta.zip

; Register use
; SB = LED

constant LED, 6
constant FRAMECNT, 0x2c
constant WATCHDOG, 0x40
constant STATUS, 0x80
constant VRAM_CTRL, 0xB
constant VRAM_COL, 8
constant VRAM_ROW, 9
constant VRAM_DATA, A

    ; wait for a few seconds. This prevents
    ; the CLS call from happening during ROM
    ; download
    load s0,120'd
bootloop:
    input s1,FRAMECNT
    compare s1,0
    jump nz,bootloop
    sub s0,1
    jump nz,bootloop

    load sb,0
    outputk 0,VRAM_CTRL ; disable display


    input s0,STATUS
    test s0,1
    jump z, UNLOCKED   ; unlocked, do nothing

    outputk 3,VRAM_CTRL ; enable display
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
    input s0,FRAMECNT     ; frame counter
    compare s0,0
    jump nz,SCREEN
    ; invert LED signal
    add sb,1

SCREEN:

    outputk 3,VRAM_ROW
    load s4,msg0'upper
    load s3,msg0'lower
    call write_string
    outputk 4,VRAM_ROW
    load s4,msg1'upper
    load s3,msg1'lower
    call write_string
    outputk 5,VRAM_ROW
    load s4,msg2'upper
    load s3,msg2'lower
    call write_string
    outputk 6,VRAM_ROW
    load s4,msg3'upper
    load s3,msg3'lower
    call write_string

    ; show the expired message if needed
    input s6,STATUS
    test s6,2
    jump z,not_expired
    outputk 8,VRAM_ROW
    load s4,expired'upper
    load s3,expired'lower
    call write_string
not_expired:
    outputk 8,VRAM_ROW
    load s4,msg4'upper
    load s3,msg4'lower
    call write_string
    outputk 9,VRAM_ROW
    load s4,msg5'upper
    load s3,msg5'lower
    call write_string

CLOSE_FRAME:
    output sb,LED
    return

write_string:
    load s0,0
.loop:
    call@ (s4,s3)
    sub s2,20
    output s0,VRAM_COL
    output s2,A
    add s0,1
    compare s0,20
    return z
    add s3,1
    addcy s4,0
    jump .loop

    ; s0 screen row address
    ; s1 number to write
    ; modifies s2
    ; s0 updated to point to the next column
WRITE_HEX:
    output s0,VRAM_COL
    load s2,s1
    sr0 s2
    sr0 s2
    sr0 s2
    sr0 s2
    call WRITE_HEX4
    add s0,1
    output s0,VRAM_COL
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
    output s2,VRAM_DATA
    return

    ; clear screen
    ; modifies s0,s1,s2
CLS:
    load s0,31
    load s1,31
    load s2,0
.loop_row:
    load s1,31
    output s0,VRAM_COL
.loop_col:
    output s1,VRAM_ROW
    output s2,a
    sub s1,1
    jump nc,.loop_col
    sub s0,1
    jump nc,.loop_row
    return

UNLOCKED:
    output s0,WATCHDOG
    jump UNLOCKED

; strings
string beta0$,  "    (c) Jotego 2023             "
string beta1$,  "    This core is in beta phase  "
string beta2$,  "    Join the beta test team at  "
string beta3$,  "   https://patreon.com/jotego "
string beta4$,  "    Place the file jtbeta.zip   "
string beta5$,  "    in the folder games/mame    "
string expired$,"    This beta RBF has expired   "
msg0:
    load&return s2, beta0$
msg1:
    load&return s2, beta1$
msg2:
    load&return s2, beta2$
msg3:
    load&return s2, beta3$
msg4:
    load&return s2, beta4$
msg5:
    load&return s2, beta5$
expired:
    load&return s2, expired$

default_jump fatal_error
fatal_error:
    jump fatal_error

    address 3FF    ; interrupt vector
    jump ISR
