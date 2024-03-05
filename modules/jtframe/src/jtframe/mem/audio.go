package mem

import (
	"fmt"
	"os"
	// "strings"
	"path/filepath"
	"gopkg.in/yaml.v2"
)

func must( e error ) {
	if e!=nil {
		fmt.Println(e)
		os.Exit(1)
	}
}

// func calc_a( rc AudioRC ) string {
// 	r := strconv.ParseFloat(rc.R )
// 	a = math.Exp
// }

func make_audio( macros map[string]string, cfg *MemConfig ) {
	var modules map[string]AudioCh
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
		if len(ch.RC)>=1 { p0 = calc_a(ch.RC[0]) }
		if len(ch.RC)>=2 { p1 = calc_a(ch.RC[1]) }
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
	for k:=len(cfg.Audio);k<5;k++ {
		cfg.Audio = append(cfg.Audio, AudioCh{} )
	}
	_, cfg.Stereo = macros["JTFRAME_STEREO"]
}