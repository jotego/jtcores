#!/usr/bin/python
# Message in the pause menu
import os

char_ram = [ 0x70 for x in range(0x400) ]
row=31

def save_hex(filename, data):
    with open(filename,"w") as f:
        for k in data:
            f.write( "%X" % k )
            f.write( "\n" )
        f.close()

def save_bin(filename, data):
    with open(filename,"wb") as f:
        f.write( bytearray(data) )
        f.close()

def print_char( msg ):
    global row
    pos = row
    for a in msg:
        char_ram[pos] = ord(a)
        pos = pos+32
    row = row-1

r_g  = [ 0 for x in range(256) ]
blue = [ 0 for x in range(256) ]

for col in range(256):
    r_g  [col] = (col%8)| 0x80 | ((col%8)<<4)
    blue [col] = col%16



#           00000000001111111111222222222233
#           01234567890123456789012345678901
print_char("                                ")
print_char("                                ")
print_char("    Vulgus clone for FPGA       ")
print_char("    brought to you by jotego.   ")
print_char("  http.//patreon.com/topapate   ")
print_char("                                ")
print_char("       thanks to my patrons     ")
print_char("                                ")
print_char("  Directors: Scralings          ")
print_char("             Suv                ")
print_char("             Frederic Mahe      ")
print_char("                                ")
print_char("                                ")
print_char("                                ")
print_char("                                ")
print_char("     Beta version               ")
print_char("                                ")
print_char("       DO NOT DISTRIBUTE        ")
print_char("                                ")
print_char("                                ")
print_char("                                ")
print_char("                                ")
print_char("                                ")
print_char("                                ")
print_char("                                ")
print_char("                              , ")
print_char("                              , ")
print_char("                              , ")
print_char("                              , ")
print_char("                                ")
print_char("                                ")
print_char("                                ")

save_hex( os.environ['JTGNG_ROOT']+"/vulgus/mist/msg.hex", char_ram )
# save_bin( os.environ['JTGNG_ROOT']+"/vulgus/ver/game/msg.bin", char_ram )
