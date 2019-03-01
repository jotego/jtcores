#!/usr/bin/python
# Message in the pause menu

ascii_conv = {
    '0':0, '1':1, '2':2, '3':3, '4':4, '5':5,
    '6':6, '7':7, '8':8, '9':9,
    'A':0XA, 'B':0XB, 'C':0XC, 'D':0XD, 'E':0XE, 'F':0XF,
    'G':0X10, 'H':0X11, 'I':0X12, 'J':0X13, 'K':0X14, 'L':0X15,
    'M':0X16, 'N':0X17, 'O':0X18, 'P':0X19, 'Q':0X1A, 'R':0X1B,
    'S':0X1C, 'T':0X1D, 'U':0X1E, 'V':0X1F, 'W':0X20, 'X':0X21,
    'Y':0X22, 'Z':0X23, ' ':0x24, '.':0x2B, '&':0x3A, '?':0x68,
    '!':0x66, '%':0x2D, '(':0x30, ')':0x31, '#':0x2f, ',':0x2A,
    '-':0x37, '+':0x36, ':':0x2c, '/':0xce, '=':0x38, '*':0x2e,
    'a':0x9a, 'b':0x9b, 'c':0x9c, 'd':0x9d, 'e':0x9e, 'f':0x9f,
    'g':0xa0, 'h':0xa1, 'i':0xa2, 'j':0xa3, 'k':0xa4, 'l':0xa5,
    'm':0xa6, 'n':0xa7, 'o':0xa8, 'p':0xa9, 'q':0xaa, 'r':0xab,
    's':0xac, 't':0xad, 'u':0xae, 'v':0xaf, 'w':0xb0, 'x':0xb1,
    'y':0xb2, 'z':0xb3, '@':0xd8
}

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
        char_ram[pos] = ascii_conv[a]
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
print_char("      1943 clone for FPGA       ")
print_char("    brought to you by jotego.   ")
print_char("  http://patreon.com/topapate   ")
print_char("                                ")
print_char("       Thanks to my patrons     ") 
print_char("                                ")
print_char("   This is a BETA version       ")
print_char("        do not distribute!      ")
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
print_char("                                ")
print_char("                                ")
print_char("                                ")
print_char("                                ")
print_char("                                ")
print_char("                                ")
print_char("                                ")
print_char("                                ")

save_hex( "../1943/mist/1943_msg.hex", char_ram )
save_bin( "../1943/ver/game/1943_msg.bin", char_ram )
