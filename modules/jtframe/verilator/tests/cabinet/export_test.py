#!/usr/bin/env python3
import struct
import subprocess
import sys
import tempfile
import zlib
from pathlib import Path

packer=Path(sys.argv[1]).resolve()
with tempfile.TemporaryDirectory() as temporary:
    root=Path(temporary); source=root/'test.cab'; output=root/'test.jtcab'
    source.write_text('2\n=5 coin\nloop\nb1\n2\nrepeat 2\n')
    result=subprocess.run([str(packer),str(source),str(output),'16'],capture_output=True,text=True)
    assert result.returncode==0,result.stderr
    data=output.read_bytes(); header=struct.unpack('<8s6I',data[:32])
    assert header[0:3]==(b'JTCAB01\0',1,16) and header[4]==0 and header[6]==32
    assert zlib.crc32(data[32:])==header[5]
    runs=list(struct.iter_unpack('<II',data[32:])); assert len(runs)==header[3]
    frames=[mask for duration,mask in runs for _ in range(duration)]
    assert frames==[0]*5+[1,0x100,0,0,0x100]+[0]*6,frames
    sentinel=b'preserve existing output'
    for directive in ['cheat=test']:
        source.write_text(directive+'\n'); output.write_bytes(sentinel)
        result=subprocess.run([str(packer),str(source),str(output)],capture_output=True,text=True)
        assert result.returncode!=0 and 'not supported' in result.stderr
        assert output.read_bytes()==sentinel
    source.write_text('2 coin\n')
    result=subprocess.run([str(packer),str(source),str(output),'1'],capture_output=True,text=True)
    assert result.returncode!=0 and output.read_bytes()==sentinel
    source.write_text('2 tracing_on\n')
    result=subprocess.run([str(packer),str(source),str(output)],capture_output=True,text=True)
    assert result.returncode==0 and 'marker at frame 0' in result.stderr
    source.write_text('2\n=5 dipsw=89ABCDEF coin\n2 b1\nloop\ndipsw=0\ndipsw=ffffffff\nrepeat 2\n')
    result=subprocess.run([str(packer),str(source),str(output),'16'],capture_output=True,text=True)
    assert result.returncode==0,result.stderr
    data=output.read_bytes(); header=struct.unpack('<8s6I',data[:32])
    assert header[:3]==(b'JTCAB02\0',2,16) and zlib.crc32(data[32:])==header[5]
    runs=list(struct.iter_unpack('<III',data[32:])); assert len(runs)==header[3]
    current=None; frames=[]
    for count,mask,dip in runs:
        if mask&0x200000: current=dip
        frames.extend([(mask&0x1fffff,current)]*count)
    assert frames==[(0,None)]*5+[(1,0x89abcdef)]+[(0x100,0x89abcdef)]*2+[(0,0),(0,0xffffffff)]*2+[(0,0xffffffff)]*4,frames
    source.write_text('dipsw=0\n2\n')
    result=subprocess.run([str(packer),str(source),str(output)],capture_output=True,text=True)
    assert result.returncode==0
    assert list(struct.iter_unpack('<III',output.read_bytes()[32:]))==[(3,0x200000,0)]
print('PASS: packed CAB CRC/length/frame semantics, padding and unsupported-directive preflight')

with tempfile.TemporaryDirectory() as temporary:
    root=Path(temporary); source=root/'dump.cab'; output=root/'dump.jtcab'
    source.write_text('2\n=5 dump coin dipsw=abcd\n2 dump\nloop\ndump\n1\nrepeat 2\n')
    result=subprocess.run([str(packer),str(source),str(output),'16'],capture_output=True,text=True)
    assert result.returncode==0,result.stderr
    data=output.read_bytes(); header=struct.unpack('<8s6I',data[:32])
    assert header[:3]==(b'JTCAB03\0',3,16) and header[4]==5
    assert zlib.crc32(data[32:])==header[5]
    runs=list(struct.iter_unpack('<III',data[32:])); frames=[]
    for count,mask,dip in runs: frames.extend([(mask,dip)]*count)
    assert [i for i,(mask,dip) in enumerate(frames) if mask&0x400000]==[5,6,7,8,10]
    assert frames[5]==(0x600001,0xabcd)
    assert frames[-1]==(0x200000,0xabcd) # Padding must never repeat the dump flag.
    source.write_text('2 dump\n')
    result=subprocess.run([str(packer),str(source),str(output),'4'],capture_output=True,text=True)
    assert result.returncode==0
    assert struct.unpack('<8s6I',output.read_bytes()[:32])[4]==2
    assert list(struct.iter_unpack('<III',output.read_bytes()[32:]))==[(2,0x400000,0),(2,0,0)]
print('PASS: dump frame/count/absolute/loop/padding semantics')
