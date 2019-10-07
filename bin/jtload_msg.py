#!/usr/bin/python
# Prompt to add the ROM file
# this is meant to be load in the attributes half of the memory

import os

ascii_conv = {
    ' ':0, '*':1
}

char_ram = [ 0 for x in range(0x400) ]
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



#           00000000001111111111222222222233
#           01234567890123456789012345678901
print_char("                                ") 
print_char("                                ")
print_char("     ****     **      ***       ")
print_char("     *       * *     *   *      ")
print_char("     ****      *       **       ") 
print_char("     *         *     **         ")
print_char("     *       ****    *****      ")
print_char("                                ")
print_char("                                ")
print_char("                                ")
print_char("    ****     ***   *    *       ")
print_char("    *   *   *   *  **  **       ")
print_char("    * *     *   *  * ** *       ")
print_char("    * *     *   *  *    *       ")
print_char("    *   *    ***   *    *       ")
print_char("                                ")
print_char("                                ")
print_char("                                ")
print_char("    *     **    **    ***       ")
print_char("    *    *  *  *  *   *  *      ")
print_char("    *    *  *  ****   *  *      ")
print_char("    *    *  *  *  *   *  *      ")
print_char("    ****  **   *  *   ***       ")
print_char("                                ")
print_char("                                ")
print_char("                                ")
print_char("                                ")

save_hex( os.environ['JTGNG']+"/modules/rom_loadv.hex", char_ram )
