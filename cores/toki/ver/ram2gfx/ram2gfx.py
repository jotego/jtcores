#!/usr/bin/python

# Toki verilog
# Copyright (C) 2024 Solal Jacob
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Convert toki memory dump to image
import sys
import struct
from PIL import Image
import matplotlib.pyplot as plt


def read_file(file_name, path=None):
    if path:
        f = open(path + "/" + file_name, 'rb')
    else:
        f = open(file_name, 'rb')
    buff = f.read()
    return buff


def pack_plan(plans, size=8, flip_x=None):
    packed = []
    for x in range(0, size):
        for y in range(0, size):
            bin_string = f"{plans[0][x][y]}{plans[1][x][y]}{plans[2][x][y]}{plans[3][x][y]}"
            if flip_x:
                packed.append(int(bin_string[::-1], 2))
            else:
                packed.append(int(bin_string, 2))
    return packed


def palette_to_rgb(palette, index, offset):
    # 2048/2 => 1024 entry
    # xxxxBBBBGGGGRRRR
    # palette color are in B G R 444, PIL in RGB
    xb = palette[index*2 + offset]  # 8888
    gr = palette[index*2+1 + offset]

    blue = (xb & 0xf) << 4  # <<4 == *16 to go from 4 to 8 bits
    red = (gr & 0xf) << 4  #
    green = (gr >> 4) << 4  # change for a mask we remove only left nibble

    return (red, green, blue)


def put_pixel(img, palette,  x_pos, y_pos, color, char, palette_offset, x_size=8, y_size=8, rom_index=None):
    for y in range(0, y_size):
        for x in range(0, x_size):
            try:
                palette_index = ((color << 4) ^ char[(y*y_size)+x])
                converted_color = palette_to_rgb(
                    palette, palette_index, palette_offset)

                if converted_color != (0x00, 0x00, 0x00):
                    img.putpixel((x_pos + x, y_pos + y), converted_color)
            except Exception as e:
                print(f'{e} put pixel at {x_pos +x} {y_pos+y}')


def scan_ram(img, ram, gfx_rom, palette, palette_offset, tile_size):
    for screen_index in range(int(len(ram)/2)):
        tile_info = ram[screen_index*2:(screen_index*2)+2]
        if tile_info != b'\x00\x00':
            # 32*8 => 256  (32,32) 1024 tile per screen
            col = int(screen_index % 32)
            row = int(screen_index / 32)  # 32*8 => 256
            x_pos = col*tile_size  # 8 or 16
            y_pos = row*tile_size  # 8 or 16
            rom_index = ((tile_info[0] & 0xf) << 8) + \
                tile_info[1]  # 4096 tile in rom
            color = (tile_info[0] >> 4)

            if tile_size == 8:
                bits_plans = char_bitplanes(gfx_rom, rom_index)
            else:
                bits_plans = tile_bitplanes(gfx_rom, rom_index)
            packed = pack_plan(bits_plans, size=tile_size)
            put_pixel(img, palette, x_pos, y_pos, color, packed, palette_offset,
                      x_size=tile_size, y_size=tile_size, rom_index=rom_index)


###################
#
# DECODE CHAR
#
def char_bitplanes(gfx_rom, rom_index):
    # 8 bits of a bitplane (or a line of a bitplane) is composed of 1 low nibbles from odd bytes and 1 for even bytes
    # the second plan is composed of 1 high nibles from odd and 1 high nibles from even bytes
    low_nibbles_p1 = []
    high_nibbles_p2 = []

    # first 16 bytes are in first rom
    for x in range(0, 32, 2):
        # odd bytes
        odd = gfx_rom[(rom_index*16+x)]
        # even bytes
        even = gfx_rom[(rom_index*16)+x+1]

        # divide bytes in high and low nibbles
        low_nibbles_p1.append(odd & 0x0f)   # low nibble are used in plan 1
        low_nibbles_p1.append(even & 0x0f)  # low nibble are used in plan 1

        high_nibbles_p2.append(odd >> 4)   # high nible are used in plan 2
        high_nibbles_p2.append(even >> 4)  # high nibble are used in plan 2

    # second 16 bytes are in second rom
    # or rom + 0x10_000 if concatened
    low_nibbles_p3 = []
    high_nibbles_p4 = []
    for x in range(0, 32, 2):
        # odd bytes
        odd = gfx_rom[(rom_index*16+x+0x10000)]
        # even bytes
        even = gfx_rom[(rom_index*16)+x+1+0x10000]

        # divide bytes in high and low nibbles
        low_nibbles_p3.append(odd & 0x0f)  # low nibbles are used in plan 3
        low_nibbles_p3.append(even & 0x0f)

        high_nibbles_p4.append(odd >> 4)   # high nibble are used in plan 4
        high_nibbles_p4.append(even >> 4)

    plans = []

    for nibbles in [low_nibbles_p1, high_nibbles_p2, low_nibbles_p3, high_nibbles_p4]:
        plan = []
        for x in range(0, int(len(nibbles)/2), 2):
            odd_nibble = nibbles[x]
            even_nibble = nibbles[x+1]

            line = ""
            line += f"{odd_nibble:04b}"[::-1]   # odd
            line += f"{even_nibble:04b}"[::-1]  # even
            plan.append(line)
        plans.append(plan)

    return ((plans[3], plans[2], plans[1], plans[0],))

################
#
# Tile Bitplanes
#
def tile_bitplanes(gfx_rom, rom_index):
    # each plan is composed of :
    # plan1 : odd bytes high nibbles
    # plan2 : odd bytes low nibbles
    # plan3 : even bytes high nibbles
    # plan4 : even bytes low nibbles
    odd_h_nibbles = []  # plan 1
    odd_l_nibbles = []  # plan 2
    even_h_nibbles = []  # plan 3
    even_l_nibbles = []  # plan 4
    for x in range(0, 128, 2):
        # odd bytes
        odd = gfx_rom[(rom_index*128)+x]
        # divide bytes in high and low nibbles
        odd_h_nibbles.append(odd >> 4)
        odd_l_nibbles.append(odd & 0x0f)

        # even bytes
        even = gfx_rom[(rom_index*128)+x+1]
        even_h_nibbles.append(even >> 4)
        even_l_nibbles.append(even & 0x0f)

    # we need to take two odd nibles then two odd nibles for the next group of 4+4+4+4*16 bits
    # or 4+4*16 if we count nibbles only
    plans = []
    for nibbles in [odd_h_nibbles, odd_l_nibbles, even_h_nibbles, even_l_nibbles]:
        plan = []
        for x in range(0, int(len(nibbles)/2), 2):
            line = ""
            nibble0 = nibbles[x]
            nibble1 = nibbles[x+1]
            nibble2 = nibbles[x+32]  # second nibbles is later in memory
            nibble3 = nibbles[x+32+1]
            line += f"{nibble0:04b}"[::-1] + f"{nibble1:04b}"[::-1]
            line += f"{nibble2:04b}"[::-1] + f"{nibble3:04b}"[::-1]
            plan.append(line)
        plans.append(plan)

    if rom_index == 0xfbb:
        print(
            f"{(plans[2], plans[3], plans[0], plans[1],)}".replace(",", "\n"))

    return ((plans[2], plans[3], plans[0], plans[1],))

################
#
# DECODE SPRITE
#
def scan_sprite(img, ram, gfx_rom, palette, palette_offset, tile_size=16):
    for sprite_index in range(int(len(ram)/8)-1, -1, -1):
        sp_bytes = ram[sprite_index*8:(sprite_index*8)+8]
        sprite_word = struct.unpack(">HHHH", sp_bytes)
        # f000 0000 f000 0000     entry not yet used
        # ffff ???? ???? ????     sprite marked as dead
        # if ((sprite_word[2] != 0xf000) && (sprite_word[0] != 0xffff))
        # if dword_0[15] == '1': #?
        # continue
        if sprite_word[2] == 0xf000 or sprite_word[0] == 0xffff:
            continue

        xoffs = sprite_word[0] & 0xf0
        x = (sprite_word[2] + xoffs) & 0x1f
        if x > 256:
            x -= 512

        yoffs = (sprite_word[0] & 0xf) << 4
        y = (sprite_word[3] + yoffs) & 0x1ff
        if y > 256:
            y -= 512

        color = sprite_word[1] >> 12
        flip_x = sprite_word[0] & 0x100
        rom_index = (sprite_word[1] & 0xfff) + ((sprite_word[2] & 0x8000) >> 3)

        bitplanes = tile_bitplanes(gfx_rom, rom_index)

        packed = pack_plan(bitplanes, size=tile_size,
                           flip_x=flip_x)  # flip_x ?

        put_pixel(img, palette, x, y, color, packed, palette_offset,
                  x_size=16, y_size=16, rom_index=rom_index)


##########
#
# INIT
#
GFX_1_START = 0x60000
GFX_2_START = 0x80000
GFX_3_START = 0x180000
GFX_4_START = 0x200000


def ram2gfx(path, show=False):
    # toki concatened roms in mra order
    rom = read_file('rom.bin')
    gfx1_rom = rom[GFX_1_START:GFX_2_START]
    gfx2_rom = rom[GFX_2_START:GFX_3_START]
    gfx3_rom = rom[GFX_3_START:GFX_4_START]
    gfx4_rom = rom[GFX_4_START:GFX_4_START+0x80000]

    # memory dump of the different video ram chipset
    bg1_ram = read_file('bg1_ram.bin', path)
    bg2_ram = read_file('bg2_ram.bin', path)
    palette_ram = read_file('palette_ram.bin', path)
    # scroll_ram = read_file('scroll_ram.bin', path)
    sprite_ram = read_file('sprite_ram.bin', path)
    vram_ram = read_file('vram_ram.bin', path)

    img = Image.new('RGB', (512, 512))
    scan_ram(img, bg1_ram, gfx3_rom, palette_ram, 0x400, tile_size=16)
    scan_ram(img, bg2_ram, gfx4_rom, palette_ram, 0x600, tile_size=16)
    scan_sprite(img, sprite_ram, gfx2_rom, palette_ram, 0x0)
    scan_ram(img, vram_ram, gfx1_rom, palette_ram, 0x200, tile_size=8)

    img.save(f'{path}/screen.png')
    if show:
        plt.imshow(img)
        plt.show()


if __name__ == "__main__":
    if len(sys.argv) == 2:
        path = sys.argv[1]
        ram2gfx(path)
    else:
        print(sys.argv[0] + " memory_dumps_path")
