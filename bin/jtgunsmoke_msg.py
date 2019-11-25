#!/usr/bin/python
# Message in the pause menu
import os

ascii_conv = {
    '0':0, '1':1, '2':2, '3':3, '4':4, '5':5,
    '6':6, '7':7, '8':8, '9':9,
    'a':0xa,  'b':0xb,  'c':0xc,  'd':0xd,  'e':0xe,  'f':0xf,
    'g':0x10, 'h':0x11, 'i':0x12, 'j':0x13, 'k':0x14, 'l':0x15,
    'm':0x16, 'n':0x17, 'o':0x18, 'p':0x19, 'q':0x1a, 'r':0x1b,
    's':0x1c, 't':0x1d, 'u':0x1e, 'v':0x1f, 'w':0x20, 'x':0x21,
    'y':0x22, 'z':0x23, '.':0x2b, '-':0x37, '&':0x3a,
    '!':0x66, '%':0x2d, '(':0x30, ')':0x31, '#':0x2f, ',':0x2a,
    '-':0x37, '+':0x36, ':':0x2c, '/':0xc0, '=':0x38, '*':0x2d,
    ' ':0x24
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
print_char("                                ")
print_char("    gunsmoke clone by jotego    ")
print_char("  http://patreon.com/topapate   ")
print_char("       thanks to my patrons     ") 
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
print_char("                                ")
print_char("                                ")
print_char("                                ")

save_hex( os.environ['JTGNG']+"/cores/gunsmoke/mist/msg.hex", char_ram )
save_bin( os.environ['JTGNG']+"/cores/gunsmoke/ver/game/msg.bin", char_ram )

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


#           00000000000000001111111111111111
#           0123456789ABCDEF0123456789ABCDEF
av_buf=bytearray(32*16)
av_pos=0
av_pos=convert_buf(av_buf,av_pos,"             scralings          ")
av_pos=convert_buf(av_buf,av_pos,"             suverman           ")
av_pos=convert_buf(av_buf,av_pos,"          frederic mahe         ")
av_pos=convert_buf(av_buf,av_pos,"          jo tomiyori           ")
av_pos=convert_buf(av_buf,av_pos,"           brian sallee         ")
av_pos=convert_buf(av_buf,av_pos,"         phillip mcmahon        ")
av_pos=convert_buf(av_buf,av_pos,"          dustin hubbard        ")
av_pos=convert_buf(av_buf,av_pos,"           daniel bauza         ")
save_hex( os.environ['JTGNG']+"/cores/gunsmoke/mist/msg_av.hex", av_buf )