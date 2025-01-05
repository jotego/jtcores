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
	// "github.com/jotego/jtframe/ucode"

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
	new_files, e := readin_yaml(filepath); if e!=nil { return nil,e }
	filepaths, e = find_paths(new_files); if e!=nil { return nil,fmt.Errorf("%w while parsing %s",e,filepath) }
	all_referenced, e := expand_references(filepaths); if e!=nil { return nil,e }
	filepaths = remove_references(filepaths)
	new_referenced := values_not_in_first(filepaths,all_referenced)
	filepaths=append(filepaths,new_referenced...)
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
	var new_files JTFiles
	e := yaml.Unmarshal(buf, &new_files)
	if e != nil {
		return nil,fmt.Errorf("YAML error: %w",e)
	}
	return new_files,nil
}

func find_paths(jtfile JTFiles) (filepaths[]string, e error) {
	filepaths = make([]string,0,32)
	for path_alias,content := range jtfile {
		basepath, e := get_base_path(path_alias); if e!=nil { return nil,e }
		newfiles, e := get_content_files(basepath,content); if e!=nil { return nil,e }
		different_files:=values_not_in_first(filepaths,newfiles)
		filepaths=append(filepaths,different_files...)
	}
	return filepaths,nil
}



func expand_references(all_files []string) (newfiles []string,e error) {
	newfiles = make([]string,0,128)
	for _, filename := range all_files {
		if filepath.Ext(filename)!=".yaml" { continue }
		if slices.Contains(parsed,filename) { continue }
		new_paths, e := parse_yaml_file(filename); if e!=nil { return nil,e }
		diff := values_not_in_first(newfiles,new_paths)
		newfiles=append(newfiles,diff...)
	}
	return newfiles,nil
}

func remove_references(files []string) (clean []string){
	clean = make([]string,0,len(files))
	for _,entry := range files {
		if filepath.Ext(entry)==".yaml" { continue }
		clean=append(clean,entry)
	}
	return clean
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

func get_content_files(basepath string, all_entries []FileList) ([]string,error) {
	filepaths := make([]string,0,32)
	// dummy entry so the for loop runs
	if len(all_entries)==0 {
		all_entries=[]FileList{
			FileList{},
		}
	}
	for _, entry := range all_entries {
		if !entry.Enabled() { continue }
		entry = fill_defaults(entry)
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

func find_files_in_path(basepath string,filelist FileList) (filepaths[]string, e error) {
	// unless/when
	filepaths = make([]string,len(filelist.Get))
	for k,newfile := range filelist.Get {
		subfolder := "hdl"
		switch filepath.Ext(newfile) {
		case ".yaml": subfolder="cfg"
		case ".sdc":  subfolder="syn"
		case ".v",".sv": subfolder="hdl"
		}
		filepaths[k]=filepath.Join(basepath,subfolder,filelist.From,newfile)
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

