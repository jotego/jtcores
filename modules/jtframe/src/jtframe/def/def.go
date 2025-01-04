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
    . "github.com/jotego/jtframe/common"
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

func parse_def(path string, target string) {
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
	release := Macros.IsSet("JTFRAME_RELEASE")
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
			parse_def(inc, target)
			continue
		}
		// lines starting with debug are not parsed for release builds
		if words[0] == "debug" {
			if release { continue }
			line=line[5:] // remove the debug word from the line
		}
		// lines starting with release are only parsed for release builds
		if words[0] == "release" {
			if !release { continue }
			line=line[7:] // remove the release word from the line
		}
		words = strings.SplitN(line, "=", 2)
		key := strings.ToUpper(strings.TrimSpace(words[0]))
		// Removes key
		if key[0] == '-' {
			key = key[1:]
			Macros.delete(key)
			continue
		}
		// macro set without content
		if len(words) ==1 {
			Macros.Set(key,"1")
			continue
		}
		val := strings.TrimSpace(words[1])
		// += will concatenate string values or add up integer values
		if len(key) > 2 && key[len(key)-1] == '+' {
			key = key[0 : len(key)-1]
			if Macros.IsSet(key) {
				old := Macros.Get(key)
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
		Macros.Set(key,val)
	}
	return
}

// check incompatible macro settings
func CheckMacros() error {
	// Check that MiST DIPs are defined after the
	// last used status bit
	dipbase, _ := strconv.Atoi(Macros.Get("JTFRAME_DIPBASE"))
	if target_uses_dipbase(Macros.Get("TARGET")) {
		if Macros.IsSet("JTFRAME_AUTOFIRE0") && dipbase < 17 {
			return fmt.Errorf("MiST DIP base is smaller than the required value by JTFRAME_AUTOFIRE0")
		}
		if Macros.IsSet("JTFRAME_OSD_SND_EN") && dipbase < 10 {
			return fmt.Errorf("MiST DIP base is smaller than the required value by JTFRAME_OSD_SND_EN")
		}
		if Macros.IsSet("JTFRAME_OSD_TEST") && dipbase < 11 {
			return fmt.Errorf("MiST DIP base is smaller than the required value by JTFRAME_OSD_TEST")
		}
	}
	if Macros.IsSet("JTFRAME_LF_BUFFER") && Macros.IsSet("JTFRAME_MR_DDRLOAD") {
		return fmt.Errorf("jtframe: cannot define both JTFRAME_LF_BUFFER and JTFRAME_MR_DDRLOAD")
	}
	// sim macros
	maxframe_str   := Macros.Get("MAXFRAME")
	dumpstart_str  := Macros.Get("DUMP_START")
	maxframe, _ := strconv.Atoi(maxframe_str)
	dumpstart,_ := strconv.Atoi(dumpstart_str)
	if dumpstart > maxframe {
		return fmt.Errorf("Set a frame start for dumping within the simulation range")
	}
	if Macros.IsSet("JTFRAME_HEADER") && !Macros.IsInt("JTFRAME_HEADER") {
		header := Macros.Get("JTFRAME_HEADER")
		return fmt.Errorf("Cannot parse JTFRAME_HEADER=%s\n", header )
	}
	if !Macros.IsInt("JTFRAME_WIDTH")  { return fmt.Errorf("JTFRAME_WIDTH must be an integer"  ) }
	if !Macros.IsInt("JTFRAME_HEIGHT") { return fmt.Errorf("JTFRAME_HEIGHT must be an integer" ) }
	return nil
}

func target_uses_dipbase( target string ) bool {
	switch( target ) {
	case "mist","sidi","neptuno","mc2","mcp": return true
	default: return false
	}
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

func str2macro( a string ) string {
	re := regexp.MustCompile("^[0-9]")
	if re.MatchString(a) {
		a = "_" + a
	}
	return strings.ToUpper(a)
}

// Mostly meant to be used for unit tests
func MakeFromMap(ref map[string]string) {
	Macros.macros = make(map[string]string)
	for key,val := range ref {
		Macros.macros[key]=val
	}
}

func MakeMacros(cfg Config) {
	Macros.macros = make(map[string]string)
	read_target_macros(cfg.Target)
	add_explicit(cfg.Add)
	parse_def(DefPath(cfg), cfg.Target)
	mem_managed := is_mem_managed(cfg.Core)
	set_separator(cfg.Target)
	// Adds a macro with the target name
	Macros.Set(cfg.Target,"1")
	Macros.Set("JTFRAME_COMMIT",fmt.Sprintf("32'h%s",make_commit_macro(cfg.Commit)))
	// Adds the CORENAME if missing. This macro is expected to exist in macros.def
	if !Macros.IsSet("CORENAME") {
		fmt.Fprintf(os.Stderr, "CORENAME not specified in cfg/macros.def. Defaults to %s\n", cfg.Core)
	}
	// Memory templates require JTFRAME_MEMGEN
	if mem_managed {
		Macros.Set("JTFRAME_MEMGEN","")
	}
	// Macros with default values
	year, month, day := time.Now().Date()
	defaul_values := map[string]string{
		str2macro(cfg.Core): "",				// the core is always set
		"JTFRAME_180SHIFT":	     "0",
		"JTFRAME_ARX":           "4",
		"JTFRAME_ARY":           "3",
		"JTFRAME_BUTTONS":       "2",
		"JTFRAME_COLORW":        "4",
		"JTFRAME_CREDITS_PAGES": "3",
		"JTFRAME_DEBUG_VPOS":    "4",
		"JTFRAME_DIALEMU_LEFT":  "5",
		"JTFRAME_DIPBASE":      "16",
		"JTFRAME_SHIFT":	     "0",
		"JTFRAME_SIGNED_SND":    "1",
		"JTFRAME_TIMESTAMP":fmt.Sprintf("%d", time.Now().Unix()),
		"CORENAME": cfg.Core,
		"DATE": fmt.Sprintf("%d%02d%02d", year%100, month, day),
		"COMMIT": cfg.Commit,
		"TARGET": cfg.Target,
	}
	for key,val := range defaul_values {
		if !Macros.IsSet(key) {
			Macros.Set(key, val)
		}
	}
	make_gametop_macro()
	// for JTFRAME_VERTICAL define MISTER_FB
	if Macros.IsSet("JTFRAME_VERTICAL") {
		Macros.Set("MISTER_FB","")
	}
	prepare_input_record()
	clean_osd_macro()
	check_colorw()
	Macros.delete(cfg.Discard...)
	mclk := make_clocks(cfg.Target)
	add_subcarrier_clk( int64(mclk) )
	make_beta_macros(cfg.Core, cfg.Target)
}

func read_target_macros( target string ) {
	fname := filepath.Join(os.Getenv("JTFRAME"), "target", target, "target.def")
	if FileExists(fname) {
		parse_def(fname, target)
	}
}

func add_explicit( key_val []string ) {
	for _, def := range key_val {
		split := strings.SplitN(def, "=", 2)
		if len(split) == 2 {
			Macros.Set(split[0],split[1])
		} else {
			Macros.Set(split[0],"1")
		}
	}
}

func is_mem_managed(corename string) bool {
	f, e := os.Open( filepath.Join(os.Getenv("CORES"), corename,"cfg","mem.yaml"))
	f.Close()
	return e==nil
}

func set_separator(target string) {
	var separator string
	switch target {
	case "mist", "sidi", "neptuno": separator=""
	case "mister", "sockit","de1soc","de10std","sidi128":
		separator = "-;"
	}
	Macros.Set("SEPARATOR",separator)
}

func make_commit_macro(commit string) (macro string) {
	if len(commit)<7 { return "0" }
	short:=commit[0:7]
	_,is_number := strconv.ParseInt(short,16,64)
	if is_number!=nil { return "0" }
	return short
}

// Derives the GAMETOP module from the CORENAME if unspecified
func make_gametop_macro() {
	if !Macros.IsSet("GAMETOP") {
		gametop := Macros.Get("CORENAME")
		if !Macros.IsSet("JTFRAME_MEMGEN") {
			gametop = gametop+"_game"
		} else {
			gametop = gametop+"_game_sdram"
		}
		gametop = strings.ToLower(gametop)
		Macros.Set("GAMETOP", gametop )
	}
}

// If JTFRAME_INPUT_RECORD exists, set the right NVRAM length
func prepare_input_record() {
	if Macros.IsSet("JTFRAME_INPUT_RECORD") {
		const JTFRAME_INPUT_RECORD_AW=12 // 4kB of recording, up to 2048 key strokes
		Macros.Set("JTFRAME_IOCTL_RD", fmt.Sprintf("%d",1<<JTFRAME_INPUT_RECORD_AW))
		Macros.Set("JTFRAME_INPUT_RECORD_AW", fmt.Sprintf("%d",JTFRAME_INPUT_RECORD_AW))
		if Macros.IsSet("JTFRAME_SHADOW") {
			fmt.Println("Macro JTFRAME_SHADOW deleted as JTFRAME_INPUT_RECORD is defined")
			Macros.delete("JTFRAME_SHADOW")
		}
	}
}

func make_clocks(target string) (mclk int) {
	// JTFRAME_PLL is defined as the PLL name
	// in the .def file. This will define that
	// name as a macro on its own too
	mclk = 48000000
	if pll, f := Macros.macros["JTFRAME_PLL"]; f {
		var freq int
		pll=strings.ToUpper(pll)
		switch(pll) {
		case "JTFRAME_PLL6144": switch(target) {
			case "MISTER": freq=6143465
			default:       freq=6144230
		}
		case "JTFRAME_PLL6293": switch(target) {
			case "MISTER": freq=6293402 // ideally 6.293700
			default:       freq=6289772
		}
		case "JTFRAME_PLL6671": switch(target) {
			case "MISTER": freq=6670673
			default:       freq=6673954
		}
		default: {
				Macros.Set(pll, "")
				freq_str := regexp.MustCompile("[0-9]+$").FindString(pll)
				if freq_str == "" {
					log.Fatal("JTFRAME: macro JTFRAME_PLL=", pll, " is not well formed. It should contain the pixel clock in kHz")
				}
				freq, _ = strconv.Atoi(freq_str)
			}
		}
		mclk = freq*8
		Macros.Set(pll,"")	// define a macro with the PLL name
	} else {
		Macros.Set("JTFRAME_PLL6000","")
	}
	if Macros.IsSet("JTFRAME_CLK96") || Macros.IsSet("JTFRAME_SDRAM96") {
		mclk *= 2
	}
	Macros.Set("JTFRAME_MCLK", fmt.Sprintf("%d",mclk))
	return mclk
}

// prevent the CORE_OSD from having two ;; in a row or starting with ;
func clean_osd_macro() {
	core_osd := Macros.Get("CORE_OSD")
	if len(core_osd) > 0 {
		if core_osd[0] == ';' {
			core_osd = core_osd[1:]
		}
		core_osd = strings.ReplaceAll(core_osd, ";;", ";")
		if core_osd[len(core_osd)-1] != ';' {
			core_osd = core_osd + ";"
		}
	} else {
		core_osd = ""
	}
	Macros.Set("CORE_OSD", core_osd)
}

func check_colorw() {
	// Do not accept less than 4bpp
	colorw,_ := strconv.Atoi(Macros.Get("JTFRAME_COLORW"))
	if colorw<4 || colorw>8 {
		log.Fatal("JTFRAME: macro JTFRAME_COLORW must be between 4 and 8")
	}
}

func add_subcarrier_clk( mclk int64 ) {
	var pal, ntsc int64
	ntsc=((315<<32)/88)*1000000/mclk
	pal=(443361875<<32)/100/mclk
	Macros.Set("JTFRAME_PAL",  fmt.Sprintf("%d",pal))
	Macros.Set("JTFRAME_NTSC", fmt.Sprintf("%d",ntsc))
	// burst length -- ntsc
	calc_len := func( subcarrier float64 ) int64 {
		ratio := float64(mclk)/subcarrier
		start := int64(3.7 * ratio)
		end   := int64((9.0+3.7) * ratio)
		return (start << 10) | end
	}
	Macros.Set("JTFRAME_NTSC_LEN", fmt.Sprintf("%d",calc_len(315000000/88.0)))
	Macros.Set("JTFRAME_PAL_LEN",  fmt.Sprintf("%d",calc_len(4433618.75)))
}

func make_beta_macros( core, target string ) {
	if betas.IsBetaFor( core, target) {
		Macros.Set("JTFRAME_UNLOCKKEY", fmt.Sprintf("%d",betas.Betakey))
		Macros.Set("BETA", "")
	}
}


// func Get_Macros( core, target string ) (map[string]string) {
// 	var def_cfg Config
// 	def_cfg.Target = target
// 	def_cfg.Core = core
// 	// def_cfg.Add = cfgstr.Append_args(def_cfg.Add, strings.Split(args.AddMacro, ","))
// 	return Make_macros(def_cfg)
// }

func init() {
	Macros.macros = make(map[string]string)
}