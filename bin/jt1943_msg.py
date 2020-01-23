#!/usr/bin/python
# Message in the pause menu
import os

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

char_ram = [ 0x24 for x in range(0x400) ]
row=31

def save_hex(filename, data):
    with open(filename,"w") as f:
        for k in data:
            f.write( "%X\n" % k )

def save_bin(filename, data):
    with open(filename,"wb") as f:
        f.write( bytearray(data) )

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


# MiSTer:
#           00000000001111111111222222222233
#           01234567890123456789012345678901
print_char("      1943 clone for FPGA       ")
print_char("    brought to you by jotego.   ")
print_char("  http://patreon.com/topapate   ")
print_char("                                ")
print_char("       Thanks to my patrons     ") 
print_char("                                ")
print_char("    Andrew Moore                ")
print_char("    Andyways                    ")
print_char("    Blackstar                   ") 
print_char("    Dave Ross                   ")
print_char("    Don Gafford                 ")
print_char("    Leslie Law                  ")
print_char("    Mary Marshall               ")
print_char("    Mark Kohler (NML32)         ")
print_char("    Matthew Coyne               ")
print_char("    Oliver Jaksch               ")
print_char("    Oscar Laguna Garcia         ")
print_char("    Roman Buser                 ")
print_char("    SmokeMonster                ")
print_char("    Ultrarobotninja             ")
print_char("    Victor Gomariz L. de G.     ")

def convert_buf( buf, k, msg ):
    for cnt in range(len(msg)):
        buf[k] = ascii_conv[ msg[cnt] ]
        k+=1
    return k

# Patreons with Avatar:
# Scralings, Suverman, Frederic Mahe, Jo Tomiyori, Brian Sallee, FULLSET, Phillip McMahon, Dustin Hubbard

save_hex( os.environ['JTROOT']+"/cores/1943/mist/msg_mister.hex", char_ram )

# Message for MiST (no Avatars)
row=31
#           00000000001111111111222222222233
#           01234567890123456789012345678901
print_char("      1943 clone for FPGA       ")
print_char("    brought to you by jotego.   ")
print_char("  http://patreon.com/topapate   ")
print_char("                                ")
print_char("       Thanks to my patrons     ") 
print_char("                                ")
print_char("    Andrew Moore                ")
print_char("    Andyways                    ")
print_char("    Blackstar                   ") 
print_char("    Dave Ross                   ")
print_char("    Don Gafford                 ")
print_char("    Leslie Law                  ")
print_char("    Mary Marshall               ")
print_char("    Mark Kohler (NML32)         ")
print_char("    Matthew Coyne               ")
print_char("    Oliver Jaksch               ")
print_char("    Oscar Laguna Garcia         ")
print_char("    Roman Buser                 ")
print_char("    SmokeMonster                ")
print_char("    Ultrarobotninja             ")
print_char("    Victor Gomariz L. de G.     ")
# print_char("    Scralings                   ")
# print_char("    Suverman                    ")
# print_char("    Frederic Mahe               ")
# print_char("    Jo Tomiyori                 ")
# print_char("    Brian Sallee                ")
# print_char("    FULLSET                     ")
# print_char("    Phillip McMahon             ")
# print_char("    Dustin Hubbard              ")
save_hex( os.environ['JTROOT']+"/cores/1943/mist/msg.hex", char_ram )
save_bin( os.environ['JTROOT']+"/cores/1943/ver/game/msg.bin", char_ram )


#           00000000000000001111111111111111
#           0123456789ABCDEF0123456789ABCDEF
av_buf=bytearray(32*10)
av_pos=0
av_pos=convert_buf(av_buf,av_pos,"            Scralings           ") # 1
av_pos=convert_buf(av_buf,av_pos,"            Suverman            ") # 2 
av_pos=convert_buf(av_buf,av_pos,"          Frederic Mahe         ") # 3
av_pos=convert_buf(av_buf,av_pos,"           Jo Tomiyori          ") # 4 
av_pos=convert_buf(av_buf,av_pos,"           Brian Sallee         ") # 5
av_pos=convert_buf(av_buf,av_pos,"             FULLSET            ") # 6
av_pos=convert_buf(av_buf,av_pos,"         Phillip McMahon        ") # 7
av_pos=convert_buf(av_buf,av_pos,"          Dustin Hubbard        ") # 8
av_pos=convert_buf(av_buf,av_pos,"           Daniel Bauza         ") # 9
av_pos=convert_buf(av_buf,av_pos,"          Arcade Express        ") # 10
save_hex( os.environ['JTROOT']+"/cores/1943/mist/msg_av.hex", av_buf )