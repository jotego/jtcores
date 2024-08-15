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
    Version: 1.0
    Date: 7-7-2022 */

package def

import (
	"bufio"
	"errors"
	"fmt"
	"log"
	"os"
	"path"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"

    "github.com/jotego/jtframe/betas"
)

type Config struct {
	Target,
	Deffile,
	Template,
	Output,
	Core,
	Commit string
	Add     []string // new definitions in command line
	Discard []string // definitions to be discarded
	Verbose bool
}

// returns true if the .def file section changes
// each section is marked with [target-name]
// multiple valid targets can be listed separated with | as in [sidi|mister]
// Glob (use of * and ?) matching will select the current target
func extract_section( line string, target string, section *string ) (bool,error) {
	if line[0] != '[' { return false, nil }
	idx := strings.Index(line, "]")
	if idx == -1 { return false, errors.New("Unclosed bracket. Expecting ]") }
	sections := strings.Split(strings.TrimSpace(line[1:idx]), "|")
	for _, name := range sections {
		*section = strings.TrimSpace(name)
		found, e := filepath.Match(*section,target)
		if found {
			*section = target
			return true, nil
		}
		if e!=nil { return false, e }
	}
	return true, nil
}

func parse_def(path string, target string, macros map[string]string) {
	if path == "" {
		return
	}
	f, err := os.Open(path)
	if err != nil {
		log.Fatal("Cannot open " + path)
	}
	defer f.Close()
	scanner := bufio.NewScanner(f)
	scanner.Split(bufio.ScanLines)
	section := target
	linecnt := 0

	for scanner.Scan() {
		linecnt++
		line := strings.TrimSpace(scanner.Text())
		if len(line) == 0 || line[0] == '#' { continue }

		// parse new sections
		change, e := extract_section(line, target, &section)
		if change { continue }
		if e!=nil {
			fmt.Println("Malformed expression at line ", linecnt, " of file ", path)
			fmt.Println(e)
			os.Exit(1)
		}
		if section != target { continue }

		// Look for keywords
		words := strings.SplitN(line, " ", 2)
		words[0] = strings.ToLower(words[0])
		if words[0] == "include" {
			// Include files are relative to the calling file,
			// unless they start with /
			slash := strings.LastIndex(path, "/")
			inc := words[1]
			if slash != -1 && inc[0] != '/' {
				inc = path[0:slash+1] + inc
			}
			parse_def(inc, target, macros)
			continue
		}
		// lines starting with debug are not parsed for release builds
		if words[0] == "debug" {
			if _, fnd := macros["JTFRAME_RELEASE"]; fnd { continue }
			line=line[5:] // remove the debug word from the line
		}
		words = strings.SplitN(line, "=", 2)
		key := strings.ToUpper(strings.TrimSpace(words[0]))
		// Removes key
		if key[0] == '-' {
			key = key[1:]
			delete(macros, key)
			continue
		}
		// macro set without content
		if len(words) ==1 {
			macros[key] = "1"
			continue
		}
		val := strings.TrimSpace(words[1])
		// += will concatenate string values or add up integer values
		if len(key) > 2 && key[len(key)-1] == '+' {
			key = key[0 : len(key)-1]
			old, found := macros[key]
			if found {
				oldint, err1 := strconv.ParseInt(old,0,64)
				newint, err2 := strconv.ParseInt(val,0,64)
				if err1==nil && err2==nil {
					// integer addition
					val=fmt.Sprintf("%d",oldint+newint)
				} else {
					// string concatenation
					val = old + val
				}
			}
		}
		macros[key] = val
	}
	return
}

func target_uses_dipbase( target string ) bool {
	switch( target ) {
	case "mist","sidi","neptuno","mc2","mcp": return true
	default: return false
	}
}

// check incompatible macro settings
func Check_macros(def map[string]string, target string) bool {
	// Check that MiST DIPs are defined after the
	// last used status bit
	dipbase, _ := strconv.Atoi(def["JTFRAME_DIPBASE"])
	if def["JTFRAME_DIPBASE"] == "" {
		dipbase = 16
	}
	_, autofire0  := def["JTFRAME_AUTOFIRE0"]
	_, osd_snd_en := def["JTFRAME_OSD_SND_EN"]
	_, osd_test   := def["JTFRAME_OSD_TEST"]
	_, lf_buffer  := def["JTFRAME_LF_BUFFER"]
	_, mr_ddrload := def["JTFRAME_MR_DDRLOAD"]
	if target_uses_dipbase(target) {
		if autofire0 && dipbase < 17 {
			log.Fatal("MiST DIP base is smaller than the required value by JTFRAME_AUTOFIRE0")
			return false
		}
		if osd_snd_en && dipbase < 10 {
			log.Fatal("MiST DIP base is smaller than the required value by JTFRAME_OSD_SND_EN")
			return false
		}
		if osd_test && dipbase < 11 {
			log.Fatal("MiST DIP base is smaller than the required value by JTFRAME_OSD_TEST")
			return false
		}
	}
	if lf_buffer && mr_ddrload {
		log.Fatal("jtframe: cannot define both JTFRAME_LF_BUFFER and JTFRAME_MR_DDRLOAD")
		return false
	}
	// sim macros
	maxframe_str,_  := def["MAXFRAME"]
	dumpstart_str,_ := def["DUMP_START"]
	maxframe, _ := strconv.Atoi(maxframe_str)
	dumpstart,_ := strconv.Atoi(dumpstart_str)
	if dumpstart > maxframe {
		log.Fatal("Set a frame start for dumping within the simulation range")
		return false
	}
	return true
}

func DefPath(cfg Config) string {
	jtroot := os.Getenv("JTROOT")
	if cfg.Core != "" && jtroot != "" {
		path := path.Join(jtroot, "cores", cfg.Core, "cfg", "macros.def")
		return path
	} else {
		return cfg.Deffile
	}
}

func Defined( macros map[string]string, key string ) bool {
	_ ,e := macros[key]
	return e
}

func str2macro( a string ) string {
	re := regexp.MustCompile("^[0-9]")
	if re.MatchString(a) {
		a = "_" + a
	}
	return strings.ToUpper(a)
}

func parse_target( target string, macros map[string]string) {
	fname := filepath.Join(os.Getenv("JTFRAME"), "target", target, "target.def")
	f, e := os.Open(fname)
	f.Close()
	if e==nil {
		parse_def(fname, target, macros)
	}
}

func Make_macros(cfg Config) (macros map[string]string) {
	macros = make(map[string]string)
	parse_target(cfg.Target, macros)
	parse_def(DefPath(cfg), cfg.Target, macros)
	f, e := os.Open( filepath.Join(os.Getenv("CORES"), cfg.Core,"cfg","mem.yaml"))
	f.Close()
	mem_managed := e == nil // Using RTL generation for the memory
	switch cfg.Target {
	case "mist", "sidi", "neptuno":
		macros["SEPARATOR"] = ""
	case "mister", "sockit","de1soc","de10std","sidi128":
		macros["SEPARATOR"] = "-;"
	}
	// Adds a macro with the target name
	macros[ strings.ToUpper(cfg.Target) ] = "1"
	if cfg.Commit!="" {
		// fmt.Fprintln( os.Stderr, "jtframe cfgstr: using commit ", cfg.Commit)
		if len(cfg.Commit)>=7 {
			macros["JTFRAME_COMMIT"] = fmt.Sprintf("32'h%s",cfg.Commit[0:7]) // the "dirty" text is dropped
		} else {
			macros["JTFRAME_COMMIT"] = "32'h0"
		}
	}
	// Adds the CORENAME if missing. This macro is expected to exist in macros.def
	_, exists := macros["CORENAME"]
	if ! exists {
		fmt.Fprintf(os.Stderr, "CORENAME not specified in cfg/macros.def. Defaults to %s\n", cfg.Core)
	}
	// Memory templates require JTFRAME_MEMGEN
	if mem_managed {
		macros["JTFRAME_MEMGEN"] = ""
	}
	// Macros with default values
	year, month, day := time.Now().Date()
	defaul_values := map[string]string{
		str2macro(cfg.Core): "",				// the core is always set
		"JTFRAME_ARX":           "4",
		"JTFRAME_ARY":           "3",
		"JTFRAME_COLORW":        "4",
		"JTFRAME_BUTTONS":       "2",
		"JTFRAME_SIGNED_SND":    "1",
		"JTFRAME_DIPBASE":      "16",
		"JTFRAME_CREDITS_PAGES": "3",
		"JTFRAME_DIALEMU_LEFT":  "5",
		"JTFRAME_SHIFT":	     "0",
		"JTFRAME_180SHIFT":	     "0",
		"JTFRAME_TIMESTAMP":fmt.Sprintf("%d", time.Now().Unix()),
		"CORENAME": cfg.Core,
		"DATE": fmt.Sprintf("%d%02d%02d", year%100, month, day),
		"COMMIT": cfg.Commit,
		"TARGET": cfg.Target,
	}
	for k,v := range defaul_values {
		_, exists = macros[k]
		if !exists {
			macros[k] = v
		}
	}
	// Derives the GAMETOP module from the CORENAME if unspecified
	_, exists = macros["GAMETOP"]
	if ! exists {
		if !mem_managed {
			macros["GAMETOP"] = strings.ToLower(macros["CORENAME"]+"_game")
		} else {
			macros["GAMETOP"] = strings.ToLower(macros["CORENAME"]+"_game_sdram")
		}
	}
	// If JTFRAME_INPUT_RECORD exists, set the right NVRAM length
	if _, f := macros["JTFRAME_INPUT_RECORD"]; f {
		const JTFRAME_INPUT_RECORD_AW=12 // 4kB of recording, up to 2048 key strokes
		macros["JTFRAME_IOCTL_RD"] = fmt.Sprintf("%d",1<<JTFRAME_INPUT_RECORD_AW);
		macros["JTFRAME_INPUT_RECORD_AW"] = fmt.Sprintf("%d",JTFRAME_INPUT_RECORD_AW);
		if _, f := macros["JTFRAME_SHADOW"]; f {
			fmt.Println("Macro JTFRAME_SHADOW deleted as JTFRAME_INPUT_RECORD is defined")
			delete(macros,"JTFRAME_SHADOW")
		}
	}
	// prevent the CORE_OSD from having two ;; in a row or starting with ;
	core_osd := macros["CORE_OSD"]
	if len(core_osd) > 0 {
		if core_osd[0] == ';' {
			core_osd = core_osd[1:]
		}
		core_osd = strings.ReplaceAll(core_osd, ";;", ";")
		if core_osd[len(core_osd)-1] != ';' {
			core_osd = core_osd + ";"
		}
		macros["CORE_OSD"] = core_osd
	} else {
		macros["CORE_OSD"] = ""
	}
	// Do not accept less than 4bpp
	colorw,_ := strconv.Atoi(macros["JTFRAME_COLORW"])
	if colorw<4 || colorw>8 {
		log.Fatal("JTFRAME: macro JTFRAME_COLORW must be between 4 and 8")
	}
	// Delete macros listed in cfg.discard
	for _, undef := range cfg.Discard {
		delete(macros, undef)
	}
	// Add macros in cfg.add
	for _, def := range cfg.Add {
		split := strings.SplitN(def, "=", 2)
		if len(split) == 2 {
			macros[split[0]] = split[1]
		} else {
			macros[split[0]] = "1"
		}
	}
	// JTFRAME_PLL is defined as the PLL name
	// in the .def file. This will define that
	// name as a macro on its own too
	mclk := 48000000
	if pll, f := macros["JTFRAME_PLL"]; f {
		var freq int
		pll=strings.ToUpper(pll)
		switch(pll) {
		case "JTFRAME_PLL6144": switch(cfg.Target) {
			case "MISTER": freq=6143465
			default:       freq=6144230
		}
		case "JTFRAME_PLL6293": switch(cfg.Target) {
			case "MISTER": freq=6293402 // ideally 6.293700
			default:       freq=6289772
		}
		case "JTFRAME_PLL6671": switch(cfg.Target) {
			case "MISTER": freq=6670673
			default:       freq=6673954
		}
		default: {
				macros[pll] = ""
				freq_str := regexp.MustCompile("[0-9]+$").FindString(pll)
				if freq_str == "" {
					log.Fatal("JTFRAME: macro JTFRAME_PLL=", pll, " is not well formed. It should contain the pixel clock in kHz")
				}
				freq, _ = strconv.Atoi(freq_str)
			}
		}
		mclk = freq*8
	}
	if Defined(macros,"JTFRAME_CLK96") || Defined(macros,"JTFRAME_SDRAM96") {
		mclk *= 2
	}
	macros["JTFRAME_MCLK"] = fmt.Sprintf("%d",mclk)
	add_subcarrier_clk( macros, int64(mclk) )
	// Set beta macros
	if betas.IsBetaFor(cfg.Core, cfg.Target) {
		macros["JTFRAME_UNLOCKKEY"] = fmt.Sprintf("%d",betas.Betakey)
		macros["BETA"]= ""
	}
	return macros
}

func add_subcarrier_clk( macros map[string]string, mclk int64 ) {
	var pal, ntsc int64
	ntsc=((315<<32)/88)*1000000/mclk
	pal=(443361875<<32)/100/mclk
	macros["JTFRAME_PAL"] =fmt.Sprintf("%d",pal)
	macros["JTFRAME_NTSC"]=fmt.Sprintf("%d",ntsc)
	// burst length -- ntsc
	calc_len := func( subcarrier float64 ) int64 {
		ratio := float64(mclk)/subcarrier
		start := int64(3.7 * ratio)
		end   := int64((9.0+3.7) * ratio)
		return (start << 10) | end
	}
	macros["JTFRAME_NTSC_LEN"]=fmt.Sprintf("%d",calc_len(315000000/88.0))
	macros["JTFRAME_PAL_LEN" ]=fmt.Sprintf("%d",calc_len(4433618.75))
}

// Replaces all the macros (marked with a $) in the file
// func Replace_Macros(path string, macros map[string]string) string {
// 	if len(path) == 0 {
// 		return ""
// 	}
// 	file, err := os.Open(path)
// 	if err != nil {
// 		log.Fatal("Cannot open " + path)
// 	}
// 	defer file.Close()

// 	scanner := bufio.NewScanner(file)

// 	var builder strings.Builder

// 	for scanner.Scan() {
// 		s := scanner.Text()
// 		for k, v := range macros {
// 			s = strings.ReplaceAll(s, "$"+k, v)
// 		}
// 		builder.WriteString(s)
// 		builder.WriteString("\n")
// 	}
// 	return builder.String()
// }

func Get_Macros( core, target string ) (map[string]string) {
	var def_cfg Config
	def_cfg.Target = target
	def_cfg.Core = core
	// def_cfg.Add = cfgstr.Append_args(def_cfg.Add, strings.Split(args.AddMacro, ","))
	return Make_macros(def_cfg)
}
