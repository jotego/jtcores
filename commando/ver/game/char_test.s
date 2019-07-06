    DI
    LD SP,$0
    LD IX,$d044
    PUSH IX
    POP DE
    LD IX,MSG
    PUSH IX
    POP HL
    LD BC,10

    ; LDIR
FIN:
    JP FIN

MSG:
    DB "hola mundo"
