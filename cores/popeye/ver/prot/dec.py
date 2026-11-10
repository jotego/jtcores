import sys, zipfile

def b(v, n):
    return (v >> n) & 1

def dec(rom):
    out = bytearray(0x8000)
    for a in range(0x8000):
        ad = (b(a,12)<<12)|(b(a,11)<<11)|(b(a,10)<<10)|(b(a,8)<<9)|(b(a,7)<<8)|(b(a,6)<<7)|(b(a,3)<<6) \
           | ((1-b(a,9))<<5)|((1-b(a,5))<<4)|((1-b(a,4))<<3)|((1-b(a,2))<<2)|((1-b(a,1))<<1)|(1-b(a,0))
        md = rom[((a>>13)&3)<<13 | ad]
        out[a] = sum(b(md, s) << (7-k) for k, s in enumerate([3,4,2,5,1,6,0,7]))
    return out

def load(zname, names):
    z = zipfile.ZipFile(zname)
    return b''.join(z.read(n) for n in names)

open(sys.argv[3], 'wb').write(dec(load(sys.argv[1], ['tpp2-c.7a','tpp2-c.7b','tpp2-c.7c','tpp2-c.7e'])))
open(sys.argv[4], 'wb').write(dec(load(sys.argv[2], ['7a','7b','7c','7e'])))
