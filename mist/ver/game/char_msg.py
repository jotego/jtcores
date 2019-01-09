#!/usr/bin/python

char_ram = [ x%256 for x in range(0x800) ]
scr_ram  = [ 0     for x in range(0x800) ]

def save_hex(filename, data):
    f = open(filename,"w")
    for k in data:
        f.write( hex(k)[2:] )
        f.write( "\n" )
    f.close()

def print_char( msg, col, row ):
    pos = row + (col<<8)
    for a in msg:
        char_ram[pos] = ord(a)
        pos = pos+1

r_g  = [ 0 for x in range(256) ]
blue = [ 0 for x in range(256) ]

for col in range(256):
    r_g  [col] = (col%8)| 0x80 | ((col%8)<<4)
    blue [col] = col%16


print_char("Hola mundo", 5, 10)
for x in range(0x400,0x800):
    char_ram[x] = 0

save_hex("rg_ram.hex", r_g  )
save_hex( "b_ram.hex", blue )
save_hex( "char_ram.hex", char_ram )
save_hex( "scr_ram.hex",  scr_ram  )