    DI
    ; Wait
    LD A,10
    LD B,0xFF
wait:
    DJNZ wait
    LD B,0xFF
    DEC A
    JP NZ,wait
    ; Turn OBJ ON
    LD DE,0xc800
    LD A,0x3F
    LD (DE),A
end: 
    jp end