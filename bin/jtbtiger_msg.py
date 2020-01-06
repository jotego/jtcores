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
print_char("     Black Tiger/Dragon         ")
print_char("       clone for FPGA           ")
print_char("    brought to you by jotego.   ")
print_char("  http://patreon.com/topapate   ")
print_char("                                ")
print_char("  andrew moore - andyways       ")
print_char("  don gafford  - j. slowfret    ")
print_char("  kyle good    - leslie law     ")
print_char("  m. astudillo - mary marshall  ")
print_char("  matthew young- oliver jaksch  ")
print_char("  blackstar    - oscar laguna   ")
print_char("  roman buser  - ryan fig       ")
print_char("  steve suavek - steve wilson   ") 
print_char("  toby boreham - xzarian        ")
print_char("                                ")
print_char("           xzarian              ")
print_char("         sembiance              ") # I haven't got the Avater
print_char("       victor gomariz           ")
print_char("       ultrarobotninja          ")
print_char("       william clemens          ") # Declined the Avatar
print_char("                                ")
print_char("                                ")
print_char("                                ")
print_char("                                ")
print_char("                                ")
print_char("                                ")
print_char("                                ")
print_char("                                ")
print_char("                                ")

save_hex( os.environ['JTGNG']+"/cores/btiger/mist/msg.hex", char_ram )
save_bin( os.environ['JTGNG']+"/cores/btiger/ver/game/msg.bin", char_ram )


#################################################################
def convert_buf( buf, k, msg ):
    for cnt in range(len(msg)):
        buf[k] = ascii_conv[ msg[cnt] ]
        k+=1
    return k

#  Avatars:
#1 Daniel Bauza
#2 Brian Sallee
#3 Dustin Hubbard
#4 Frederic Mahe
#5 Jo Tomiyori
#6 Phillip McMahon
#7 Scralings
#8 Sembiance -- but I don't have the image!
#9 Suvodip Mitra
#A Arcade Express


#           00000000000000001111111111111111
#           0123456789ABCDEF0123456789ABCDEF
av_buf=bytearray(32*16)
av_pos=0
for cnt in range(len(av_buf)):
    av_buf[cnt]=32

av_pos=convert_buf(av_buf,av_pos,"           Scralings            ")
av_pos=convert_buf(av_buf,av_pos,"           Suverman             ")
av_pos=convert_buf(av_buf,av_pos,"        Frederic Mahe           ")
av_pos=convert_buf(av_buf,av_pos,"        Jo Tomiyori             ")
av_pos=convert_buf(av_buf,av_pos,"         Brian Sallee           ")
av_pos=convert_buf(av_buf,av_pos,"       Phillip McMahon          ")
av_pos=convert_buf(av_buf,av_pos,"        Dustin Hubbard          ")
av_pos=convert_buf(av_buf,av_pos,"         Daniel Bauza           ")
av_pos=convert_buf(av_buf,av_pos,"        Arcade Express          ")
save_hex( os.environ['JTGNG']+"/cores/btiger/mist/msg_av.hex", av_buf )

# Andrew Moore
# Andyways
# Don Gafford
# Jorge Slowfret
# Kyle Good
# Leslie Law
# Manuel Astudillo
# Mary Marshall
# Matthew Young
# Oliver Jaksch
# Oliver Wndmth
# Oscar Laguna Garcia
# Roman Buser
# Ryan Fig
# Steve Suavek
# Steven Wilson
# Toby Boreham
# Ultrarobotninja
# Victor Gomariz Ladron de Guevara
# Xzarian
# 
# Avatar
# 
# Brian Sallee
# Daniel Bauza
# Dustin Hubbard
# Frederic Mahe
# Jo Tomiyori
# Phillip McMahon
# Scralings
# Sembiance
# Suvodip Mitra
# William Clemens
# Arcade Express