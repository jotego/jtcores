    DI
    LD IX,0xC800

LOOP:
    LD A,$2
    LD (IX+0),A
    ;LD (IX+1),A

    LD B,0
WAIT:
    DJNZ WAIT
    LD B,0
    DJNZ WAIT
;    LD B,0
;    DJNZ WAIT
;    JP LOOP    
end: 
    jp end