#!/usr/bin/python
import png
import sys
import os
pr=sys.stdout.write

jtgng_path=os.environ['JTGNG']+"/"

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
maxobj=128
bufzy=bytearray(maxobj*16*16/4)
bufxw=bytearray(maxobj*16*16/4)
for x in range(len(bufzy)):
    bufzy[x] = 0xff
    bufxw[x] = 0xff
bufpos=0

mapxy=bytearray(maxobj*4)

def read_bmp(filename):
    avatar=png.Reader(filename)
    l=avatar.read()
    bmp=list(l[2])  # rows and columns
    return bmp

# 1943 colour palettes
def show_palettes():
    muxsel=bytearray( file(jtgng_path+"/rom/1943/bm4.12c","rb").read(32)     )
    rpal  =bytearray( file(jtgng_path+"/rom/1943/bm1.12a","rb").read(256)    )
    gpal  =bytearray( file(jtgng_path+"/rom/1943/bm2.13a","rb").read(256)    )
    bpal  =bytearray( file(jtgng_path+"/rom/1943/bm3.14a","rb").read(256)    )

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
offsetx = 20
offsety = 8
verbose=0


def dump_block( rowc, colc, bmp, pal, palidx ):
    global bufpos, objcnt, offsety, offsetx, verbose
    pr("\t%2d: %2d,%2d" % (objcnt,colc,rowc))
    mapxy[objcnt*4  ] = objcnt  # address
    mapxy[objcnt*4+1] = palidx  # PAL
    mapxy[objcnt*4+2] = (rowc+offsety)&255    # Y
    mapxy[objcnt*4+3] = (colc+offsetx)&255    # X

    objcnt+=1
    r=rowc
    while r<rowc+16:
        c=colc
        while c<colc+16:
            c4=c<<2
            if(bmp[r][c4+3]!=0):
                pxl=pal[(bmp[r][c4]>>4, bmp[r][c4+1]>>4, bmp[r][c4+2]>>4)]
            else:
                pxl=15
            if(verbose):
                pr("%X"%pxl)
            (zy,xw) = break_4pixels( c%4, pxl )
            if(c%4==0):
                bufzy[bufpos] = zy; 
                bufxw[bufpos] = xw; 
            else:
                bufzy[bufpos] |= zy&255; 
                bufxw[bufpos] |= xw&255; 
            if( c%4 == 3 ):
                bufpos+=1
            c+=1
        r+=1
        if(verbose):
            pr("\n")

# convert bitmap to OBJ, size must be multiple of 16x16
def convert_bmp(bmp, pal, palidx):
    global offsety
    print "\tBMP size = %d, %d" % (len(bmp), len(bmp[0])/4)
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
        pr("\n")
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
    palorig=set()
    for k in range(len(bmp)):
        j=0
        while j<len(bmp[0]):
            if(bmp[k][j+3]!=0):
                curpal.add ( (bmp[k][j]>>4, bmp[k][j+1]>>4, bmp[k][j+2]>>4)  )
                palorig.add( (bmp[k][j], bmp[k][j+1], bmp[k][j+2])  )
            j+=4
    j=0
    pal=dict()
    for k in curpal:
        pal[k]=j
        j+=1
    if verbose:
        print "Original:"
        print palorig
        print "Converted"
        print pal
    print( "\tPalette conversion %d to %d" % (len(palorig),len(pal)))
    return pal

######################################################################################3
## Conversion
pal_list=list()

def convert_file(filename):
    p=jtgng_path+filename.strip("\n")
    print p
    bmp=read_bmp( p )
    pal=get_pal(bmp)
    palidx = len(pal_list)
    print("\t%d colours. PAL index %d" % (len(pal), palidx) )
    convert_bmp(bmp, pal, palidx )
    pal_list.append(pal)

# Try opening the file with the list of PNG images
corename=sys.argv[1]
avatar_filename = jtgng_path+corename+"/patrons/avatars"
file = open( avatar_filename )
line = file.readline()

while line:
    convert_file(line)
    line = file.readline()
file.close()

# dump the new ROM files

# Graphics
f0=open(jtgng_path+corename+"/mist/avatar.hex","w")
for k in range(len(bufzy)):
    x = bufzy[k]<<8
    x |= bufxw[k]
    x &= 0xffff
    f0.write("%4X\n" % x )

# Map
f0=open(jtgng_path+corename+"/mist/avatar_xy.hex","w")
k=0
for k in range(len(mapxy)>>2):
    k4 = k*4
    f0.write( "%2X\n" % (mapxy[k4  ]&255) )
    f0.write( "%2X\n" % (mapxy[k4+1]&255) )
    f0.write( "%2X\n" % (mapxy[k4+2]&255) )
    f0.write( "%2X\n" % (mapxy[k4+3]&255) )

# Palette
f0=open(jtgng_path+corename+"/mist/avatar_pal.hex","w")
for pal in pal_list:
    palbuf=[]
    for k in range(16):
        palbuf.append(0)
    for k in pal:
        idx = pal[k]
        #print idx
        #print k
        palbuf[idx] = (k[0]<<8)|(k[1]<<4)|k[2]
        #print palbuf[idx]
    for k in range(16):
        f0.write("%X\n" % palbuf[k] )
# fill in with zeroes the rest of available palettes
k=len(pal_list)
while k<16:
    for j in range(16):
        f0.write("0\n")
    k=k+1


print("Only %d 16-bit words actually used" % bufpos )

# Final Map
if corename == "1943":
    map9x9 = [  # Scralings
         0, 1, 2,
         3, 4, 5, 
         6, 7, 8,
            #unused
            255,255,255,255,255,255,255,
        # Suv
         9,10,11,
        12,13,14,
        15,16,17,
            #unused
            255,255,255,255,255,255,255,
        # Mahe
        18,255,255,
        255,18,255,
        255,255,18,
            #unused
            255,255,255,255,255,255,255,
        # Tomiyori
        19,20,21,
        22,23,24,
        255,255,255,
            #unused
            255,255,255,255,255,255,255,
        # Brian
        25,26,27,
        28,29,30,
        31,32,33,
            #unused
            255,255,255,255,255,255,255,
        # Sascha
        34,35,36,
        37,38,39,
        40,41,42,
            #unused
            255,255,255,255,255,255,255,
        # McMahon
        43,44,45,
        46,47,48,
        255,255,255,
            #unused
            255,255,255,255,255,255,255,
        # Hubbard
        49,50,51,
        52,53,54,
        55,56,57,
            #unused
            255,255,255,255,255,255,255,
    ]

if corename == "commando" or corename == "vulgus" or corename == "gunsmoke":
   map9x9 = [  # Scralings
         0, 1, 2,
         3, 4, 5, 
         6, 7, 8,
            #unused
            255,255,255,255,255,255,255,
        # Suv
         9,10,11,
        12,13,14,
        15,16,17,
            #unused
            255,255,255,255,255,255,255,
        # Mahe
        18,255,255,
        255,18,255,
        255,255,18,
            #unused
            255,255,255,255,255,255,255,
        # Tomiyori
        19,20,21,
        22,23,24,
        255,255,255,
            #unused
            255,255,255,255,255,255,255,
        # Brian
        25,26,27,
        28,29,30,
        31,32,33,
            #unused
            255,255,255,255,255,255,255,
        # McMahon
        34,35,36,
        37,38,39,
        255,255,255,
            #unused
            255,255,255,255,255,255,255,
        # Hubbard
        40,41,42,
        43,44,45,
        46,47,48,
            #unused
            255,255,255,255,255,255,255,
        # Daniel Bauza
        49,50,51,
        52,53,54,
        55,56,57,
            #unused
            255,255,255,255,255,255,255,
    ]

if corename=="tora" or corename=="biocom" or corename=="f1dream":
   map9x9 = [  # Scralings
         0, 1, 2,
         3, 4, 5, 
         6, 7, 8,
            #unused
            255,255,255,255,255,255,255,
        # Suv
         9,10,11,
        12,13,14,
        15,16,17,
            #unused
            255,255,255,255,255,255,255,
        # Mahe
        18,255,255,
        255,18,255,
        255,255,18,
            #unused
            255,255,255,255,255,255,255,
        # Tomiyori
        19,20,255,
        21,22,255,
        23,24,255,
            #unused
            255,255,255,255,255,255,255,
        # Brian
        25,26,27,
        28,29,30,
        31,32,33,
            #unused
            255,255,255,255,255,255,255,
        # McMahon
        34,35,255,
        36,37,255,
        38,39,255,
            #unused
            255,255,255,255,255,255,255,
        # Hubbard
        40,41,42,
        43,44,45,
        46,47,48,
            #unused
            255,255,255,255,255,255,255,
        # Daniel Bauza
        49,50,51,
        52,53,54,
        55,56,57,
            #unused
            255,255,255,255,255,255,255,
    ]

f0=open(jtgng_path+corename+"/mist/avatar_obj.hex","w")
for k in map9x9:
    f0.write("%X\n" % k)

print("Map 9x9 size = %d" % len(map9x9) )
