/*  This file is part of JT_FRAME.
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
    Date: 28-8-2022 */

package jtfiles

import (
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/jotego/jtframe/def"
	"github.com/jotego/jtframe/cfgstr"
	"github.com/jotego/jtframe/ucode"
	"gopkg.in/yaml.v2"
)

type Origin int

const (
	GAME Origin = iota
	FRAME
	TARGET
	MODULE
	JTMODULE
)

type FileList struct {
	From   string   `yaml:"from"`
	Get    []string `yaml:"get"`
	Unless string   `yaml:"unless"` // parses the section "unless" the macro is defined
	When   string   `yaml:"when"`   // parses the section "when" the macro is defined
}

type JTModule struct {
	Name   string `yaml:"name"`
	Unless string `yaml:"unless"`
	When   string   `yaml:"when"`
}

type UcDesc struct {
	Src		string `yaml:"src"`
	Output  string `yaml:"output"`
	// private
	modname string
}
type UcFiles map[string]UcDesc // if this is changed to a non reference type, update the functions that take it as an argument

type JTFiles struct {
	Game    []FileList `yaml:"game"`
	JTFrame []FileList `yaml:"jtframe"`
	Target  []FileList `yaml:"target"`
	Modules struct {
		JT    []JTModule `yaml:"jt"`
		Other []FileList `yaml:"other"`
	} `yaml:"modules"`
	Here []string `yaml:"here"`
	Ucode UcFiles `yaml:"ucode"`
}

type Args struct {
	Corename string // JT core
	Parse    string // any file
	Rel      bool
	Local    bool
	Format   string
	Target   string
	AddMacro string // More macros, separated by commas
}

var parsed []string
var CWD string
var args Args
var macros map[string]string

func parse_args(args *Args) {
	flag.Usage = func() {
		fmt.Fprintf(flag.CommandLine.Output(), "%s, part of JTFRAME. (c) Jose Tejada 2021-2022.\nUsage:\n", os.Args[0])
		fmt.Fprint(flag.CommandLine.Output(),
			`    jtfiles look for three yaml files:
		- game.yaml, in the core folder
		- target.yaml, in $JTFRAME/target
		- sim.yaml, in $JTFRAME/target (when simulation output requested)

	 Each yaml file can call other files. The game.yaml file should avoid
	 files specific to a target. That's the only file that a JTFRAME user
	 should populate.
	 The files target.yaml and sim.yaml are part of JTFRAME and should not
	 be modified, except for adding support to new devices.

`)
		flag.PrintDefaults()
		os.Exit(0)
	}
	flag.StringVar(&args.Corename, "core", "", "core name")
	flag.StringVar(&args.Parse, "parse", "", "File to parse. Use either -parse or -core")
	flag.StringVar(&args.Format, "f", "qip", "Output format. Valid values: qip, sim")
	flag.StringVar(&args.Target, "target", "", "Target platform: mist, mister, pocket, etc.")
	flag.BoolVar(&args.Rel, "rel", false, "Output relative paths")
	flag.Parse()
	if len(args.Corename) == 0 && len(args.Parse) == 0 {
		log.Fatal("JTFILES: You must specify either the core name with argument -core\nor a file name with -parse")
	}
}

func GetFilename(corename, basename, parsepath string) string {
	var fname string
	if len(corename) > 0 {
		cores := os.Getenv("CORES")
		if len(cores) == 0 {
			log.Fatal("JTFILES: environment variable CORES is not defined")
		}
		fname = cores + "/" + corename + "/cfg/"+basename+".yaml"
	} else {
		fname = parsepath
	}
	return fname
}

func append_filelist(dest *[]FileList, src []FileList, other *[]string, origin Origin) {
	if src == nil {
		return
	}
	if dest == nil {
		*dest = make([]FileList, 0)
	}
	parse_section:
	for _, each := range src {
		// Parses the section unless the macro is defined
		if each.Unless != "" {
			for _,name := range( strings.Split(each.Unless,",")) {
				if _, exists := macros[name]; exists {
					continue parse_section
				}
			}
		}
		// Only parses the section when the macro is defined
		if each.When != "" {
			found := false
			for _,name := range( strings.Split(each.When,",")) {
				if _, exists := macros[name]; exists {
					found = true
					break
				}

			}
			if !found {
				continue parse_section
			}
		}

		var newfl FileList
		newfl.From = each.From
		newfl.Get = make([]string, 2)
		for _, each := range each.Get {
			each = strings.TrimSpace(each)
			if strings.HasSuffix(each, ".yaml") {
				var path string
				switch origin {
				case GAME:
					path = os.Getenv("CORES") + "/" + newfl.From + "/cfg/"
				case FRAME:
					path = os.Getenv("JTFRAME") + "/hdl/" + newfl.From + "/"
				case TARGET:
					path = os.Getenv("JTFRAME") + "/target/" + newfl.From + "/"
				default:
					path = os.Getenv("MODULES") + "/" + newfl.From + "/"
				}
				*other = append(*other, path+each)
			} else {
				newfl.Get = append(newfl.Get, each)
			}
		}
		if len(newfl.Get) > 0 {
			found := false
			for k, each := range *dest {
				if each.From == newfl.From {
					(*dest)[k].Get = append((*dest)[k].Get, newfl.Get...)
					found = true
					break
				}
			}
			if !found {
				*dest = append(*dest, newfl)
			}
		}
	}
}

func is_parsed(name string) bool {
	for _, k := range parsed {
		if name == k {
			return true
		}
	}
	return false
}

func parse_yaml(filename string, files *JTFiles) {
	buf, err := ioutil.ReadFile(filename)
	if err != nil {
		if parsed == nil {
			log.Printf("Warning: cannot open file %s. YAML processing still used for JTFRAME board.", filename)
			return
		} else {
			log.Fatalf("jtframe files: cannot open referenced file %s", filename)
		}
	}
	if parsed == nil {
		parsed = make([]string, 0)
	}
	parsed = append(parsed, filename)
	var aux JTFiles
	err_yaml := yaml.Unmarshal(buf, &aux)
	if err_yaml != nil {
		//fmt.Println(err_yaml)
		fmt.Printf("jtframe files: ERROR cannot parse file\n\t%s\n\t%v\n", filename, err_yaml)
		os.Exit(1)
	}
	other := make([]string, 0)
	// Parse
	append_filelist(&files.Game, aux.Game, &other, GAME)
	append_filelist(&files.JTFrame, aux.JTFrame, &other, FRAME)
	append_filelist(&files.Target, aux.Target, &other, TARGET)
	append_filelist(&files.Modules.Other, aux.Modules.Other, &other, MODULE)
	if files.Modules.JT == nil {
		files.Modules.JT = make([]JTModule, 0)
	}
	for _, each := range aux.Modules.JT {
		var fname string
		var f *os.File
		var err error
		for _, path := range []string{"hdl","cfg"} {
			fname = filepath.Join(os.Getenv("MODULES"), each.Name, path, each.Name+".yaml")
			f, err = os.Open(fname)
			if err == nil {
				break
			}
		}
		// Parse the YAML file if it exists
		if err == nil {
			f.Close()
			parse_yaml(fname, files)
		} else {
			files.Modules.JT = append(files.Modules.JT, each)
		}
	}
	for _, each := range other {
		if !is_parsed(each) {
			parse_yaml(each, files)
		}
	}
	// "here" files
	if files.Here == nil {
		files.Here = make([]string, 0)
	}
	dir := filepath.Dir(filename)
	for _, each := range aux.Here {
		fullpath := filepath.Join(dir, each)
		if strings.HasSuffix(each, ".yaml") && !is_parsed(each) {
			parse_yaml(fullpath, files)
		} else {
			files.Here = append(files.Here, fullpath)
		}
	}
	// ucode requirements
	for k,v := range aux.Ucode {
		if files.Ucode == nil { files.Ucode=make(UcFiles) }
		v.modname = k
		files.Ucode[k+"-"+v.Src+"-"+v.Output] = v
	}
}

// Make the path relative or absolute
func make_path(path, filename string, rel bool) (item string) {
	var err error
	if strings.Index(filename,path)==-1 && strings.Index(filename,"/")==-1 {
		fmt.Printf("%s -> %s\n",path,filename)
		filename = filepath.Join(path, filename)
	}
	if rel {
		item, err = filepath.Rel(CWD, filename)
	} else {
		item = filepath.Clean(filename)
	}
	if err != nil {
		log.Fatalf("JTFILES: Cannot parse path to %s\n", filename)
	}
	return item
}

func dump_filelist(fl []FileList, all *[]string, origin Origin, rel bool) {
	for _, each := range fl {
		var path string
		switch origin {
		case GAME:
			path = filepath.Join(os.Getenv("CORES"), each.From, "hdl")
		case FRAME:
			path = filepath.Join(os.Getenv("JTFRAME"), "hdl", each.From)
		case TARGET:
			path = filepath.Join(os.Getenv("JTFRAME"), "target", each.From)
		case MODULE:
			path = filepath.Join(os.Getenv("MODULES"), each.From)
		default:
			path = os.Getenv("JTROOT")
		}
		for _, each := range each.Get {
			if len(each) ==0 { continue }
			matches,e := filepath.Glob(filepath.Join(path,each))
			if e!=nil {
				fmt.Println(e)
				fmt.Printf("jtframe files: error parsing file list.")
				os.Exit(1)
			}
			if( len(matches)==0 ) {
				fmt.Printf("Warning: no matches for %s\n",each)
			}
			for _, m := range matches {
				*all = append(*all, make_path(path, m, rel))
			}
		}
	}
}

func dump_jtmodules(mods []JTModule, all *[]string, rel bool) {
	modpath := os.Getenv("MODULES")
	if mods == nil {
		return
	}
	for _, each := range mods {
		if len(each.Name) > 0 {
			lower := strings.ToLower(each.Name)
			lower = filepath.Join(lower, "hdl", lower+".yaml")

			*all = append(*all, make_path(modpath, lower, rel))
		}
	}
}

// Get file path names from JTFiles definition
func collect_files(files JTFiles, rel bool) []string {
	all := make([]string, 0)
	dump_filelist(files.Game, &all, GAME, rel)
	dump_filelist(files.JTFrame, &all, FRAME, rel)
	dump_filelist(files.Target, &all, TARGET, rel)
	dump_jtmodules(files.Modules.JT, &all, rel)
	dump_filelist(files.Modules.Other, &all, MODULE, rel)
	for _, each := range files.Here {
		if rel {
			each, _ = filepath.Rel(CWD, each)
		}
		all = append(all, each)
	}
	// Weed out the vhdl files
	vhdl    := make([]string,0,len(all))
	nonvhdl := make([]string,0,len(all))
	for _,each := range all {
		if strings.HasSuffix(each,".vhd") || strings.HasSuffix(each,".vhdl") {
			vhdl = append( vhdl, each )
		} else {
			nonvhdl = append( nonvhdl, each )
		}
	}
	// non-VHDL files are sorted
	sort.Strings(nonvhdl)
	if len(nonvhdl) > 0 {
		// Remove duplicated files
		uniq := make([]string, 0)
		for _, each := range nonvhdl {
			if len(uniq) == 0 || each != uniq[len(uniq)-1] {
				uniq = append(uniq, each)
			}
		}
		// Add all the VHDL files
		uniq = append(uniq, vhdl...)
		// Check that files exist
		for _, each := range uniq {
			if _, err := os.Stat(each); os.IsNotExist(err) {
				fmt.Println("JTFiles warning: file", each, "not found")
			}
		}
		return uniq
	} else {
		return all
	}
}

func dump_qip(all []string, args Args ) {
	fout, err := os.Create("game.qip")
	if err != nil {
		log.Fatal(err)
	}
	defer fout.Close()
	for _, each := range all {
		filetype := ""
		switch filepath.Ext(each) {
		case ".sv":
			filetype = "SYSTEMVERILOG_FILE"
		case ".vhd":
			filetype = "VHDL_FILE"
		case ".v":
			filetype = "VERILOG_FILE"
		case ".qip":
			filetype = "QIP_FILE"
		case ".sdc":
			filetype = "SDC_FILE"
		default:
			{
				log.Fatalf("JTFILES: unsupported file extension %s in file %s", filepath.Ext(each), each)
			}
		}
		aux := "set_global_assignment -name " + filetype
		if args.Rel {
			aux = aux + "[file join $::quartus(qip_path) " + each + "]"
		} else {
			aux = aux + " " + each
		}
		fmt.Fprintln(fout, aux)
	}
}

func dump_sim(all []string, args Args ) {
	fout, err := os.Create( "game.f" )
	if err != nil {
		log.Fatal(err)
	}
	fout_vhdl, err := os.Create("jtsim_vhdl.f")
	if err != nil {
		log.Fatal(err)
	}
	defer fout.Close()
	defer fout_vhdl.Close()
	for _, each := range all {
		dump := true
		switch filepath.Ext(each) {
		case ".sv", ".v":
			dump = true
		case ".qip",".sdc":
			dump = false
		case ".vhd":
			fmt.Fprintln(fout_vhdl, each)
			dump = false
		default:
			{
				log.Fatalf("JTFILES: unsupported file extension %s in file %s", filepath.Ext(each), each)
			}
		}
		if dump {
			fmt.Fprintln(fout, each)
		}
	}
}

func dump_plain(all []string, args Args ) {
	fout, err := os.Create( "files" )
	if err != nil {
		log.Fatal(err)
	}
	defer fout.Close()
	jtroot := os.Getenv("JTROOT")+"/"
	for _, each := range all {
		each=strings.TrimPrefix(each,jtroot)
		fmt.Fprintln(fout, each)
	}
}

// func parse_paths( skip []string, args Args, paths... string ) (uniq []string) {
// 	var files JTFiles
// 	for _, each := range paths {
// 		parse_yaml(each, &files)
// 	}
// 	all := collect_files( files, args.Rel )
// 	// Remove files in the skip list
// 	for _, s := range all {
// 		found := false
// 		for _, s2 := range skip {
// 			if s == s2 {
// 				found = true
// 				break
// 			}
// 		}
// 		if !found {
// 			uniq = append(uniq, s)
// 		}
// 	}
// 	return uniq
// }

func dump_files( filenames[]string, format string ) bool {
	switch format {
	case "syn", "qip":
		dump_qip(filenames, args )
	case "sim":
		dump_sim(filenames, args )
	case "plain":
		dump_plain(filenames, args )
	default:
		return false // don't know how to dump
	}
	return true
}

// Trying out the "accept interfaces" Go principle:
type CoreInfo interface {
	GetName() string
	GetTarget() string
}

func (this Args) GetName() string {
	return this.Corename
}

func (this Args) GetTarget() string {
	return this.Target
}

func append_mem( info CoreInfo, local bool, macros map[string]string, fn []string ) []string {
	mempath := filepath.Join( os.Getenv("CORES"), info.GetName(), "cfg", "mem.yaml" )
	f, err := os.Open( mempath )
	f.Close()
	if err!=nil {
		return fn	// mem.yaml didn't exist. Nothing done
	}
	fname := macros["GAMETOP"]+".v"
	if info.GetTarget()!="" && !local {
		fname = filepath.Join( os.Getenv("CORES"), info.GetName(),info.GetTarget(),fname)
	}
	return append(fn,fname)

}

func dump_ucode( files JTFiles ) {
	for _, uc := range files.Ucode {
		ucode.Args.Output = uc.Output
		ucode.Make(uc.modname,uc.Src)
	}
}

func Run(args Args) {
	CWD, _ = os.Getwd()

	var def_cfg def.Config
	def_cfg.Target = args.Target
	def_cfg.Core = args.Corename
	def_cfg.Add = cfgstr.Append_args(def_cfg.Add, strings.Split(args.AddMacro, ","))
	macros = def.Make_macros(def_cfg)

	var files JTFiles
	parse_yaml( GetFilename(args.Corename, "game", args.Parse), &files )
	parse_yaml( os.Getenv("JTFRAME")+"/hdl/jtframe.yaml", &files )

	if args.Target != "" {
		parse_yaml( os.Getenv("JTFRAME")+"/target/"+args.Target+"/target.yaml", &files )
		if args.Format == "sim" {
			parse_yaml(os.Getenv("JTFRAME")+"/target/"+args.Target+"/sim.yaml", &files )
		}
	}
	filenames := collect_files( files, args.Rel )
	filenames = append_mem( args, args.Local, macros, filenames )
	dump_ucode( files )
	if !dump_files( filenames, args.Format ) {
		fmt.Printf("Unknown output format '%s'\n", args.Format)
		os.Exit(1)
	}
}
