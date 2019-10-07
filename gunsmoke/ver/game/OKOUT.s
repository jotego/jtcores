    DI
    ; Turn OBJ ON
    LD DE,0xD806
    LD A,0x30
    LD (DE),A
    ; Write a random object
    LD DE,0xFF00
    LD A,55
    LD (DE),A
    LD DE,0xFF01
    LD (DE),A
    LD DE,0xFF02
    LD (DE),A
    LD DE,0xFF03
    LD (DE),A
    LD DE,0xC806
    LD (DE),A
end: 
    jp end