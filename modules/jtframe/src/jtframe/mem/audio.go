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

	"github.com/jotego/jtframe/common"
)

var rout float64

func eng2float( s string ) float64 {
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
	case "para": return mant*rout/(mant+rout) // parallel of a resistor with module's output impedance
	case "ay": return mant*4.0		// gain for an AY-3-8910 connected to 10 kOhm
	case "rout": return mant*rout
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
	buf, e := os.ReadFile(filepath.Join(os.Getenv("JTFRAME"),"hdl","sound","audio_mod.yaml"))
	common.Must(e)
	common.Must(yaml.Unmarshal(buf,&modules))
	return modules
}

func make_fir( core, outpath string, ch *AudioCh, fs float64 ) {
	const scale = 0x7FFF	// 16 bits, signed
	if ch.Fir=="" { return }
	coeff := make([]int,128)
	fname := common.Find_in_folders( ch.Fir,
		[]string{
			filepath.Join(os.Getenv("CORES"),core,"cfg"),
			filepath.Join(os.Getenv("JTFRAME"),"hdl","sound"),
		}, true)
	f, e := os.Open(fname)
	common.Must(e)
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
		coeff[cnt] = int(c)
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
	common.Must(e)
	for _, each := range coeff {
		fmt.Fprintf(f,"%04X\n",each&0xffff)
	}
	for k:=0;k<512-128;k+=1 { fmt.Fprintln(f,"0000")} // fill the rest of file
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

func fill_audio_clock( macros map[string]string, cfg *Audio ) {
	aux, _ := macros["JTFRAME_MCLK"]
	fmhz, _ := strconv.Atoi(aux)
	fmhz *= 1000
	cfg.FracN,cfg.FracM = find_div(float64(fmhz), 192000.0 )
	cfg.FracW = int( math.Ceil(math.Log2( float64(max( cfg.FracM, cfg.FracN )) )))+1
}

func fill_global_pole( cfg *Audio, fs float64 ) {
	if cfg.RC.R=="" || cfg.RC.C=="" {
		// add a pole at 20kHz for all cores
		cfg.RC.R="8k"
		cfg.RC.C="1n"
	}
	cfg.GlobalPole, cfg.GlobalFcut = calc_a(cfg.RC, fs)
	cfg.GlobalPole = fmt.Sprintf("8'h%s",cfg.GlobalPole)
}


func make_audio( macros map[string]string, cfg *MemConfig, core, outpath string ) {
	fill_audio_clock( macros, &cfg.Audio )
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
	fill_global_pole( &cfg.Audio, fs )
	var gmax float64
	for k,_ := range cfg.Audio.Channels {
		ch := &cfg.Audio.Channels[k]
		if ch.Name=="" {
			fmt.Printf("ERROR: anonymous audio channels are not allowed in mem.yaml\n")
			os.Exit(1)
		}
		mod, fnd := modules[ch.Module]
		if !fnd && ch.Module!="" {
			fmt.Printf("Error: unknown module statement %s for audio channel %s in mem.yaml\n",
			ch.Module, ch.Name )
			os.Exit(1)
		}
		if fnd {
			// copy module information
			ch.Data_width = mod.Data_width
			ch.Unsigned   = mod.Unsigned
			ch.Stereo     = mod.Stereo
			ch.DCrm       = mod.DCrm
			ch.Vpp		  = mod.Vpp
			rout          = 0
			rout          = eng2float(mod.Rout)
		}
		// if ch.RC==nil { ch.RC = mod.RC }
		// Derive pole information
		make_rc(  ch, fs )
		make_fir( core, outpath, ch, fs )
		ch.gain=rmin/eng2float(ch.Rsum)
		if ch.Pre != "" { ch.gain *= eng2float(ch.Pre) }
		if ch.Vpp != "" { ch.gain *= eng2float(ch.Vpp) }
		// fmt.Printf("%6s - %f - %s %f -> %f\n",ch.Name,ch.Pre,ch.Rsum,rmin,ch.gain)
		// if (int(gint)>>4) > 15 {
		// 	fmt.Printf("Gain unbalance among audio channels is too large")
		// 	os.Exit(1)
		// }
		if gmax==0 || ch.gain>gmax { gmax=ch.gain }
	}
	rsum := eng2float(cfg.Audio.Rsum)
	if rsum==0 { rsum = rmin }
	const FRAC_BITS=6
	const INTEGER=1<<FRAC_BITS
	for k,_ := range cfg.Audio.Channels {
		ch := &cfg.Audio.Channels[k]
		ch.gain = ch.gain/gmax*rmin/rsum
		ch.Gain = fmt.Sprintf("8'h%02X",int(ch.gain*INTEGER)&0xff)
	}
	const MaxCh=6
	if len(cfg.Audio.Channels)>MaxCh {
		fmt.Printf("ERROR: Audio configuration requires %d channels, but maximum supported is %d\n",len(cfg.Audio.Channels),MaxCh)
		os.Exit(1)
	}
	// fill up to 6 channels
	if len(cfg.Audio.Channels)>0 {
		for k:=len(cfg.Audio.Channels);k<MaxCh;k++ {
			cfg.Audio.Channels = append(cfg.Audio.Channels, AudioCh{ Gain: "8'h00" } )
		}
	}
	_, cfg.Stereo = macros["JTFRAME_STEREO"]
}