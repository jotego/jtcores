        LD A,0
        LD HL, $C000
LOOP:   INC A
        LD B,A
        LD (HL),B
        LD B,0
        LD B,(HL)
        INC HL
        JP LOOP
