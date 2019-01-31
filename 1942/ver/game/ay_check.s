    DI
    LD IX,$8000 ; first AY
    LD IY,$C000 ; second AY

    LD A,$02
    LD (IX+1),A
    LD A,$05
    LD (IY+1),A

    LD A,$f
    LD B,8
    LD (IX+0),B
    LD (IX+1),A
    LD (IY+0),B
    LD  A,$e
    LD (IY+1),A

    LD B,10
WAIT:
    DJNZ WAIT    
    ; go for noise
    LD A,6
    LD (IX+0),A
    LD A,3
    LD (IX+1),A
END:
    JP END    