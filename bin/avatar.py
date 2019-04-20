#!/usr/bin/python
import png
import sys
pr=sys.stdout.write



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

def read_bmp(filename):
    avatar=png.Reader(filename)
    l=avatar.read()
    bmp=list(l[2])  # rows and columns
    return bmp

# 1943 colour palettes
def show_palettes():
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

def break_4pixels( bit, pixel ):
    zy = ( (pixel&8)<<1 ) | ((pixel&4)>>2)
    xw = ( (pixel&2)<<3 ) |  (pixel&1)
    zy <<= (3-bit)
    xw <<= (3-bit)
    return (zy,xw)

objcnt=0
offsetx = 40
offsety = 40

def dump_block( rowc, colc, bmp, pal, palidx ):
    global bufpos, objcnt, offsety, offsetx
    print("%2d: %d,%d" % (objcnt,rowc,colc))
    mapxy[objcnt*4  ] = objcnt  # address
    mapxy[objcnt*4+1] = palidx  # PAL
    mapxy[objcnt*4+2] = rowc+offsety    # Y
    mapxy[objcnt*4+3] = colc+offsetx    # X

    objcnt+=1
    r=rowc
    while r<rowc+16:
        c=colc
        while c<colc+16:
            c4=c<<2
            if(bmp[r][c4+3]>0):
                pxl=pal[(bmp[r][c4]>>4, bmp[r][c4+1]>>4, bmp[r][c4+2]>>4)]
            else:
                pxl=15
            (zy,xw) = break_4pixels( c%4, pxl )
            bufzy[bufpos] |= zy&255; 
            bufxw[bufpos] |= xw&255; 
            if( c%4 == 3 ):
                bufpos+=1
            c+=1
        r+=1

# convert bitmap to OBJ, size must be multiple of 16x16
def convert_bmp(bmp, pal, palidx):
    global offsety
    print "BMP size = %d, %d" % (len(bmp), len(bmp[0])/4)
    if len(bmp)%16!=0 or len(bmp[0])%16!=0:
        print "Error: BMP size is not a multiple of 16"
        exit(1)
    rowc=0
    while rowc<len(bmp):
        colc=0
        while(colc< (len(bmp[0])>>2)):
            dump_block(rowc, colc, bmp, pal, palidx)
            colc = colc+16
        rowc=rowc+16
    offsety+=len(bmp)


# shows the Bitmap alpha channel on screen
def show_mask():
    for k in range(len(bmp)):
        j=3
        while j<len(bmp[0]):
            if(bmp[k][j]>0):
                pr("*") 
            else:
                pr(" ") 
            j+=4
        pr('\n')


# Palette has 15 usable colours (0-14)
# position 15 is reserved for alpha
def get_pal(bmp):
    curpal=set()
    for k in range(len(bmp)):
        j=0
        while j<len(bmp[0]):
            if(bmp[k][j+3]>0):
                curpal.add( (bmp[k][j]>>4, bmp[k][j+1]>>4, bmp[k][j+2]>>4)  )
            j+=4
    j=0
    pal=dict()
    for k in curpal:
        pal[k]=j
        j+=1
    return pal

######################################################################################3
## Conversion

#patrons=["phillip_mcmahon.png","scralings_48.png","sascha.png","brian_sallee.png"]
patrons=["brian_sallee.png"]
png_path="../1943/patrons/"
pal_list=list()

for p in patrons:
    p=png_path+p
    print p
    bmp=read_bmp( p )
    pal=get_pal(bmp)
    convert_bmp(bmp, pal, len(pal_list))
    pal_list.append(pal)

    
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

# Palette
f0=open("../1943/mist/avatar_pal.hex","w")
for pal in pal_list:
    cnt=0
    for k in pal:
        colour = pal[k]
        # print colour
        # print k
        colour = (k[0]<<8)|(k[1]<<4)|k[0]
        colour &= 0xfff
        f0.write("%X\n" % colour )
        cnt+=1
    # Fill up to 16 colours, the last one is always transparent
    while cnt<16:
        f0.write("0\n")
        cnt+=1

print("Only %d bytes actually used" % bufpos )