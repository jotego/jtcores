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
print_char("    Vulgus   clone by jotego    ")
print_char("  http://patreon.com/topapate   ")
print_char("       Requested by F. Mahe     ")
print_char("       Thanks to my patrons     ") 
print_char("                                ")
print_char("       Frederic Mahe            ")
print_char("         Scralings              ")
print_char("       Suvodip Mitra            ")
print_char("                                ")
print_char("       Daniel Bauza             ")
print_char("       Brian Sallee             ")
print_char("       Dustin Hubbard           ")
print_char("         Jo Tomiyori            ")
print_char("       Phillip McMahon          ")
print_char("         Sembiance              ") # I haven't got the Avater
print_char("       William Clemens          ") # Declined the Avatar
print_char("                                ")
print_char("  Andrew Moore - Andyways       ")
print_char("  Don Gafford  - J. Slowfret    ")
print_char("  Kyle Good    - Leslie Law     ")
print_char("  M. Astudillo - Mary Marshall  ")
print_char("  Matthew Young- Oliver Jaksch  ")
print_char("  Oliver Wndmth- Oscar Laguna   ")
print_char("  Roman Buser  - Ryan Fig       ")
print_char("  Steve Suavek - Steve Wilson   ") 
print_char("  Tony Boreham - Xzarian        ")
print_char("                                ")
print_char("           Xzarian              ")
print_char("       Victor Gomariz           ")
print_char("       Ultrarobotninja          ")
print_char("                                ")

save_hex( os.environ['JTGNG']+"/vulgus/mist/msg.hex", char_ram )
# save_bin( os.environ['JTGNG']+"/vulgus/ver/game/msg.bin", char_ram )

#################################################################
def convert_buf( buf, k, msg ):
    for cnt in range(len(msg)):
        buf[k] = ord( msg[cnt] )
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
save_hex( os.environ['JTGNG']+"/vulgus/mist/msg_av.hex", av_buf )