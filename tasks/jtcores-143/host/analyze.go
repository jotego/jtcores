// Analyze finite Yamaha captures without assuming absolute left/right wiring.
package main

import (
    "crypto/sha256"
    "encoding/binary"
    "encoding/csv"
    "encoding/json"
    "flag"
    "fmt"
    "math"
    "os"
    "strconv"
    "strings"
)

type capture struct {
    header [18]uint32
    samples []uint16
    digest string
}
type analysis struct {
    File string `json:"file"`
    SHA256 string `json:"sha256"`
    Mode uint32 `json:"mode"`
    SampleRate float64 `json:"sample_rate_hz"`
    Channels [2]channel_stats `json:"latch_channels"`
}
type channel_stats struct {
    Count int `json:"count"`
    Minimum int `json:"minimum"`
    Maximum int `json:"maximum"`
    Unique int `json:"unique_values"`
    InvalidExponent int `json:"invalid_exponent"`
    RMS float64 `json:"rms"`
    RisingCrossings int `json:"rising_zero_crossings"`
    Frequency float64 `json:"zero_crossing_hz,omitempty"`
}
type edge struct { at, channel int }

func main() {
    csv_prefix := flag.String("csv", "", "prefix for per-file, per-channel CSV artifacts")
    fixture_prefix := flag.String("fixture", "", "write RTL replay fixture from one raw capture")
    flag.Parse()
    if flag.NArg()==0 { fmt.Fprintln(os.Stderr,"Usage: analyze [-csv PREFIX] FILE..."); os.Exit(2) }
    for file_index,path := range flag.Args() {
        c,e := read_capture(path)
        if e!=nil { die(e) }
        words,rate,e := c.decode()
        if e!=nil { die(fmt.Errorf("%s: %w",path,e)) }
        if *fixture_prefix!="" {
            if flag.NArg()!=1 || c.header[11]!=1 { die(fmt.Errorf("fixture requires one raw capture")) }
            if e:=c.fixture(*fixture_prefix,words);e!=nil { die(e) }
        }
        result := analysis{File:path,SHA256:c.digest,Mode:c.header[11],SampleRate:rate}
        for ch:=0;ch<2;ch++ {
            result.Channels[ch] = summarize(words[ch],rate)
            if *csv_prefix!="" {
                path := fmt.Sprintf("%s-%d-%d.csv",*csv_prefix,file_index,ch)
                if e:=write_csv(path,words[ch]);e!=nil { die(e) }
            }
        }
        if e:=json.NewEncoder(os.Stdout).Encode(result);e!=nil { die(e) }
    }
}

func (c *capture) fixture(prefix string,words [2][]uint16) error {
    var stimulus, expected strings.Builder
    for _,w:=range c.samples { fmt.Fprintf(&stimulus,"%04x\n",w) }
    var edges []edge
    for i:=1;i<len(c.samples);i++ {
        before:=c.samples[i-1]^uint16(c.header[12])
        after:=c.samples[i]^uint16(c.header[12])
        if falling:=before & ^after & 3;falling!=0 { edges=append(edges,edge{i,int(falling>>1)}) }
    }
    var index [2]int
    count:=0
    for end:=1;end<len(edges);end++ {
        ch:=edges[end].channel
        w:=words[ch][index[ch]]
        index[ch]++
        // RTL needs the first interval to measure bit timing before sampling.
        if end==1 { continue }
        fmt.Fprintf(&expected,"%05x\n",uint32(ch)<<16|uint32(w))
        count++
    }
    parameters:=fmt.Sprintf("localparam STIMULUS_COUNT=%d, EXPECTED_COUNT=%d, PERIOD_TICKS=%d, INVERT=%d;\n",
        edges[len(edges)-1].at+2,count,c.header[5],c.header[12])
    for suffix,contents:=range map[string]string{
        ".stimulus.hex":stimulus.String(),".expected.hex":expected.String(),".vh":parameters,
    } {
        if e:=os.WriteFile(prefix+suffix,[]byte(contents),0600);e!=nil { return e }
    }
    return nil
}

func read_capture(path string) (*capture,error) {
    b,e := os.ReadFile(path)
    if e!=nil { return nil,e }
    if len(b)<80 || (string(b[:8])!="C96CAP02" && string(b[:8])!="C96CAP03" && string(b[:8])!="C96CAP04") {
        return nil,fmt.Errorf("%s: unsupported capture header",path)
    }
    c := &capture{digest:fmt.Sprintf("%x",sha256.Sum256(b))}
    for i:=range c.header { c.header[i]=binary.LittleEndian.Uint32(b[8+i*4:]) }
    h:=c.header
    if h[0]!=80 || (h[1]!=2 && h[1]!=3 && h[1]!=4) || h[7]>0xffffff ||
       h[3]>32768 || h[4]==0 || h[4]>32768 || h[3]>h[4] ||
       h[5]==0 || h[6]!=100000000 || h[8]&1!=0 || h[8]&2==0 ||
       h[8]&^uint32(15)!=0 || h[9]!=16 || h[10]!=h[3]*2 ||
       len(b)!=80+int(h[10]) || h[12]>15 || h[13]>3 || h[14]!=0 || h[16]!=0 || h[17]!=0 {
        return nil,fmt.Errorf("%s: invalid metadata, length or framing errors",path)
    }
    if (h[1]==2 && (string(b[:8])!="C96CAP02" || h[11]!=1 || h[15]!=0)) ||
       (h[1]==3 && (string(b[:8])!="C96CAP03" || h[11]!=3 || h[15]<1024 || h[15]>4096)) ||
       (h[1]==4 && (string(b[:8])!="C96CAP04" || h[11]!=3 || h[15]<1024 || h[15]>4096 || h[5]>1024)) {
        return nil,fmt.Errorf("%s: expected raw v2 or Yamaha v3/v4 capture",path)
    }
    c.samples=make([]uint16,h[3])
    for i:=range c.samples { c.samples[i]=binary.LittleEndian.Uint16(b[80+2*i:]) }
    return c,nil
}

func (c *capture) decode() ([2][]uint16,float64,error) {
    var words [2][]uint16
    if c.header[11]==3 {
        for i,w:=range c.samples { words[i%2]=append(words[i%2],w) }
        stride:=uint32(1)
        if c.header[1]==4 { stride=c.header[5] }
        return words,float64(c.header[6])/(float64(c.header[15])*float64(stride)),nil
    }
    var edges []edge
    for i,w:=range c.samples {
        if w>15 { return words,0,fmt.Errorf("raw sample exceeds four bits") }
        if i==0 { continue }
        before:=c.samples[i-1]^uint16(c.header[12])
        after:=w^uint16(c.header[12])
        falling:=before & ^after & 3
        if falling==3 { return words,0,fmt.Errorf("simultaneous SH falling edges") }
        if falling!=0 { edges=append(edges,edge{i,int(falling>>1)}) }
    }
    if len(edges)<5 { return words,0,fmt.Errorf("not enough alternating SH edges") }
    half_span:=float64(edges[len(edges)-1].at-edges[0].at)/float64(len(edges)-1)
    if half_span<32 { return words,0,fmt.Errorf("raw sampling too slow for stable bit centers") }
    for i:=1;i<len(edges);i++ {
        begin,end:=edges[i-1],edges[i]
        span:=end.at-begin.at
        if begin.channel==end.channel || math.Abs(float64(span)-half_span)>2 {
            return words,0,fmt.Errorf("malformed SH phase near sample %d",end.at)
        }
        var word uint16
        for bit:=0;bit<16;bit++ {
            at:=int(math.Round(float64(begin.at)+(float64(bit)+.5)*float64(span)/16))
            level:=(c.samples[at]^uint16(c.header[12]))>>2 & 1
            for _,neighbor:=range []int{at-1,at+1} {
                if (c.samples[neighbor]^uint16(c.header[12]))>>2&1!=level {
                    return words,0,fmt.Errorf("unstable SO bit center near sample %d",at)
                }
            }
            word|=level<<bit
        }
        words[end.channel]=append(words[end.channel],word)
    }
    return words,float64(c.header[6])/(float64(c.header[5])*half_span*2),nil
}

func summarize(words []uint16,rate float64) channel_stats {
    s:=channel_stats{Count:len(words)}
    unique:=make(map[int]bool)
    var sum, previous, first_cross, last_cross float64
    for i,w:=range words {
        value,valid:=linear(w)
        if !valid { s.InvalidExponent++ }
        if i==0 || value<s.Minimum { s.Minimum=value }
        if i==0 || value>s.Maximum { s.Maximum=value }
        unique[value]=true
        sum+=float64(value)*float64(value)
        if i>0 && previous<0 && value>=0 {
            cross:=float64(i-1)-previous/(float64(value)-previous)
            if s.RisingCrossings==0 { first_cross=cross }
            last_cross=cross
            s.RisingCrossings++
        }
        previous=float64(value)
    }
    s.Unique=len(unique)
    if s.Count>0 { s.RMS=math.Sqrt(sum/float64(s.Count)) }
    if s.RisingCrossings>1 { s.Frequency=rate*float64(s.RisingCrossings-1)/(last_cross-first_cross) }
    return s
}

func linear(word uint16) (int,bool) {
    exp:=word>>13
    if exp==0 { return 0,false }
    return (int(word>>3&1023)-512)<<uint(exp-1),true
}

func write_csv(path string,words []uint16) error {
    file,e:=os.OpenFile(path,os.O_CREATE|os.O_EXCL|os.O_WRONLY,0600)
    if e!=nil { return e }
    defer file.Close()
    out:=csv.NewWriter(file)
    if e:=out.Write([]string{"sample","raw16_hex","linear"});e!=nil { return e }
    for i,w:=range words {
        value,_:=linear(w)
        if e:=out.Write([]string{strconv.Itoa(i),fmt.Sprintf("%04x",w),strconv.Itoa(value)});e!=nil { return e }
    }
    out.Flush()
    return out.Error()
}

func die(e error) { fmt.Fprintln(os.Stderr,e);os.Exit(1) }
