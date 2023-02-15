; Homebrew replacement for Tough Turf MCU code
; (c) Jose Tejada 2021

    LJMP INIT
    RETI
.ORG 0XB
    RETI
.ORG 0X13
    RETI
.ORG 0X1B
    RETI
.ORG 0X23
    RETI
.ORG 0X2B
    RETI

.ORG 0X100
INIT:
    MOV TCON,#0x45  ; Disable timers, set EXT0 edge trigger

    MOV p1,#0xFF    ; Disables interrupts and resets for M68000

