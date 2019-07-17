#!/usr/bin/python
# Message in the pause menu
import os

ascii_conv = {
    '0':0, '1':1, '2':2, '3':3, '4':4, '5':5,
    '6':6, '7':7, '8':8, '9':9,
    'a':0x41, 'b':0x42, 'c':0x43, 'd':0x44, 'e':0x45, 'f':0x46,
    'g':0x47, 'h':0x48, 'i':0x49, 'j':0x4a, 'k':0x4b, 'l':0x4c,
    'm':0x4d, 'n':0x4e, 'o':0x4f, 'p':0x50, 'q':0x51, 'r':0x52,
    's':0x53, 't':0x54, 'u':0x55, 'v':0x56, 'w':0x57, 'x':0x58,
    'y':0x59, 'z':0x5a, '.':0x5b, ',':0x2f, '=':0x3a,
    'A':0x81, 'B':0x82, 'C':0x83, 'D':0x84, 'E':0x85, 'F':0x86,
    'G':0x87, 'H':0x88, 'I':0x89, 'J':0x8a, 'K':0x8b, 'L':0x8c,
    'M':0x8d, 'N':0x8e, 'O':0x8f, 'P':0x90, 'Q':0x91, 'R':0x92,
    'S':0x93, 'T':0x94, 'U':0x95, 'V':0x96, 'W':0x97, 'X':0x98,
    'Y':0x99, 'Z':0x9a,
    ' ':0x20, '/':0x7f
}

char_ram = [ 0x20 for x in range(0x400) ]
# Start from the top right corner of the horizontal screen
# as this hardware is rotated
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
        #print "pos %X <- %c" % ( pos, chr(char_ram[pos]))
        pos = pos+32
    row = row-1

r_g  = [ 0 for x in range(256) ]
blue = [ 0 for x in range(256) ]

for col in range(256):
    r_g  [col] = (col%8)| 0x80 | ((col%8)<<4)
    blue [col] = col%16



#           00000000001111111111222222222233
#           01234567890123456789012345678901
print_char("   00                      00   ")
print_char("   01                      01   ")
print_char("   02    commando FPGA clone    ")
print_char("   03  brought to you by jotego.")
print_char("   04     patreon.com/topapate  ")
print_char("   05                      05   ")
print_char("   06    thanks to my patrons   ")
print_char("   07                      07   ")
print_char("   08                      08   ")
print_char("   09  BETA VERSION        09   ")
print_char("   0A                      0A   ")
print_char("   0B                      0B   ")
print_char("   0C     DO NOT DISTRIBUTE     ")
print_char("   0D                      0D   ")
print_char("   0E                      0E   ")
print_char("   0F   001111111111222222222233")
print_char("   10   890123456789012345678901")
print_char("   11                      11   ")
print_char("   12                      12   ")
print_char("   13                      13   ")
print_char("   14                      14   ")
print_char("   15                      15   ")
print_char("   16                      16   ")
print_char("   17                      17   ")
print_char("   18                      18   ")
print_char("   19                      19   ")
print_char("   1A                      1A   ")
print_char("   1B                      1B   ")
print_char("   1C                      1C   ")
print_char("   1D                      1D   ")
print_char("   1E                      1E   ")
print_char("   1F                      1F   ")

save_hex( os.environ['JTGNG_ROOT']+"/commando/mist/msg.hex", char_ram )
save_bin( os.environ['JTGNG_ROOT']+"/commando/ver/game/msg.bin", char_ram )
