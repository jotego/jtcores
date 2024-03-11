package mem

import (
	"bufio"
	"fmt"
	"math"
	"os"
	"regexp"
	"strings"
	"strconv"
	"path/filepath"
	"gopkg.in/yaml.v2"
)

func must( e error ) {
	if e!=nil {
		fmt.Println(e)
		os.Exit(1)
	}
}

func eng2float( s string ) float64 {
	const ym14=5000.0
	const ym12=2000.0
	re := regexp.MustCompile(`^[\d]*(\.[\d]+)?`)
	s = strings.TrimSpace(s)
	input := s
	sm := re.FindString(s)
	mant,_ := strconv.ParseFloat(sm,64)
	s=s[len(sm):]
	if len(s)==0 { return mant }
	if sm=="" && s!="" { mant = 1.0 }
	switch(s) {
	// output impedance of sound chips
	case "ym12": return mant*ym12	// YM3012 output impedance (seen with YM2151)
	case "ym14": return mant*ym14	// YM3014 output impedance (seen with YM2203)
	case "para14": return mant*ym14/(mant+ym14) // parallel of a resistor with YM3014's output impedance
	case "ay": return mant*4.0	// gain for an AY-3-8910 connected to 10 kOhm
	// standard suffixes
	case "p": return mant*1e-12
	case "n": return mant*1e-9
	case "u": return mant*1e-6
	case "m": return mant*1e-3
	case "k": return mant*1e3
	case "M": return mant*1e6
	case "G": return mant*1e9
	case "T": return mant*1e12
	default: {
		fmt.Printf("ERROR: unknown suffix %s\n in %s (mem.yaml)\n",s,input)
		os.Exit(1)
	}
	}
	return mant
}

func calc_a( rc AudioRC, fs float64 ) (string,int) {
	r := eng2float(rc.R)
	c := eng2float(rc.C)
	if r==0 || c==0 { return "00",0 }
	wc := 1.0/(r*c*fs)
	fc := int(math.Round(1.0/(2*math.Pi*r*c)))
	a := math.Round(math.Exp(-wc)*256)
	return fmt.Sprintf("%02X",int(a)),fc
}

func read_modules() map[string]AudioCh {
	var modules map[string]AudioCh
	buf, e := os.ReadFile(filepath.Join(os.Getenv("JTFRAME"),"src","jtframe","mem","audio_mod.yaml"))
	must(e)
	must(yaml.Unmarshal(buf,&modules))
	return modules
}

func make_fir( core, outpath string, ch *AudioCh, fs float64 ) {
	const scale = 32767	// 16 bits, signed
	if ch.Fir=="" { return }
	coeff := make([]int,0,128)
	fname := filepath.Join(os.Getenv("CORES"),core,"cfg",ch.Fir)
	f, e := os.Open(fname)
	must(e)
	scanner := bufio.NewScanner(f)
	cnt:=0
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		comment := strings.Index(line,"#")
		if comment==0 || line=="" { continue }
		if comment!=-1 { line = line[0:comment] }
		c, e := strconv.ParseFloat(line,64)
		if e!=nil {
			fmt.Printf("Cannot parse float number in file %s\n",ch.Fir)
			os.Exit(1)
		}
		c *= scale
		coeff = append(coeff,int(c))
		cnt+=1
		if cnt>127 {
			fmt.Printf("Too many coefficients for FIR filter. Max is 127\n")
			os.Exit(1)
		}
	}
	f.Close()
	// Save the file
	fname = ch.Fir
	if i:=strings.LastIndex(fname,"."); i!=-1 { fname = fname[0:i] }
	fname += ".hex"
	ch.Firhex=fname
	fname = filepath.Join(outpath,fname)
	f, e = os.Create(fname)
	must(e)
	for _, each := range coeff {
		fmt.Fprintf(f,"%04X\n",each&0xffff)
	}
	f.Close()
}

func make_rc( ch *AudioCh, fs float64 ) {
	if ch.Fir != "" {
		ch.Pole = "16'h00"
		ch.Filters = 1	// the FIR one
		return
	}
	ch.Filters=0
	for k:=0; k<len(ch.RC); {
		p0 := "00"
		p1 := "00"
		if k  <len(ch.RC) { p0,ch.Fcut[0] = calc_a(ch.RC[k  ], fs) }
		if k+1<len(ch.RC) { p1,ch.Fcut[1] = calc_a(ch.RC[k+1], fs) }
		hex := fmt.Sprintf("16'h%s%s",p1,p0)
		if ch.Rc_en {
			if k==0 && len(ch.RC)<3 {
				ch.Pole=fmt.Sprintf("%s%s_rcen?%s : ",ch.Pole,ch.Name,hex)
			} else {
				ch.Pole=fmt.Sprintf("%s%s_rcen[%d]?%s : ",ch.Pole,ch.Name,k>>1,hex)
			}
		} else {
			ch.Pole=hex
		}
		ch.Filters+=1
		k+=2
		if !ch.Rc_en { break } // only first two poles taken unless rc_en is set to true
	}
	if ch.Rc_en { ch.Pole=fmt.Sprintf("%s16'h0",ch.Pole) }
}

func make_audio( macros map[string]string, cfg *MemConfig, core, outpath string ) {
	modules := read_modules()
	const fs = float64(192000)
	// assign information derived from the module type
	rmin := 0.0
	for _,ch := range cfg.Audio.Channels {
		if ch.Rsum=="" {
			fmt.Printf("rsum missing for audio channel %s\n",ch.Name)
			os.Exit(1)
		}
		rsum := eng2float(ch.Rsum)
		if rsum<=0 {
			fmt.Printf("rsum must be >0 in audio channel %s\n",ch.Name)
			os.Exit(1)
		}
		if (rsum>0 && rsum < rmin) || rmin==0 { rmin=rsum }
	}
	var gmax float64
	for k,_ := range cfg.Audio.Channels {
		ch := &cfg.Audio.Channels[k]
		if ch.Name=="" {
			fmt.Printf("ERROR: anonymous audio channels are not allowed in mem.yaml\n")
			os.Exit(1)
		}
		mod, fnd := modules[ch.Module]
		if !fnd && ch.Module!="" {
			fmt.Printf("Warning: ignored module statement %s for audio channel %s in mem.yaml\n",
			ch.Module, ch.Name )
			continue
		}
		if fnd {
			// copy module information
			ch.Data_width = mod.Data_width
			ch.Unsigned   = mod.Unsigned
			ch.Stereo     = mod.Stereo
			ch.DCrm		  = mod.DCrm
		}
		// if ch.RC==nil { ch.RC = mod.RC }
		// Derive pole information
		make_rc(  ch, fs )
		make_fir( core, outpath, ch, fs )
		ch.gain=rmin/eng2float(ch.Rsum)
		if ch.Pre != "" { ch.gain *= eng2float(ch.Pre) }
		// fmt.Printf("%6s - %f - %s %f -> %f\n",ch.Name,ch.Pre,ch.Rsum,rmin,ch.gain)
		// if (int(gint)>>4) > 15 {
		// 	fmt.Printf("Gain unbalance among audio channels is too large")
		// 	os.Exit(1)
		// }
		if gmax==0 || ch.gain>gmax { gmax=ch.gain }
	}
	rsum := eng2float(cfg.Audio.Rsum)
	for k,_ := range cfg.Audio.Channels {
		ch := &cfg.Audio.Channels[k]
		ch.gain = ch.gain/gmax*rmin/rsum
		ch.Gain = fmt.Sprintf("8'h%02X",int(ch.gain*16)&0xff)
	}
	if len(cfg.Audio.Channels)>5 {
		fmt.Printf("ERROR: Audio configuration requires %d channels\n",len(cfg.Audio.Channels))
		os.Exit(1)
	}
	// fill up to 5 channels
	if len(cfg.Audio.Channels)>0 {
		for k:=len(cfg.Audio.Channels);k<5;k++ {
			cfg.Audio.Channels = append(cfg.Audio.Channels, AudioCh{ Gain: "8'h00" } )
		}
	}
	_, cfg.Stereo = macros["JTFRAME_STEREO"]
}