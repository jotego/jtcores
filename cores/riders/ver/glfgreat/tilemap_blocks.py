# Building Blocks Tilemap

A="A.bin" # "061b07.18d"
B="B.bin" # "061b06.16d"
C="C.bin" # "061b05.15d"

def read_file(bf):
    with open(bf, 'rb') as f:
        rd = bytearray(f.read())
    return rd

def generate_position(tmap, ypos, xpos):
    position = (tmap << 18) | ((ypos & 0x1ff) << 9) | (xpos & 0x1ff)
    return position

def compress_pos(tmap, ypos, xpos):
    yp, xp   = (ypos >> 1), (xpos >> 1)
    position = (tmap << 16) | ((yp & 0xff) << 8 ) | (xp & 0xff)
    return f"{position:05X}"

def read_word_18(pos):
    c_idx   = pos >> 2
    c_shift = (pos & 0b11) * 2
    c_byte  = c[c_idx]
    c2      = (c_byte >> c_shift) & 0b11  # 2 bits

    word18 = (c2 << 16) | (a[pos] << 8) | (b[pos])

    return word18


def word72():
    w72=0
    b_list = [bytes00, bytes01, bytes10, bytes11]
    for w in range(4):
        w72 |= b_list[w] << w*18
    return f"{w72:018X}"

def create_hex_file(fname, hlist, nmap=0):
    hwr=""
    for x in hlist:
        if nmap == 0:
            hwr += f"{x}\n"
        else:
            hwr += f"{hlist[x]}\n"

    try:
        with open(fname, "x") as h:
            h.write(hwr)
    except FileExistsError:
        with open(fname, "w") as h:
            h.write(hwr)

def read_all_files():
    global a, b, c
    a = read_file(A)
    b = read_file(B)
    c = read_file(C)

read_all_files()

blocks  = {}
freq    = {}
newmap  = {}
hexlist = {}
encoded_count =-1

for bank in range(2):
    for y in range(0, 512, 2):
        for x in range(0, 512, 2):
            bytes00 = read_word_18( generate_position(bank,y  ,x  ))
            bytes01 = read_word_18( generate_position(bank,y  ,x+1))
            bytes10 = read_word_18( generate_position(bank,y+1,x  ))
            bytes11 = read_word_18( generate_position(bank,y+1,x+1))
            # code = f"%05X_%05X_%05X_%05X" [bytes00, bytes01, bytes10, bytes11]
            code = f"{bytes11:05X}_{bytes10:05X}_{bytes01:05X}_{bytes00:05X}"
            if code not in blocks:
                encoded_count+= 1
                blocks[code]  = encoded_count
                hexlist[word72()] = encoded_count
            if code not in freq:
                freq[code] = 1
            else:
                freq[code] += 1

            newmap[ compress_pos(bank,y,x) ] = f"{blocks[code]:05X}"

print("Number of individual blocks: ", len(blocks))
print(len(newmap))

create_hex_file("tilemap_2x2.hex",hexlist)
create_hex_file("decoder.hex",newmap,1)