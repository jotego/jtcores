    DI
    LD IX,$c005
RANDOM_TEST:
    ; Random write address
    LD L,(IX+0)    ; random value
    LD A,(IX+0)
    AND $3
    ADD A,$d8
    LD H,A
    ; Random value to write
    LD A,(IX+0)
    LD (HL),A
    LD D,A      ; save the value to compare later
    ; Random wait
    LD A,(IX+0)
    AND $3
    LD B,A
WAIT:
    DJNZ WAIT
    ; Compare value
    LD A,D
    LD D,(HL)
    CP D
    JP Z,RANDOM_TEST
    ; There was an error
    LD HL,$DEAD
    LD A,(IX+1)    ; Finish the simulation
FIN:
    JP FIN

    DW 0,0,0,0
