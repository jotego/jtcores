package files

import(
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"
)

func Test_parse_yaml_file_not_existing(t *testing.T) {
	_, e := parse_yaml_file("i_do_not_exist",nil)
	if e==nil { t.Error("should have detected a non existing file")}
}

func Test_parse_yaml_file(t *testing.T) {
	jtfiles:=make(JTFiles)
	/*collected*/_, e := parse_yaml_file("test_here.yaml",jtfiles)
	if e!=nil { t.Error(e)}
	// if total:=len(collected);total!=2 {
	// 	t.Error("Expecting 2 files, found %d",total)
	// 	return
	// }
}

func Test_get_base_path(t *testing.T) {
	for _,name := range []string{"jtframe","cores","modules"} {
		base, e := get_base_path(name)
		if e!=nil { t.Error(e) }
		upper := strings.ToUpper(name)
		if base != os.Getenv(upper) {
			t.Errorf("%s base path did not match $%s",name,upper)
		}
	}
	_, e := get_base_path("undefined")
	if e==nil { t.Error("Undefined path was not identified") }
	base, e := get_base_path("here")
	if e!=nil { t.Error(e) }
	if base!="." { t.Error("'here' path incorrect")}
}

func Test_fill_defaults(t *testing.T) {
	full_entry := FileList{
		Use: "contra",
		Get: []string{"game.v"},
	}
	parse := fill_defaults(full_entry)
	if parse.Use!=full_entry.Use || slices.Compare(parse.Get,full_entry.Get)!=0 {
		t.Error("Fully defined entry should not be modified")
	}
	partial_entry := FileList{
		Use: "jt12/jt89",
	}
	parse = fill_defaults(partial_entry)
	if parse.Use!="jt12/jt89" {
		t.Error("'use' path should not be modified")
	}
	if slices.Compare(parse.Get,[]string{"cfg/files.yaml"})!=0 {
		t.Error("Default entries are not filled")
	}
}

func Test_find_files_in_path(t *testing.T) {
	basepath := ".."
	filelist := FileList{
		Use: "files",
		Get: []string{"game.v","video.v","files.yaml"},
	}
	foundpaths, e := find_files_in_path(basepath,filelist)
	if e!=nil { t.Error(e) }
	if total:=len(foundpaths);total!=3 {
		t.Errorf("Found %d paths, expected %d",total,len(filelist.Get))
	}
	for k,expected := range []string{
		"../files/hdl/game.v",
		"../files/hdl/video.v",
		"../files/cfg/files.yaml"} {
		if foundpaths[k] != expected {
			t.Errorf("Path was %s but should be %s",foundpaths[k],expected)
		}
	}
}

func Test_differences(t *testing.T) {
	cwd, e := os.Getwd()
	if e!=nil { t.Error(e); t.FailNow() }
	set_a := []string{"files.go","../files/types.go"}
	set_b := []string{"types.go",filepath.Join(cwd,"../files/files.go"),filepath.Join(cwd,"files_test.go")}
	set_diff := differences(set_a,set_b)
	if total:=len(set_diff);total!=3 {
		t.Errorf("Expected 3 files, got %d",total)
		t.Log(set_diff)
	}
}

func Test_make_paths_abs(t *testing.T) {
	cwd,_ := os.Getwd()
	folder_name := filepath.Base(cwd)
	paths := []string{"a",cwd+"/../"+folder_name+"//b"}
	make_paths_abs(paths)
	if total:=len(paths);total!=2 { t.Errorf("Expected 2 files, got %d",total)}
	if paths[0]!=filepath.Join(cwd,"a") { t.Errorf("Unexpected path %s",paths[0])}
	if paths[1]!=filepath.Join(cwd,"b") { t.Errorf("Unexpected path %s",paths[1])}
}

// func Test_find_paths(t *testing.T) {
// 	jtfile := JTFiles{
// 		"modules": FileList{
// 			Use: "jt12"
// 		},
// 	}
// }