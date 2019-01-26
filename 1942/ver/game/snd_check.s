    DI
    LD IX,0xC800

    LD A,$AA
    LD (IX+0),A
    LD A,$55
    LD (IX+1),A
end: 
    jp end