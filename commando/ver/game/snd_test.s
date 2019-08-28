    DI
    LD SP,$0
    LD HL,$C800
    LD A,1
    LD (HL),A
FIN:
    JP FIN
