#!/usr/bin/python
# Message in the pause menu
import os

ascii_conv = {
    '0':0, '1':1, '2':2, '3':3, '4':4, '5':5,
    '6':6, '7':7, '8':8, '9':9,
    '.':0x2e, "'":0x22,
    '!':0x21,                                         ',':0x2c,
              ':':0x3a,           '=':0x3d,                    
    'A':0x41, 'B':0x42, 'C':0x43, 'D':0x44, 'E':0x45, 'F':0x46,
    'G':0x47, 'H':0x48, 'I':0x49, 'J':0x4a, 'K':0x4b, 'L':0x4c,
    'M':0x4d, 'N':0x4e, 'O':0x4f, 'P':0x50, 'Q':0x51, 'R':0x52,
    'S':0x53, 'T':0x54, 'U':0x55, 'V':0x56, 'W':0x57, 'X':0x58,
    'Y':0x59, 'Z':0x5a,
    ' ':0x20
}

char_ram = [ 0x20 for x in range(0x400) ]
row=0

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
        char_ram[pos] = ascii_conv[a]
        pos = pos+1
    row = row+32

r_g  = [ 0 for x in range(256) ]
blue = [ 0 for x in range(256) ]

for col in range(256):
    r_g  [col] = (col%8)| 0x80 | ((col%8)<<4)
    blue [col] = col%16



#           00000000001111111111222222222233
#           01234567890123456789012345678901
print_char("                                ")
print_char("        BIONIC COMMANDO         ")
print_char("        CLONE FOR FPGA          ")
print_char("    BROUGHT TO YOU BY JOTEGO.   ")
print_char("  HTTP:!!PATREON.COM!TOPAPATE   ")
print_char("                                ")
print_char("       THANKS TO MY PATRONS     ")
print_char("                                ")
print_char("  DIRECTORS: SCRALINGS          ")
print_char("             SUV                ")
print_char("             FREDERIC MAHE      ")
print_char("                                ")
print_char("                                ")
print_char("                                ")
print_char("                                ")
print_char("     BETA VERSION               ")
print_char("                                ")
print_char("       DO NOT DISTRIBUTE        ")
print_char("                                ")
print_char("                                ")
print_char("                                ")
print_char("                                ")
print_char("                                ")
print_char("                                ")
print_char("                                ")
print_char("                                ")
print_char("                                ")
print_char("                                ")
print_char("                                ")
print_char("                                ")

save_hex( os.environ['JTGNG']+"/biocom/mist/msg.hex", char_ram )
save_bin( os.environ['JTGNG']+"/biocom/ver/game/msg.bin", char_ram )
