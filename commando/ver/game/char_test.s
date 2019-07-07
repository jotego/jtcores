    DI

    LD SP,$0
    CALL CLRCHR
    LD DE,$d044
    LD HL,MSG
    LD BC,10

    LDIR
FIN:
    JP FIN

CLRCHR:
    LD HL,$D000
    LD A,' ' 
    LD C,4
CLRCHR2:
    LD B,0
CLRCHR1:
    LD (HL),A
    INC HL
    DJNZ CLRCHR1
    DEC C
    JR NZ,CLRCHR2
    RET


MSG:
    DB "hola mundo"
