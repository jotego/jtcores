package mem

import (
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
	re := regexp.MustCompile(`^[\d]*(\.[\d]+)?`)
	s = strings.TrimSpace(s)
	sm := re.FindString(s)
	mant,_ := strconv.ParseFloat(sm,64)
	s=s[len(sm):]
	if len(s)==0 { return mant }
	switch(s[0]) {
	case 'p': return mant*1e-12
	case 'n': return mant*1e-9
	case 'u': return mant*1e-6
	case 'm': return mant*1e-3
	case 'k': return mant*1e3
	case 'M': return mant*1e6
	case 'G': return mant*1e9
	case 'T': return mant*1e12
	}
	return mant
}

func calc_a( rc AudioRC, fs float64 ) (string,int) {
	r := eng2float(rc.R)
	c := eng2float(rc.C)
	wc := 1.0/(r*c*fs)
	fc := int(math.Round(1.0/(2*math.Pi*r*c)))
	a := math.Round(math.Exp(-wc)*256)
	return fmt.Sprintf("%02X",int(a)),fc
}

func make_audio( macros map[string]string, cfg *MemConfig ) {
	var modules map[string]AudioCh
	const fs = float64(192000)
	buf, e := os.ReadFile(filepath.Join(os.Getenv("JTFRAME"),"src","jtframe","mem","audio_mod.yaml"))
	must(e)
	must(yaml.Unmarshal(buf,&modules))
	// assign information derived from the module type
	for k,_ := range cfg.Audio {
		ch := &cfg.Audio[k]
		if ch.Name=="" {
			fmt.Printf("ERROR: anonymous audio channels are not allowed in mem.yaml\n")
			os.Exit(1)
		}
		mod, fnd := modules[ch.Module]
		if !fnd {
			fmt.Printf("Warning: ignored module statement %s for audio channel %s in mem.yaml\n",
			ch.Module, ch.Name )
			continue
		}
		// copy module information
		ch.Data_width = mod.Data_width
		ch.Unsigned   = mod.Unsigned
		ch.Stereo     = mod.Stereo
		ch.DCrm		  = mod.DCrm
		if ch.RC==nil { ch.RC = mod.RC }
		// Derive pole information
		p0 := "00"
		p1 := "00"
		if len(ch.RC)>=1 { p0,ch.Fcut[0] = calc_a(ch.RC[0], fs) }
		if len(ch.RC)>=2 { p1,ch.Fcut[1] = calc_a(ch.RC[1], fs) }
		if len(ch.RC)>2 {
			fmt.Printf("ERROR: Only two RC poles are supported")
			os.Exit(1)
		}
		ch.Pole=fmt.Sprintf("16'h%s%s",p1,p0)
	}
	if len(cfg.Audio)>5 {
		fmt.Printf("ERROR: Audio configuration requires %d channels\n",len(cfg.Audio))
		os.Exit(1)
	}
	// fill up to 5 channels
	if len(cfg.Audio)>0 {
		for k:=len(cfg.Audio);k<5;k++ {
			cfg.Audio = append(cfg.Audio, AudioCh{} )
		}
	}
	_, cfg.Stereo = macros["JTFRAME_STEREO"]
}