#!/usr/bin/python
import png
import sys

avatar=png.Reader("phillip_mcmahon.png")
l=avatar.read()
bmp=list(l[2])  # rows and columns

# for row in bmp:
#     for col in row:
#         sys.stdout.write("%X " % col)
#         col
#     sys.stdout.write("\n")

# 1943 object format
# 2 ROMs
# 4 bits per pixel
# 2 pixels per byte
# ROM 0,       bits 7-4  3-0
# pixels 3-0         Z    Y
# pixels 3-0         X    W
# A5 selects pixels +16
# A4-A1 selects row
# A0 selects pixels +4
# A5 is moved to A1 in jt1943, so data is contiguous
# One object is 16x16 pixels

# output arrays
bufzy=bytearray(32*16*16/4)
bufxw=bytearray(32*16*16/4)
for x in range(len(bufzy)):
    bufzy[x] = 0
    bufxw[x] = 0
bufpos=0

mapxy=bytearray(32*4)

# 1943 colour palettes
def show_palettes:
    muxsel=bytearray( file("../rom/1943/bm4.12c","rb").read(32)     )
    rpal  =bytearray( file("../rom/1943/bm1.12a","rb").read(256)    )
    gpal  =bytearray( file("../rom/1943/bm2.13a","rb").read(256)    )
    bpal  =bytearray( file("../rom/1943/bm3.14a","rb").read(256)    )

    # Dump all object palettes
    for palmsb in range(4):
        msb=muxsel[ 0x19 | (palmsb<<1) ]
        for pallsb in range(4):
            for col in range(16):
                idx = msb<<6 | (pallsb<<4) | col
                idx &= 0xff
                print("%d,%d -> %d, %d, %d" %(palmsb, pallsb, rpal[idx], gpal[idx], bpal[idx]) )

def break_4pixels( bit, pixel):
    pixel &= 15
    zy = ( (pixel&8)<<4 ) | (pixel&4)
    xw = ( (pixel&2)<<4 ) | (pixel&1)
    zy <<= bit
    xw <<= bit
    return (zy,xw)

objcnt=0
offsetx = 40
offsety = 40

def dump_block( rowc, colc, bmp ):
    global bufpos, objcnt
    print("%2d: %d,%d" % (objcnt,rowc,colc))
    mapxy[objcnt*4  ] = objcnt  # address
    mapxy[objcnt*4+1] = 1       # PAL
    mapxy[objcnt*4+2] = rowc+offsety    # Y
    mapxy[objcnt*4+3] = colc+offsetx    # X

    objcnt+=1
    r=rowc
    while r<rowc+16:
        c=colc
        while c<colc+16:
            (zy,xw) = break_4pixels( c%4, bmp[r][c] )
            bufzy[bufpos] |= zy&255; 
            bufxw[bufpos] |= xw&255; 
            if( c%4 == 3 ):
                bufpos+=1
            c+=1
        r+=1


def normalize_gray(bmp):
    gmax=0
    # Find the maximum
    for r in bmp:
        for c in r:
            if c > gmax:
                gmax=c
    # Divide by it and multiply by 15
    for k in range(len(bmp)):
        for j in range(len(bmp[0])):
            bmp[k][j]= bmp[k][j]*16/gmax
            bmp[k][j]&=15


# convert bitmap to OBJ, size must be multiple of 16x16
def convert_bmp(bmp):
    print "BMP size = %d, %d" % (len(bmp), len(bmp[0]))
    if len(bmp)%16!=0 or len(bmp[0])%16!=0:
        print "Error: BMP size is not a multiple of 16"
        exit(1)
    normalize_gray(bmp)
    rowc=0
    while rowc<len(bmp):
        colc=0
        while(colc<len(bmp[0])):
            dump_block(rowc, colc, bmp)
            colc = colc+16
        rowc=rowc+16

# convert_bmp(bmp)
    
# dump the new ROM files

# Graphics
f0=open("../1943/mist/avatar.hex","w")
for k in range(bufpos):
    x = bufzy[k]<<8
    x |= bufxw[k]
    x &= 0xffff
    f0.write("%X\n" % x )

# Map
f0=open("../1943/mist/avatar_xy.hex","w")
k=0
for k in range(32):
    k4 = k*4
    f0.write( "%X\n" % (mapxy[k4  ]&255) )
    f0.write( "%X\n" % (mapxy[k4+1]&255) )
    f0.write( "%X\n" % (mapxy[k4+2]&255) )
    f0.write( "%X\n" % (mapxy[k4+3]&255) )



print("Only %d bytes actually used" % bufpos )