/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Date: 4-1-2025 */

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
	"text/template"

	"github.com/jotego/jtframe/macros"
	"github.com/jotego/jtframe/common"

	"gopkg.in/yaml.v2"
)

var rout float64
var audio_modules map[string]AudioCh
var audio_template_functions template.FuncMap

func init() {
	audio_modules = read_modules()
	audio_template_functions = template.FuncMap{
		"gain2dec": Gain2dec,
	}
}

func Make_audio( cfg *MemConfig, core, outpath string ) error {
	fill_audio_clock( &cfg.Audio )
	const fs = float64(192000)
	// assign information derived from the module type
	if e := validate_channels(cfg.Audio.Channels); e!=nil { return e }
	_,_,rtotal := find_rlimits(cfg.Audio.Channels)
	fill_global_pole( &cfg.Audio, fs )
	if e := fill_PCB_configurations( cfg.Audio.PCB ); e!=nil { return e }

	rsum := eng2float(cfg.Audio.Rsum)
	if rsum==0 { rsum = rtotal }
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
		ch_res := eng2float(ch.Rsum)
		if cfg.Audio.Rsum_feedback_res {
			ch.gain=rsum/ch_res
		} else {
			rother := rtotal-ch_res
			rgnd := rsum
			if rother!=0 {
				var e error
				rgnd, e = parallel_res(rsum,rother)
				if e!=nil { return e }
			}
			ch.gain=resistor_div(rgnd,ch_res)
		}
		if ch.Pre != "" { ch.gain *= eng2float(ch.Pre) }
		if ch.Vpp != "" { ch.gain *= eng2float(ch.Vpp) }
	}
	if e := normalize_channels( cfg.Audio.Channels, cfg.Audio.Gain ); e!=nil {return e}
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
	cfg.Audio.Stereo = macros.IsSet("JTFRAME_STEREO")
	return nil
}

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
	fname, e := common.FindFileInFolders( ch.Fir,
		[]string{
			common.ConfigFilePath(core, ""),
			filepath.Join(os.Getenv("JTFRAME"),"hdl","sound"),
		})
	common.Must(e)
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
	fmhz := macros.GetInt("JTFRAME_MCLK")
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

func fill_PCB_configurations( pcbs []AudioPCB ) (e error) {
	for k, _ := range pcbs {
		e = pcbs[k].derive_gains()
		if e != nil {
			return e
		}
	}
	return nil
}

func (pcb *AudioPCB)derive_gains() error {
	const global=1.0
	gains, e := pcb.extract_gains(); if e!=nil { return e }
	e = normalize_gains(gains,global); if e!=nil { return e }
	return pcb.make_gaincfg(gains)
}

func (pcb *AudioPCB)extract_gains() ([]float64,error) {
	gains,e := pcb.calc_opamp_gain()
	if e!=nil { return nil,e }
	pcb.apply_preamp(gains)
	return gains,nil
}

func (pcb *AudioPCB)calc_opamp_gain() ([]float64,error) {
	gains:=make([]float64,len(pcb.Rsums))
	rfb := eng2float(pcb.Rfb)
	for k, summing_res := range pcb.Rsums {
		rsum := eng2float(summing_res)
		if rsum==0 { return nil,fmt.Errorf("zero is not a valid value for rsum") }
		gains[k] = rfb/rsum
	}
	return gains,nil
}

func (pcb *AudioPCB)apply_preamp(gains []float64) {
	for k,preamp_gain := range pcb.Pres {
		gains[k] *= preamp_gain
	}
}

func (pcb *AudioPCB)make_gaincfg(all_gains []float64) (e error) {
	asint := make([]int,len(all_gains))
	for k, gain := range all_gains {
		if k>5 { return fmt.Errorf("Too many channels in Audio.PCB") }
		asint[k], e = float2gain(gain)
		if e!=nil { return fmt.Errorf("%w for gain=%.2f, (Rfb=%s)",e,gain,pcb.Rfb) }
	}
	gainstr := ""
	for k,gain := range asint {
		hex := fmt.Sprintf("%02X",gain)
		if k>0 { gainstr = "_"+gainstr }
		gainstr = hex+gainstr
	}
	pcb.Gaincfg="48'h"+gainstr
	return nil
}

func parallel_res(rr ...float64) (req float64, e error) {
	for _,res := range rr {
		if res==0 { return 0,fmt.Errorf("0 is not a valid resistor value")}
		req += 1.0/res
	}
	return 1.0/req,nil
}

func resistor_div(rgnd, rin float64) float64 {
	rtotal := rgnd+rin
	return rgnd/rtotal
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

func find_rlimits( all_channels []AudioCh ) (rmin, rmax, rtotal float64) {
	for _,ch := range all_channels {
		rsum := eng2float(ch.Rsum)
		if (rsum>0 && rsum < rmin) || rmin==0 { rmin=rsum }
		if rsum>0 && rsum > rmax { rmax=rsum }
		rtotal+=rsum
	}
	return rmin,rmax,rtotal
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

func normalize_channels( all_channels []AudioCh, global float64 ) error {
	if global==0 {
		global=1.0
	}
	all_gains := extract_gains(all_channels)
	normalize_gains(all_gains,global)
	for k,_ := range all_gains {
		ch := &all_channels[k]
		ch.gain = all_gains[k]
		intg, e := float2gain(ch.gain); if e!=nil { return e }
		ch.Gain = fmt.Sprintf("8'h%02X",intg)
		if Verbose {
			fmt.Printf("channel %d, gain %X\n",k,ch.Gain)
		}
	}
	return nil
}

func extract_gains(all_channels []AudioCh) (gains []float64) {
	gains=make([]float64,len(all_channels))
	for k,_ := range all_channels {
		gains[k]=all_channels[k].gain
	}
	return gains
}

func normalize_gains(all_gains []float64, global_gain float64) (e error) {
	var gmax float64
	for _,gain := range all_gains {
		if gmax==0 || gain>gmax {
			gmax=gain
		}
	}
	for k,_ := range all_gains {
		all_gains[k] = all_gains[k]/gmax*global_gain
	}
	return nil
}

func float2gain(gain float64) (int,error) {
	const FRAC_BITS=7 // must match jtframe_sndchain.WD
	const INTEGER=1<<FRAC_BITS
	intg := int(gain*INTEGER)
	if (intg&^0xff)!=0 {
		return 0,fmt.Errorf("Error: cannot fit audio gain in 8 bits\n")
	}
	return intg,nil
}

func Gain2dec(hex string) string {
	if len(hex)<4 || len(hex)>5 {
		panic(fmt.Sprintf("Bad format: %s",hex))
	}
	hex=hex[3:]
	integer, e := strconv.ParseInt(hex,16,64)
	if e!=nil { panic(e) }
	asfloat := float64(integer)/128.0
	return fmt.Sprintf("%.2f",asfloat)
}
