# Building Blocks Tilemap

A="061b07.18d"
B="061b06.16d"
C="061b05.15d"

def read_file(bf):
    with open(bf, 'rb') as f:
        rd = bytearray(f.read())
    return rd

def generate_position(tmap, ypos, xpos):
    position = (tmap << 18) | ((ypos & 0x1ff) << 9) | (xpos & 0x1ff)
    return position

def compress_pos(tmap, ypos, xpos):
    yp, xp   = (ypos >> 1), (xpos >> 1)
    position = (tmap << 16) | ((yp << 8) & 0xff) | (xp & 0xff)
    return f"{position:017X}"

def read_word_18(pos):
    c_idx   = pos >> 2
    c_shift = (pos & 0b11) * 2
    c_byte  = c[c_idx]
    c2      = (c_byte >> c_shift) & 0b11  # 2 bits

    word18 = (a[pos] << 10) | (b[pos] << 2) | c2

    return word18

def read_all_files():
    global a, b, c
    a = read_file(A)
    b = read_file(B)
    c = read_file(C)

read_all_files()

blocks = {}
encoded_count=-1
newmap = {}
for bank in range(2):
    for y in range(0, 512, 2):
        for x in range(0, 512, 2):
            bytes00 = read_word_18( generate_position(bank,y  ,x  ))
            bytes01 = read_word_18( generate_position(bank,y  ,x+1))
            bytes10 = read_word_18( generate_position(bank,y+1,x  ))
            bytes11 = read_word_18( generate_position(bank,y+1,x+1))

            code = f"{bytes00:05X}_{bytes01:05X}_{bytes10:05X}_{bytes11:05X}"
            if code not in blocks:
                encoded_count+= 1
                blocks[code]  = encoded_count

            newmap[ compress_pos(bank,y,x) ] = blocks[code]

print("Number of individual blocks: ", len(blocks))
