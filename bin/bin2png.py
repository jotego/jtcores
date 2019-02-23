#! /usr/bin/python
import zlib
import struct

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

def makeColourPNG(data, width = 256, height = 224):
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
aux = bytearray( fin.read() )
print("Len = %d" % len(aux))
video_data = bytearray( len(aux)/2 )
c=0
# verilog outputs 32 bits per pixel
# drops each second word:
for k in range(0,len(aux),4):
    video_data[c]   = aux[k]
    video_data[c+1] = aux[k+1]
    c+=2

fin.close()

pxl=0

#look for start
frame_start=0
frame_cnt = 0
while frame_start < len(video_data)-2:
    while (video_data[frame_start+1]&0x20) == 0x20 and frame_start<len(video_data)-2:
        frame_start += 2

    if frame_start>=len(video_data)-2:
        print "Done"
        break

    frame = bytearray(356*259*3)
    dumped=frame_start
    width=0
    c=0
    lines=0

    for k in range(frame_start,len(video_data),2):
        sync = (video_data[k+1]>>4)

        if (sync&2) == 2: # VSYNC
            #print("Vsync after %d lines" % lines) # 356x259
            dumped = k
            break
        if (sync&1) == 1: # Hsync
            if width !=0:
                #print("Line extended over %d " % width)
                lines +=1
            width = 0
            continue
        red  = video_data[k+1]&0xf
        green= video_data[k]>>4
        blue = video_data[k]&0xf
        frame[c  ] = red   * 17
        frame[c+1] = green * 17
        frame[c+2] = blue  * 17
        c+=3
        width+=1
    if dumped == frame_start:
        break

    print("Frame extended over %d pixels" % ((dumped-frame_start)/2))
    frame_start = k    
    # save PNG
    with open("img%03d.png"%frame_cnt,"wb") as fout:
        png_data = makeColourPNG(frame, 356, 259)
        fout.write(png_data)
    frame_cnt += 1
