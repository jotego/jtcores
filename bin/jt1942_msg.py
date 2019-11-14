#!/usr/bin/python
# Message in the pause menu
import os

ascii_conv = {
    '0':0, '1':1, '2':2, '3':3, '4':4, '5':5,
    '6':6, '7':7, '8':8, '9':9,
    'a':0xa, 'b':0xb, 'c':0xc, 'd':0xd, 'e':0xe, 'f':0xf,
    'g':0x10, 'h':0x11, 'i':0x12, 'j':0x13, 'k':0x14, 'l':0x15,
    'm':0x16, 'n':0x17, 'o':0x18, 'p':0x19, 'q':0x1a, 'r':0x1b,
    's':0x1c, 't':0x1d, 'u':0x1e, 'v':0x1f, 'w':0x20, 'x':0x21,
    'y':0x22, 'z':0x23, '.':0x24, '-':0x25, '&':0x26, '?':0x27,
    '!':0x28, '%':0x29, '(':0x2a, ')':0x2b, '#':0x2f, ',':0x34,
    '-':0x35, '+':0x36, ':':0x44, '/':0x46, '=':0x4a, '*':0x4b,
    ' ':0x70
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
        char_ram[pos] = ascii_conv[a.lower()]
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
print_char("      1942 clone for fpga       ")
print_char("    brought to you by jotego.   ")
print_char("  http://patreon.com/topapate   ")
print_char("                                ")
print_char("       thanks to my patrons     ")
print_char("                                ")
print_char("  directors: scralings          ")
print_char("             suvodip mitra      ")
print_char("             frederic mahe      ")
print_char("  Blackstar                     ")
print_char("  Don Gafford                   ")
print_char("  Dustin Hubbard                ")
print_char("  Leslie Law                    ")
print_char("  Matthew Coyne                 ")
print_char("  Mary Marshall                 ")
print_char("  Oscar Laguna Garcia           ")
print_char("  SmokeMonster - Youtube chan!  ")
print_char("                                ")
print_char("  Hardware Support From:        ")
print_char("                                ")
print_char("           Manuferhi            ")
print_char("        Antonio Villena         ")
print_char("  Ricardo Saraiva-Retroshop.pt  ")
print_char("                                ")
print_char("  Greetings to Alexey Melnikov, ")
print_char("  Gyurco for his MiST Support   ")
print_char("    and AmigaWave YT channel!   ")
print_char("                                ")

save_hex( os.environ['JTGNG']+"/1942/mist/msg.hex", char_ram )
save_bin( os.environ['JTGNG']+"/1942/ver/game/msg.bin", char_ram )
