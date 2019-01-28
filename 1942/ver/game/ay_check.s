    DI
    LD IX,$8000 ; first AY
    LD IY,$C000 ; second AY

    LD A,$02
    LD (IX+1),A
    LD (IY+1),A

    LD A,$f
    LD B,8
    LD (IX+0),B
    LD (IX+1),A
    LD (IY+0),B
    LD (IY+1),A



END:
    JP END    