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

func parse_def(path string, cfg Config, macros *map[string]string) {
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
	section := "all"
	linecnt := 0

	for scanner.Scan() {
		linecnt++
		line := strings.TrimSpace(scanner.Text())
		if len(line) == 0 || line[0] == '#' {
			continue
		}
		if line[0] == '[' {
			idx := strings.Index(line, "]")
			if idx == -1 {
				fmt.Println("Malformed expression at line ", linecnt, " of file ", path)
				log.Fatal("Bad def file")
			}
			sections := strings.Split(strings.TrimSpace(line[1:idx]), "|")
			for _, s := range sections {
				section = strings.TrimSpace(s)
				var m bool
				var e error
				if m,e = filepath.Match(section,cfg.Target); m {
					section = cfg.Target
					break
				}
				if e!=nil {
					fmt.Printf("Malformed expression in .def file: %s\n", section)
					os.Exit(1)
				}
			}
			continue
		}
		if section == "all" || section == cfg.Target {
			// Look for keywords
			words := strings.SplitN(line, " ", 2)
			if words[0] == "include" {
				// Include files are relative to the calling file,
				// unless they start with /
				slash := strings.LastIndex(path, "/")
				inc := words[1]
				if slash != -1 && inc[0] != '/' {
					inc = path[0:slash+1] + inc
				}
				parse_def(inc, cfg, macros)
				continue
			}
			words = strings.SplitN(line, "=", 2)
			key := strings.ToUpper(strings.TrimSpace(words[0]))
			if key[0] == '-' {
				// Removes key
				key = key[1:]
				delete(*macros, key)
			} else {
				if len(words) > 1 {
					val := strings.TrimSpace(words[1])
					if len(key) > 2 && key[len(key)-1] == '+' {
						key = key[0 : len(key)-1]
						old, e := (*macros)[key]
						if e {
							val = old + val
						}
					}
					(*macros)[key] = val
				} else {
					(*macros)[key] = "1"
				}
			}
		}
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

func Make_macros(cfg Config) (macros map[string]string) {
	macros = make(map[string]string)
	parse_def(DefPath(cfg), cfg, &macros)
	f, e := os.Open( filepath.Join(os.Getenv("CORES"), cfg.Core,"cfg","mem.yaml") )
	f.Close()
	mem_managed := e == nil // Using RTL generation for the memory
	switch cfg.Target {
	case "mist", "sidi", "neptuno":
		macros["SEPARATOR"] = ""
	case "mister", "sockit","de1soc","de10std":
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
	// Memory templates require JTFRAME_SDRAM_BANKS and JTFRAME_MEMGEN
	if mem_managed {
		_, exists = macros["JTFRAME_SDRAM_BANKS"]
		if !exists && mem_managed {
			macros["JTFRAME_SDRAM_BANKS"] = ""
		}
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
	mclk := 48000
	if pll, e := macros["JTFRAME_PLL"]; e {
		macros[strings.ToUpper(pll)] = ""
		freq_str := regexp.MustCompile("[0-9]+$").FindString(pll)
		if freq_str == "" {
			log.Fatal("JTFRAME: macro JTFRAME_PLL=", pll, " is not well formed. It should contain the pixel clock in kHz")
		}
		freq, _ := strconv.Atoi(freq_str)
		mclk = freq*8
	}
	if Defined(macros,"JTFRAME_SDRAM96") || Defined(macros,"JTFRAME_CLK96") {
		mclk *= 2
	}
	macros["JTFRAME_MCLK"] = fmt.Sprintf("%d",mclk)
	// Set beta macros
	if betas.IsBetaFor(cfg.Core, cfg.Target) {
		macros["JTFRAME_UNLOCKKEY"] = fmt.Sprintf("%d",betas.Betakey)
		macros["BETA"]= ""
	}
	return macros
}

// Replaces all the macros (marked with a $) in the file
func Replace_Macros(path string, macros map[string]string) string {
	if len(path) == 0 {
		return ""
	}
	file, err := os.Open(path)
	if err != nil {
		log.Fatal("Cannot open " + path)
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)

	var builder strings.Builder

	for scanner.Scan() {
		s := scanner.Text()
		for k, v := range macros {
			s = strings.ReplaceAll(s, "$"+k, v)
		}
		builder.WriteString(s)
		builder.WriteString("\n")
	}
	return builder.String()
}
