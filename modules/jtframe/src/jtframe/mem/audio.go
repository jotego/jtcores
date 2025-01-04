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

	"github.com/jotego/jtframe/def"
	"github.com/jotego/jtframe/common"
)

var rout float64
var audio_modules map[string]AudioCh

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

// a coefficient of the low pass filter
// b coefficient = 1-a
// Tangent function used for frequency pre-warping
func calc_a( rc AudioRC, fs float64, bits int ) (string,int) {
	r := eng2float(rc.R)
	c := eng2float(rc.C)
	if r==0 || c==0 { return "00",0 }
	fc := math.Round(1.0/(2*math.Pi*r*c))
	if fc>fs*.49 {
		return "0000",int(fc)
	}
	wc := math.Tan(math.Pi*fc/fs)
	a := math.Round((1.0-wc)/(wc+1.0)*(math.Pow(2,float64(bits))-1.0))
	if wc>1.0 { a=0 }
	return fmt.Sprintf("%04X",int(a)&0xffff),int(fc)
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
	rout = ch.rout
	const bits=15
	if ch.Fir != "" {
		ch.Pole = fmt.Sprintf("%d'h00",bits*2)
		ch.Filters = 1	// the FIR one
		return
	}
	ch.Filters=0
	for k:=0; k<len(ch.RC); {
		p0 := "00"
		p1 := "00"
		if k  <len(ch.RC) { p0,ch.Fcut[0] = calc_a(ch.RC[k  ], fs, bits) }
		if k+1<len(ch.RC) { p1,ch.Fcut[1] = calc_a(ch.RC[k+1], fs, bits) }
		hex := fmt.Sprintf("{%d'h%s,%d'h%s}",bits,p1,bits,p0)
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
	if ch.Rc_en { ch.Pole=fmt.Sprintf("%s%d'h0",ch.Pole,bits*2) }
}

func fill_audio_clock( cfg *Audio ) {
	fmhz := def.Macros.GetInt("JTFRAME_MCLK")
	cfg.FracN,cfg.FracM = find_div(float64(fmhz), 192000.0 )
	cfg.FracW = int( math.Ceil(math.Log2( float64(max( cfg.FracM, cfg.FracN )) )))+1
}

func fill_global_pole( cfg *Audio, fs float64 ) {
	const bits=15
	if cfg.RC.R=="" || cfg.RC.C=="" {
		// add a pole at 20kHz for all cores
		cfg.RC.R="8k"
		cfg.RC.C="1n"
	}
	cfg.GlobalPole, cfg.GlobalFcut = calc_a(cfg.RC, fs,bits)
	cfg.GlobalPole = fmt.Sprintf("%d'h%s",bits,cfg.GlobalPole)
}


func Make_audio( cfg *MemConfig, core, outpath string ) error {
	fill_audio_clock( &cfg.Audio )
	const fs = float64(192000)
	// assign information derived from the module type
	if e := validate_channels(cfg.Audio.Channels); e!=nil { return e }
	rmin,rmax := find_rlimits(cfg.Audio.Channels)
	fill_global_pole( &cfg.Audio, fs )
	rsum := eng2float(cfg.Audio.Rsum)
	if rsum==0 { rsum = rmax }
	for k,_ := range cfg.Audio.Channels {
		ch := &cfg.Audio.Channels[k]
		mod, fnd := audio_modules[ch.Module]
		if fnd {
			copy_module_data(mod,ch)
		}
		rout = 0
		rout = eng2float(ch.Rout)
		ch.rout = rout
		make_audio_filters( core, outpath, ch, fs )
		if cfg.Audio.Rsum_feedback_res {
			ch.gain=eng2float(ch.Rsum)/rsum
		} else {
			ch.gain=rmin/eng2float(ch.Rsum)
		}
		if ch.Pre != "" { ch.gain *= eng2float(ch.Pre) }
		if ch.Vpp != "" { ch.gain *= eng2float(ch.Vpp) }
	}
	if e := normalize_gains( cfg.Audio.Channels, cfg.Audio.Gain ); e!=nil {return e}
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
	cfg.Stereo = def.Macros.IsSet("JTFRAME_STEREO")
	return nil
}

func validate_channels( all_channels []AudioCh) error {
	for _,ch := range all_channels {
		if ch.Rsum=="" {
			return fmt.Errorf("rsum missing for audio channel %s\n",ch.Name)
		}
		rsum := eng2float(ch.Rsum)
		if rsum<=0 {
			return fmt.Errorf("rsum must be >0 in audio channel %s\n",ch.Name)
		}
		if ch.Name=="" {
			return fmt.Errorf("ERROR: anonymous audio channels are not allowed in mem.yaml\n")
		}
		_, fnd := audio_modules[ch.Module]
		if !fnd && ch.Module!="" {
			return fmt.Errorf("Error: unknown module statement %s for audio channel %s in mem.yaml\n",
			ch.Module, ch.Name )
		}
	}
	return nil
}

func find_rlimits( all_channels []AudioCh ) (rmin, rmax float64) {
	for _,ch := range all_channels {
		rsum := eng2float(ch.Rsum)
		if (rsum>0 && rsum < rmin) || rmin==0 { rmin=rsum }
		if rsum>0 && rsum > rmax { rmax=rsum }
	}
	return rmin,rmax
}

func copy_module_data( src AudioCh, dst *AudioCh ) {
	dst.Data_width = src.Data_width
	dst.Unsigned   = src.Unsigned
	dst.Stereo     = src.Stereo
	dst.DCrm       = src.DCrm
	dst.Vpp		   = src.Vpp
	dst.Rout       = src.Rout
}

func make_audio_filters(core, outpath string, ch *AudioCh, fs float64) {
	make_rc( ch, fs )
	make_fir( core, outpath, ch, fs )
}

func normalize_gains( all_channels []AudioCh, global float64 ) error {
	const FRAC_BITS=7 // must match jtframe_sndchain.WD
	const INTEGER=1<<FRAC_BITS
	if global==0 {
		global=1.0
	}
	var gmax float64
	for _,ch := range all_channels {
		if gmax==0 || ch.gain>gmax { gmax=ch.gain }
	}
	for k,_ := range all_channels {
		ch := &all_channels[k]
		ch.gain = ch.gain/gmax*global
		intg := int(ch.gain*INTEGER)
		if (intg&^0xff)!=0 {
			return fmt.Errorf("Error: cannot fit audio gain in 8 bits\n")
		}
		ch.Gain = fmt.Sprintf("8'h%02X",intg&0xff)
		if verbose {
			fmt.Printf("channel %d, gain %X\n",k,ch.Gain)
		}
	}
	return nil
}

func init() {
	audio_modules = read_modules()
}