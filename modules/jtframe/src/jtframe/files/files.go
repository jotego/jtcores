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

package files

import (
	"fmt"
	"io/ioutil"
	// "log"
	"os"
	"path/filepath"
	// "sort"
	"slices"
	"strings"

	"github.com/jotego/jtframe/common"
	"github.com/jotego/jtframe/macros"
	"github.com/jotego/jtframe/ucode"

	"gopkg.in/yaml.v2"
)

var parsed []string
var CWD string
var args Args

func Run(set_args Args) {
	args = set_args
	CWD, _ = os.Getwd()
	prepare_macros()

	filenames, e := parse_yaml_file( common.ConfigFilePath(args.Corename, "files.yaml") )
	common.Must(e)

	jtframe_cfg := filepath.Join(os.Getenv("JTFRAME"),"cfg","files.yaml")
	all_jtframe, e := parse_yaml_file( jtframe_cfg )
	common.Must(e)

	filenames = merge(filenames,all_jtframe)
	target_files, e := collect_target()
	common.Must(e)

	filenames = merge(filenames,target_files)
	if mem_file := get_mem_file(); mem_file!="" {
		filenames = append(filenames,mem_file)
	}
	if args.Rel {
		common.Must(make_relative_to_cwd(filenames))
	}
	// dump_ucode( files )
	e = dump_files( filenames )
	common.Must(e)
}

func prepare_macros() {
	macros.MakeMacros(args.Corename, args.Target)
	arg_macros := strings.Split(args.AddMacro, ",")
	macros.AddKeyValPairs(arg_macros...)
}

func collect_target() ([]string,error) {
	if args.Target == "" { return nil,nil }
	target_cfg := get_target_cfg_filepath("files.yaml")
	files, e := parse_yaml_file( target_cfg )
	if e!=nil { return nil, e }

	var sim_files []string
	if args.Format == "sim" {
		sim_cfg := get_target_cfg_filepath("sim.yaml")
		sim_files, e = parse_yaml_file(sim_cfg)
		if e!=nil { return nil, e }
	}
	return merge(files,sim_files),nil
}

func get_target_cfg_filepath(filename string) string {
	return filepath.Join(os.Getenv("JTFRAME"),"target",args.Target,"cfg",filename)
}

func merge(a,b []string) []string {
	new_in_b := values_not_in_first(a,b)
	return append(a,new_in_b...)
}

func get_mem_file() string {
	cwd,_ := os.Getwd()
	memcfg := common.ConfigFilePath(args.Corename,"mem.yaml")
	if !common.FileExists(memcfg) { return "" }
	game_file := macros.Get("GAMETOP")+".v"
	if args.Target!="" && !args.Local {
		syn_folder := filepath.Join(os.Getenv("CORES"),args.Corename,args.Target)
		syn_folder, _ = filepath.Rel(cwd,syn_folder)
		game_file=filepath.Join(syn_folder,game_file)
	}
	game_file=filepath.Join(cwd,game_file)
	return game_file
}

func make_relative_to_cwd(filenames []string) (e error) {
	cwd, _ := os.Getwd()
	for k,_ := range filenames {
		filenames[k], e = filepath.Rel(cwd,filenames[k])
	}
	return e
}

func parse_yaml_file(filepath string) (filepaths []string, e error) {
	newfiles, e := readin_yaml(filepath); if e!=nil { return nil,e }
	e = make_ucode(newfiles); if e!=nil { return nil,e }
	filepaths, e = find_paths(newfiles)
	if e!=nil { return nil,fmt.Errorf("%w while parsing %s",e,filepath) }
	return filepaths, nil
}

func readin_yaml(filename string) (JTFiles,error) {
	buf, e := ioutil.ReadFile(filename)
	if e != nil {
		return nil,fmt.Errorf("jtframe files: cannot open referenced file %s\n%w",filename,e)
	}
	parsed = append(parsed, filename)
	jtfiles, e := unmarshall(buf)
	if e!= nil {
		return nil,fmt.Errorf("While parsing file %s, %w",filename,e)
	}
	return jtfiles,nil
}

func unmarshall(buf []byte) (JTFiles,error) {
	var newfiles JTFiles
	e := yaml.Unmarshal(buf, &newfiles)
	if e != nil {
		return nil,fmt.Errorf("YAML error: %w",e)
	}
	return newfiles,nil
}

func find_paths(jtfile JTFiles) (filepaths[]string, e error) {
	filepaths = make([]string,0,32)
	for path_alias,content := range jtfile {
		basepath, e := get_base_path(path_alias); if e!=nil { return nil,e }
		newfiles, e := get_content_files(basepath,content); if e!=nil { return nil,e }
		filepaths, e = append_or_expand(filepaths,newfiles); if e!=nil { return nil,e }
		// different_files:=values_not_in_first(filepaths,newfiles)
		// filepaths=append(filepaths,different_files...)
	}
	return filepaths,nil
}

func append_or_expand(oldfiles,newfiles []string) (merged []string,e error) {
	merged = make([]string,len(oldfiles),len(oldfiles)+len(newfiles))
	copy(merged,oldfiles)
	for _,filename := range newfiles {
		if slices.Contains(merged,filename) { continue }
		expanded, e := expand_references(filename); if e!=nil { return nil, e }
		merged=append(merged,expanded...)
	}
	return merged,nil
}

func expand_references(filename string) (newfiles []string,e error) {
	if filepath.Ext(filename)!=".yaml" { return []string{filename}, nil }
	if slices.Contains(parsed,filename) { return nil, nil }
	newfiles = make([]string,0,128)
	return parse_yaml_file(filename)
}

func get_base_path(name string) (basepath string, e error) {
	if name=="." {
		return ".", nil
	}
	if basepath, found := is_core(name); found {
		return basepath, nil
	}
	if basepath, found := is_module(name); found {
		return basepath, nil
	}
	return "",fmt.Errorf("Cannot resolve path alias %s meaningfully",name)
}

func is_core(name string) (string,bool) {
	return is_in_folder(name,os.Getenv("CORES"))
}

func is_module(name string) (string,bool) {
	return is_in_folder(name,os.Getenv("MODULES"))
}

func is_in_folder(name, folder string) (string,bool) {
	full_path := filepath.Join(folder,name)
	if common.FileExists(full_path) {
		return full_path,true
	}
	return "",false
}

func get_content_files(basepath string, all_entries []FileList) (filepaths []string,e error) {
	filepaths = make([]string,0,32)
	// dummy entry so the for loop runs
	if len(all_entries)==0 {
		all_entries=[]FileList{
			FileList{},
		}
	}
	for _, entry := range all_entries {
		if !entry.Enabled() { continue }
		entry = fill_defaults(entry)
		if e:=validate(entry); e!=nil { return nil, e }
		entry.Get, e = expand_glob(basepath,entry)
		if e!=nil { return nil,e }
		newfiles, e := find_files_in_path(basepath,entry);
		if e!=nil { return nil,e }
		different_files:=differences(filepaths,newfiles)
		filepaths=append(filepaths,different_files...)
	}
	return filepaths,nil
}

func fill_defaults(entry FileList) FileList {
	var empty UcDesc
	if entry.Ucode==empty && len(entry.Get)==0 {
		entry.Get = []string{"files.yaml"}
	}
	return entry
}

func validate(entry FileList) (e error) {
	for _,filename := range entry.Get {
		basename := filepath.Base(filename)
		if basename!=filename {
			return fmt.Errorf("File entries cannot contain folder names: %s",filename)
		}
	}
	return nil
}

func expand_glob(basepath string, entry FileList) (expanded []string,e error) {
	expanded=make([]string,0,len(entry.Get))
	for _,filename := range entry.Get {
		filename = entry.make_path(basepath,filename)
		matches, e := filepath.Glob(filename)
		if e!=nil { return nil,e }
		if len(matches)==0 {
			return nil,fmt.Errorf("%s did not match any file",filename)
		}
		short_names := basenames(matches)
		expanded=append(expanded,short_names...)
	}
	return expanded,nil
}

func basenames(all_names []string) (based []string) {
	based = make([]string,0,len(all_names))
	for _, name := range all_names {
		based=append(based,filepath.Base(name))
	}
	return based
}

// func change_dir(ref_filepath string, filenames []string) []string {
// 	basename
// }

func (entry FileList) make_path(basepath, filename string) string {
	subfolder := subfolder_for_ext(filename)
	full_path := filepath.Join(basepath,subfolder,entry.From,filename)
	return full_path
}

func subfolder_for_ext(filename string) string {
	subfolder := ""
	switch filepath.Ext(filename) {
	case ".yaml": subfolder="cfg"
	case ".sdc",".qip":  subfolder="syn"
	case ".v",".sv",".vhd": subfolder="hdl"
	}
	return subfolder
}

func find_files_in_path(basepath string,filelist FileList) (filepaths[]string, e error) {
	// unless/when
	filepaths = make([]string,len(filelist.Get))
	for k,newfile := range filelist.Get {
		filepaths[k]=filelist.make_path(basepath,newfile)
	}
	return filepaths,nil
}

func differences(a, b []string) (diff []string) {
	make_paths_abs(a)
	make_paths_abs(b)
	diff = make([]string,0,len(a)+len(b))
	for _,path := range a {
		if slices.Contains(diff,path) {continue}
		diff=append(diff,path)
	}
	for _,path := range b {
		if slices.Contains(diff,path) {continue}
		diff=append(diff,path)
	}
	return diff
}

func values_not_in_first(a, b []string) (diff []string) {
	make_paths_abs(a)
	make_paths_abs(b)
	diff = make([]string,0,len(b))
	for _,path := range b {
		if slices.Contains(a,path) {continue}
		diff=append(diff,path)
	}
	return diff
}

func make_paths_abs(paths []string) {
	cwd,_ := os.Getwd()
	for k,newpath := range paths {
		if !filepath.IsAbs(newpath) {
			newpath = filepath.Join(cwd,newpath)
		}
		clean := filepath.Clean(newpath)
		paths[k] = clean
	}
}

func make_ucode( files JTFiles ) error {
	for path_alias,content := range files {
		// basepath, e := get_base_path(path_alias); if e!=nil { return nil,e }
		for _, entry := range content {
			uc := entry.Ucode
			if uc.Src=="" { continue }
			ucode.Args.Output = uc.Output
			e := ucode.Make(path_alias,uc.Src)
			if e!=nil { return e }
		}
	}
	return nil
}

func dump_files( filenames[]string ) error {
	switch args.Format {
	case "syn", "qip":
		return dump_qip(filenames)
	case "sim":
		return dump_sim(filenames)
	case "plain":
		return dump_plain(filenames)
	default:
		return fmt.Errorf("Unknown dump format %s",args.Format)
	}
}

func init() {
	parsed = make([]string, 0, 128)
}

