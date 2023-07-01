#! /usr/bin/python3
import zlib
import struct
import sys

def makeGrayPNG(data, width = 256, height = 224):
    def I1(value):
        return struct.pack("!B", value & (2**8-1))
    def I4(value):
        return struct.pack("!I", value & (2**32-1))
    # generate these chunks depending on image type
    makeIHDR = True
    makeIDAT = True
    makeIEND = True
    png = b"\x89" + "PNG\r\n\x1A\n".encode('ascii')
    if makeIHDR:
        colortype = 0 # true gray image (no palette)
        bitdepth = 8 # with one byte per pixel (0..255)
        compression = 0 # zlib (no choice here)
        filtertype = 0 # adaptive (each scanline seperately)
        interlaced = 0 # no
        IHDR = I4(width) + I4(height) + I1(bitdepth)
        IHDR += I1(colortype) + I1(compression)
        IHDR += I1(filtertype) + I1(interlaced)
        block = "IHDR".encode('ascii') + IHDR
        png += I4(len(IHDR)) + block + I4(zlib.crc32(block))
    if makeIDAT:
        raw = b""
        for y in range(height):
            raw += b"\0" # no filter for this scanline
            for x in range(width):
                #c = b"\0" # default black pixel
                #if y < len(data) and x < len(data[y]):
                c = I1(data[y*width+x])
                raw += c
        compressor = zlib.compressobj()
        compressed = compressor.compress(raw)
        compressed += compressor.flush() #!!
        block = "IDAT".encode('ascii') + compressed
        png += I4(len(compressed)) + block + I4(zlib.crc32(block))
    if makeIEND:
        block = "IEND".encode('ascii')
        png += I4(0) + block + I4(zlib.crc32(block))
    return png

def makeColourPNG(data, width = 640, height = 480):
    def I1(value):
        return struct.pack("!B", value & (2**8-1))
    def I4(value):
        return struct.pack("!I", value & (2**32-1))
    # generate these chunks depending on image type
    makeIHDR = True
    makeIDAT = True
    makeIEND = True
    png = b"\x89" + "PNG\r\n\x1A\n".encode('ascii')
    if makeIHDR:
        colortype = 2 # true color
        bitdepth = 8 # with one byte per pixel (0..255)
        compression = 0 # zlib (no choice here)
        filtertype = 0 # adaptive (each scanline seperately)
        interlaced = 0 # no
        IHDR = I4(width) + I4(height) + I1(bitdepth)
        IHDR += I1(colortype) + I1(compression)
        IHDR += I1(filtertype) + I1(interlaced)
        block = "IHDR".encode('ascii') + IHDR
        png += I4(len(IHDR)) + block + I4(zlib.crc32(block))
    if makeIDAT:
        raw = b""
        for y in range(height):
            raw += b"\0" # no filter for this scanline
            for x in range(width):
                idx = 3*(y*width+x)
                for colour in range(3):
                    #c = b"\0" # default black pixel
                    #if y < len(data) and x < len(data[y]):
                    c = I1(data[idx+colour])
                    raw += c
        compressor = zlib.compressobj()
        compressed = compressor.compress(raw)
        compressed += compressor.flush() #!!
        block = "IDAT".encode('ascii') + compressed
        png += I4(len(compressed)) + block + I4(zlib.crc32(block))
    if makeIEND:
        block = "IEND".encode('ascii')
        png += I4(0) + block + I4(zlib.crc32(block))
    return png

fin=open("video.bin","rb")
fin.seek(0,2)
file_len = fin.tell()/2
fin.seek(0,0)
# aux = bytearray( fin.read() )
print("Len = %d" % file_len)
#video_data = bytearray( len(aux)/2 )
c=0
# verilog outputs 32 bits per pixel
# drops each second word:
# for k in range(0,len(aux),4):
#     video_data[c]   = aux[k]
#     video_data[c+1] = aux[k+1]
#     c+=2

# fin.close()

pxl=0

#look for start
frame_start=0
frame_cnt = 0
frame_width = 1024
frame_height= 768
last_lines=0

frame = bytearray(frame_width*frame_height*3)
for k in range(len(frame)):
    frame[k] = 0

rotate=0
scale_up=0
overwrite=0

for a in sys.argv:
    if a=="-r" or a =="--rotate":
        rotate=1
    if a=="-o" or a =="--overwrite":
        overwrite=1
    if a=="-s" or a =="--scale":
        scale_up=1
        
while 1: # len(video_data)-2:
    video_data = bytearray( fin.read(4) )
    while len(video_data)==4 and (video_data[1]&0x20) == 0x20:
        video_data = bytearray( fin.read(4) )

    if len(video_data)!=4:
        print "Done"
        break

    filename = "img%03d.png"%frame_cnt
    dumped=frame_start
    width=0
    c=0
    lines=0
    k=frame_start
    while len(video_data)==4:
    # for k in range(frame_start,len(video_data),2):
        sync = (video_data[1]>>4)

        if (sync&2) == 2: # VSYNC
            if lines != last_lines:
                print("Vsync after %d lines" % lines) # 356x259
                last_lines = lines
            dumped = k
            break
        if (sync&1) == 1: # Hsync
            if width !=0:
                #print("Line extended over %d " % width)
                lines +=1
                c = lines*frame_width*3
            width = 0
            video_data = bytearray( fin.read(4) )
            continue
        red  = video_data[1]&0xf
        green= (video_data[0]>>4)&0xf
        blue = video_data[0]&0xf
        try:
            frame[c  ] = red   * 17
            frame[c+1] = green * 17
            frame[c+2] = blue  * 17
        except:
            print( "error with %d,%d,%d. Index = %d" % (red,green,blue, c) )
            raise
        c+=3
        width+=1
        video_data = bytearray( fin.read(4) )
    # if dumped == frame_start:
    #     break

    # print("Frame extended over %d pixels" % ((dumped-frame_start)/2))
    frame_start = k    
    # save PNG
    try:
        skip=0
        if overwrite==0:
            with open(filename,"rb") as fout:
                fout.seek(0,2)
                if fout.tell()>0:
                    skip=1
                    print ".",
    except:
        skip=0
        print "*",
    sys.stdout.flush()
    if skip==0:
        with open(filename,"wb") as fout:
            if rotate==1:
                rotated_buffer=bytearray(width*lines*3)
                png_width = lines
                png_height = width
                for l in range(0,lines):
                    for r in range(0,width):
                        for color in range(0,3):
                            rotated_buffer[color+l*3+r*(lines*3)] = frame[(frame_width*3)*(l+1)-((frame_width-width)*3+color+3*r)]
            else:
                png_width = frame_width
                png_height = lines                
                rotated_buffer = frame
            if scale_up:
                scaled = bytearray(png_width*png_height*(3*3)*3)
                cnt=0
                for h in range(0,png_height):
                    for hr in range(0,3):
                        for w in range(0,png_width):
                            for wr in range(0,3):
                                for c in range(0,3):
                                    scaled[cnt] = rotated_buffer[(png_width*h+w)*3+c]
                                    cnt=cnt+1
                rotated_buffer = scaled
                png_width = 3*png_width
                png_height = 3*png_height
            png_data = makeColourPNG( rotated_buffer, png_width, png_height) #png_height)
            fout.write(png_data)
    frame_cnt += 1
