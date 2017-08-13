#!/usr/bin/python
import png
import sys

lines=[]
cnt=0

print sys.argv[1]

with open(sys.argv[1],'rb') as f:
	newline=[]
	info=0
	while (info==0):
		blue = f.read(1)
		green= f.read(1)
		red  = f.read(1)
		info = f.read(1)
		if(info==0xff):
			break
		newline.append(red)
		newline.append(blue)
		newline.append(green)
	if( info==0xff ):
		print len(newline)
		lines.append(newline)
#	if(f.eof):
#		print "Total lines=", len(lines)
#		break
print "Total lines=", len(lines)

with open('output.png','wb') as f:
	w = png.Writer(bitdepth=8,height=len(lines),width=len(lines[0])/3)
	w.write(f,lines)
