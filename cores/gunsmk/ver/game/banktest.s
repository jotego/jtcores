    DI
    LD DE,0xc804
    LD A,0x0
    LD (DE),A
    LD HL,0x8000
    LD B,(HL)
    LD HL,0xafff
    LD B,(HL)

    ; Bank 1
    LD A,4
    LD (DE),A
    LD HL,0x8000
    LD B,(HL)
    LD HL,0xafff
    LD B,(HL)

    ; Bank 2
    LD A,8
    LD (DE),A
    LD HL,0x8000
    LD B,(HL)
    LD HL,0xafff
    LD B,(HL)

    ; Bank 3
    LD A,12
    LD (DE),A
    LD HL,0x8000
    LD B,(HL)
    LD HL,0xafff
    LD B,(HL)

end: 
    jp end