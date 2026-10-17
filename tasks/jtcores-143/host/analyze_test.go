package main

import (
    "encoding/binary"
    "os"
    "path/filepath"
    "testing"
)

func TestLinear(t *testing.T) {
    for _,v:=range []struct{word uint16;want int;valid bool}{
        {0x3000,0,true},{0x3ff8,511,true},{0x2000,-512,true},
        {0xfff8,32704,true},{0xe000,-32768,true},{0,0,false},
        {0x3007,0,true},
    } {
        got,valid:=linear(v.word)
        if got!=v.want || valid!=v.valid { t.Fatalf("%04x: %d,%v",v.word,got,valid) }
    }
}

func TestCaptureMetadata(t *testing.T) {
    header:=[18]uint32{80,3,1,2,2,1,100000000,12,2,16,4,3,15,0,0,1788,0,0}
    pack:=func(h [18]uint32) []byte {
        b:=make([]byte,84)
        copy(b,"C96CAP03")
        for i,v:=range h { binary.LittleEndian.PutUint32(b[8+4*i:],v) }
        binary.LittleEndian.PutUint16(b[80:],0x3000)
        binary.LittleEndian.PutUint16(b[82:],0x3ff8)
        return b
    }
    path:=filepath.Join(t.TempDir(),"capture.cap")
    if e:=os.WriteFile(path,pack(header),0600);e!=nil { t.Fatal(e) }
    c,e:=read_capture(path)
    if e!=nil { t.Fatal(e) }
    words,_,e:=c.decode()
    if e!=nil || len(words[0])!=1 || len(words[1])!=1 { t.Fatal("stereo decode",e) }
    for _,mutation:=range []struct{field int;value uint32}{
        {3,32769},{4,1},{6,0},{8,3},{9,8},{10,2},{11,2},
        {12,16},{13,4},{14,1},{15,0},{16,1},{17,1},
    } {
        h:=header;h[mutation.field]=mutation.value
        if e:=os.WriteFile(path,pack(h),0600);e!=nil { t.Fatal(e) }
        if _,e:=read_capture(path);e==nil { t.Fatalf("accepted invalid field %d",mutation.field) }
    }
    for _,b:=range [][]byte{pack(header)[:83],append(pack(header),0)} {
        if e:=os.WriteFile(path,b,0600);e!=nil { t.Fatal(e) }
        if _,e:=read_capture(path);e==nil { t.Fatal("accepted truncated/trailing payload") }
    }
}

func TestRawIndependentFraming(t *testing.T) {
    // Construct SO independently from the decoder, then compare every full word.
    c:=&capture{}
    c.header[5]=1;c.header[6]=100000000;c.header[11]=1;c.header[12]=7
    const ticks=56
    corrected:=uint16(3)
    var source []uint16
    for index:=0;index<12;index++ {
        w:=uint16(0x3000+index*0x61)
        source=append(source,w)
        corrected &^=1<<uint(index%2)
        for bit:=0;bit<16;bit++ {
            if bit==8 { corrected|=1<<uint((index+1)%2) }
            corrected=(corrected &^4) | ((w>>uint(bit)&1)<<2)
            for j:=0;j<ticks;j++ { c.samples=append(c.samples,corrected^7) }
        }
    }
    words,rate,e:=c.decode()
    if e!=nil { t.Fatal(e) }
    if rate!=100000000.0/(ticks*32) { t.Fatal(rate) }
    // Capture begins on an edge; the first observable boundary is word 1.
    for end:=2;end<12;end++ {
        ch:=end%2;slot:=(end-2)/2
        if words[ch][slot]!=source[end-1] { t.Fatalf("word %d: %04x",end,words[ch][slot]) }
    }
    // Destroy a strobe, making channel boundaries repeat.
    for i:=48*ticks;i<80*ticks;i++ { c.samples[i]&^=2 }
    if _,_,e:=c.decode();e==nil { t.Fatal("malformed framing accepted") }
}
