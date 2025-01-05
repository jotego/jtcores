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

	// "github.com/jotego/jtframe/common"
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

	// var files JTFiles
	// parse_yaml( common.ConfigFilePath(args.Corename, "files.yaml"), files )
	// parse_yaml( os.Getenv("JTFRAME")+"/hdl/jtframe.yaml", files )

	// if args.Target != "" {
	// 	parse_yaml( os.Getenv("JTFRAME")+"/target/"+args.Target+"/target.yaml", &files )
	// 	if args.Format == "sim" {
	// 		parse_yaml(os.Getenv("JTFRAME")+"/target/"+args.Target+"/sim.yaml", &files )
	// 	}
	// }
	// filenames := collect_files( files, args.Rel )
	// filenames = append_mem( args, args.Local, macros.Get("GAMETOP"), filenames )
	// dump_ucode( files )
	// if !dump_files( filenames, args.Format ) {
	// 	fmt.Printf("Unknown output format '%s'\n", args.Format)
	// 	os.Exit(1)
	// }
}

func prepare_macros() {
	macros.MakeMacros(args.Corename, args.Target)
	arg_macros := strings.Split(args.AddMacro, ",")
	macros.AddKeyValPairs(arg_macros...)
}

func parse_yaml_file(filepath string) (filepaths []string, e error) {
	new_files, e := readin_yaml(filepath); if e!=nil { return nil,e }
	filepaths, e = find_paths(new_files); if e!=nil { return nil,e }
	// all_referenced, e := expand_references(filepaths); if e!=nil { return nil,e }
	// new_referenced := differences(filepaths,all_referenced)
	// filepaths=append(filepaths,new_referenced...)
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
		different_files:=differences(filepaths,newfiles)
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
		diff := differences(newfiles,new_paths)
		newfiles=append(newfiles,diff...)
	}
	return newfiles,nil
}

func get_base_path(name string) (basepath string, e error) {
	switch name {
	case "jtframe","cores","modules": {
		upper := strings.ToUpper(name)
		basepath=os.Getenv(upper)
	}
	case "here": basepath="."
	default: return "",fmt.Errorf("Unknown path alias %s",name)
	}
	if basepath=="" {
		return "",fmt.Errorf("Cannot resolve path alias %s meaningfully",name)
	}
	return basepath,nil
}

func get_content_files(basepath string, all_entries []FileList) ([]string,error) {
	filepaths := make([]string,0,32)
	for _, entry := range all_entries {
		entry = fill_defaults(entry)
		newfiles, e := find_files_in_path(basepath,entry);
		if e!=nil { return nil,e }
		different_files:=differences(filepaths,newfiles)
		filepaths=append(filepaths,different_files...)
	}
	return filepaths,nil
}

func fill_defaults(entry FileList) FileList {
	if entry.Use!="" && len(entry.Get)==0 {
		entry.Get = []string{"cfg/files.yaml"}
	}
	return entry
}

func find_files_in_path(basepath string,filelist FileList) (filepaths[]string, e error) {
	// unless/when
	basepath = filepath.Join(basepath,filelist.Use)
	filepaths = make([]string,len(filelist.Get))
	for k,newfile := range filelist.Get {
		subfolder := "hdl"
		switch filepath.Ext(newfile) {
		case ".yaml": subfolder="cfg"
		case ".sdc":  subfolder="syn"
		case ".v",".sv": subfolder="hdl"
		}
		filepaths[k]=filepath.Join(basepath,subfolder,newfile)
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

func init() {
	parsed = make([]string, 0, 128)
}