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
    LD B,A
    ; Random wait
    LD A,(IX+0)
    AND $3
    LD D,A
WAIT:
    DJNZ WAIT
    ; Compare value
    LD A,B
    CP (HL)
    JP NZ,RANDOM_TEST
    ; There was an error
    LD HL,$DEAD
    LD (IX+1),A    ; Finish the simulation
