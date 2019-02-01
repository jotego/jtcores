#!/usr/bin/python
# Message in the pause menu

char_ram = [ 20 for x in range(0x400) ]

def save_hex(filename, data):
    f = open(filename,"w")
    for k in data:
        f.write( hex(k)[2:] )
        f.write( "\n" )
    f.close()

def print_char( msg, col, row ):
    pos = row + (col<<8)
    for a in msg:
        char_ram[pos] = ord(a)
        pos = pos+1

r_g  = [ 0 for x in range(256) ]
blue = [ 0 for x in range(256) ]

for col in range(256):
    r_g  [col] = (col%8)| 0x80 | ((col%8)<<4)
    blue [col] = col%16



#           00000000001111111111222222222233
#           01234567890123456789012345678901
print_char("                                ", 0,  0)
print_char("                                ", 0,  1)
print_char("      1942 Clone for FPGA       ", 0,  2)
print_char("    Brought to you by jotego.   ", 0,  3)
print_char("  http://patreon.com/topapate   ", 0,  4)
print_char("                                ", 0,  5)
print_char("       Thanks to my patreons    ", 0,  6) 
print_char("                                ", 0,  7)
print_char("  Directors: Scralings          ", 0,  8)
print_char("             Suvodip Mitra      ", 0,  9)
print_char("                                ", 0, 10)
print_char("  Dustin Hubbard                ", 0, 11)
print_char("  SmokeMonster - Youtube chan!  ", 0, 12)
print_char("  Oscar Laguna Garcia           ", 0, 13)
print_char("  Matthe Coyne                  ", 0, 14)
print_char("  Mary Marshall                 ", 0, 15)
print_char("  Leslie Law                    ", 0, 16)
print_char("  Don Gafford                   ", 0, 17)
print_char("  Hardware Support From:        ", 0, 18)
print_char("  Antonio Villena               ", 0, 19)
print_char("  Manuferhi                     ", 0, 20)
print_char("  Ricardo Saraiva-Retroshop.pt  ", 0, 21)
print_char("                                ", 0, 22)
print_char("  Greetings to Alexey Melnikov! ", 0, 23)
print_char("                                ", 0, 24)

save_hex( "1942_msg.hex", char_ram )
