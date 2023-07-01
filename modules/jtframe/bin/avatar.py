#!/usr/bin/python3
import png
import sys
import os
pr=sys.stdout.write

jtroot_path=os.environ['JTROOT']+"/"

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
maxobj=256
bufzy=bytearray(int(maxobj*16*16/4))
bufxw=bytearray(int(maxobj*16*16/4))
for x in range(len(bufzy)):
    bufzy[x] = 0xff
    bufxw[x] = 0xff
bufpos=0

def read_bmp(filename):
    avatar=png.Reader(filename)
    l=avatar.read()
    bmp=list(l[2])  # rows and columns
    return bmp

def break_4pixels( bit, pixel ):
    zy = ( (pixel&8)<<1 ) | ((pixel&4)>>2)
    xw = ( (pixel&2)<<3 ) |  (pixel&1)
    zy <<= (3-bit)
    xw <<= (3-bit)
    return (zy,xw)

objcnt=0
offsetx = 20
offsety = 8
# set to 1 to debug errors:
verbose=0


def dump_block( rowc, colc, bmp, pal, palidx ):
    global bufpos, objcnt, offsety, offsetx, verbose
    pr("\t%2d: %2d,%2d" % (objcnt,colc,rowc))

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
    print("\tBMP size = %d, %d" % (len(bmp), len(bmp[0])/4))
    if len(bmp)%16!=0 or len(bmp[0])%16!=0:
        print("Error: BMP size is not a multiple of 16")
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
            if(bmp[k][j+3]==255):
                curpal.add ( (bmp[k][j]>>4, bmp[k][j+1]>>4, bmp[k][j+2]>>4)  )
                palorig.add( (bmp[k][j], bmp[k][j+1], bmp[k][j+2], bmp[k][j+3])  )
            j+=4
    j=0
    pal=dict()
    for k in curpal:
        pal[k]=j
        j+=1
    if verbose:
        print("Original:")
        print(palorig)
        print("Converted")
        print(pal)
    print( "\tPalette conversion %d to %d" % (len(palorig),len(pal)))
    return pal

######################################################################################3
## Conversion
pal_list=list()

def convert_file(filename):
    p=jtroot_path+filename.strip("\n")
    print(p)
    bmp=read_bmp( p )
    pal=get_pal(bmp)
    palidx = len(pal_list)
    print("\t%d colours. PAL index %d" % (len(pal), palidx) )
    convert_bmp(bmp, pal, palidx )
    pal_list.append(pal)

# Try opening the file with the list of PNG images
corename=sys.argv[1]

if os.path.exists(jtroot_path+"cores/"):
    corepath=jtroot_path+"cores/"+corename
    jtroot_path=jtroot_path+"cores/"
else:
    corepath=jtroot_path

print("corepath=", corepath)
print("jtroot_path=", jtroot_path)

avatar_filename = corepath+"/patrons/avatars"
file = open( avatar_filename )
line = file.readline()

while line:
    if line[0] != '#':
        convert_file(line)
    line = file.readline()
file.close()

# dump the new ROM files

# Graphics
f0=open(corepath+"/patrons/avatar.hex","w")
for k in range(len(bufzy)):
    x = bufzy[k]<<8
    x |= bufxw[k]
    x &= 0xffff
    f0.write("%4X\n" % x )

# Palette
f0=open(corepath+"/patrons/avatar_pal.hex","w")
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
