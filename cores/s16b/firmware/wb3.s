; Homebrew replacement for Tough Turf MCU code
; (c) Jose Tejada 2021

    LJMP INIT
    LJMP VBLANK
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
    MOV IE,#0x81
    MOV R7,#20      ; power-up time for main CPU, 20 frames
PUP:
    MOV A,R7
    JNZ PUP
IDLE:
    SJMP IDLE

READVAL:
    MOV R0,#7
    MOV A,R1
    MOVX @R0,A
    INC R0
    MOV A,R2
    MOVX @R0,A
    INC R0
    MOV A,R3
    MOVX @R0,A
    MOV R0,#5
    MOV A,#2
    MOVX @R0,A  ; Read
    MOV R0,#2
RDWAIT:
    MOVX A,@R0
    ANL A,#0x40h
    JNZ RDWAIT
    MOV R0,#0
    MOVX A,@R0
    MOV R4,A
    INC R0
    MOVX A,@R0
    MOV R5,A
    RET

WRVAL:
    MOV R0,#0xA
    MOV A,R1
    MOVX @R0,A
    INC R0
    MOV A,R2
    MOVX @R0,A
    INC R0
    MOV A,R3
    MOVX @R0,A
    MOV R0,#0
    MOV A,R4
    MOVX @R0,A
    INC R0
    MOV A,R5
    MOVX @R0,A
    ; trigger write
    MOV R0,#5
    MOV A,#1
    MOVX @R0,A  ; Write
    MOV R0,#2
WRWAIT:
    MOVX A,@R0
    ANL A,#0x40h
    JNZ WRWAIT
    RET

.ORG 0x200
VBLANK:
    MOV IE,#0
    ; Count down frames for power up
    MOV A,R7
    JZ VBLANK_MAIN
    DEC R7
    MOV IE,#0x81
    RETI
VBLANK_MAIN:
    ; Read sound data
    MOV R1,#0xFF
    MOV R2,#0x80
    MOV R3,#4
    ACALL READVAL
    MOV A,R5
    JZ NOSND
    MOV R0,#3
    MOV A,R4
    MOVX @R0,A  ; update sound register
    ; Signal that the command was processed
    MOV R5,#0
    MOV R1,#0xff
    MOV R2,#0x80
    MOV R3,#0x4
    ACALL WRVAL
NOSND:

    ; Set the vertical interrupt
    MOV R0,#4
    MOV A,#0xB
    MOVX @R0,A
    MOV R1,#4
    MOV IE,#0x81
    RETI
