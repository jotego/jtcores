    DI
    LD HL,0x8000
    LD IX,0xA000
    LD DE,0xC806

    LD B,2
bank_loop:
    LD A,B
    LD (DE),A
    LD A,(HL)
    LD A,(IX+0)
    DEC B
    JP P,bank_loop

    IM 0
    EI

end: 
    EI
    jp end