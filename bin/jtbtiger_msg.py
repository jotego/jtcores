#!/usr/bin/python
# Message in the pause menu
import os

ascii_conv = {
    '0':0, '1':1, '2':2, '3':3, '4':4, '5':5,
    '6':6, '7':7, '8':8, '9':9,
    'a':0x61, 'b':0x62, 'c':0x63, 'd':0x64, 'e':0x65, 'f':0x66,
    'g':0x67, 'h':0x68, 'i':0x69, 'j':0x6a, 'k':0x6b, 'l':0x6c,
    'm':0x6d, 'n':0x6e, 'o':0x6f, 'p':0x70, 'q':0x71, 'r':0x72,
    's':0x73, 't':0x74, 'u':0x75, 'v':0x76, 'w':0x77, 'x':0x78,
    'y':0x79, 'z':0x7a, '.':0x2e, '-':0x2d, '&':0x26, '?':0x3f,
    '!':0x21, '%':0x25, '(':0x28, ')':0x29, '#':0x23, ',':0x2c,
    '+':0x2b, ':':0x3a, '/':0x2f, '=':0x3d, '*':0x2a, "'":0x27,
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
print_char("        BLACK TIGER             ")
print_char("       CLONE FOR FPGA           ")
print_char("    BROUGHT TO YOU BY JOTEGO.   ")
print_char("  HTTP://PATREON.COM/TOPAPATE   ")
print_char("                                ")
print_char("      THANKS TO MY PATRONS      ")
print_char("                                ")
print_char("                                ")
print_char("      BETA VERSION              ")
print_char("                                ")
print_char("                                ")
print_char("      DO NOT DISTRIBUTE         ")
print_char("                                ")
print_char("                                ")
print_char("     SPECIAL THANKS TO          ")
print_char("      MANUEL ASTUDILLO          ")
print_char("                                ")
print_char("     FOR DONATING A             ")
print_char("       BLACK TIGER PCB          ")
print_char("         FOR RESEARCH           ")
print_char("                                ")
print_char("                                ")
print_char("                                ")
print_char("                                ")
print_char("                                ")
print_char("                                ")
print_char("                                ")
print_char("                                ")
print_char("                                ")

save_hex( os.environ['JTGNG']+"/btiger/mist/msg.hex", char_ram )
save_bin( os.environ['JTGNG']+"/btiger/ver/game/msg.bin", char_ram )
