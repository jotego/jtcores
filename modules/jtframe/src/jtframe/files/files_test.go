package files

import(
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"
)

func Test_parse_yaml_file_not_existing(t *testing.T) {
	_, e := parse_yaml_file("i_do_not_exist")
	if e==nil { t.Error("should have detected a non existing file")}
}

func Test_parse_yaml_file(t *testing.T) {
	collected, e := parse_yaml_file("test_here.yaml")
	if e!=nil { t.Error(e)}
	if total:=len(collected);total!=2 {
		t.Log(collected)
		t.Errorf("Expecting 2 files, found %d",total)
		return
	}
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
		From: "contra",
		Get: []string{"game.v"},
	}
	parse := fill_defaults(full_entry)
	if parse.From!=full_entry.From || slices.Compare(parse.Get,full_entry.Get)!=0 {
		t.Error("Fully defined entry should not be modified")
	}
	partial_entry := FileList{
		From: "jt12/jt89",
	}
	parse = fill_defaults(partial_entry)
	if parse.From!="jt12/jt89" {
		t.Error("'use' path should not be modified")
	}
	if slices.Compare(parse.Get,[]string{"files.yaml"})!=0 {
		t.Error("Default entries are not filled")
	}
}

func Test_find_files_in_path(t *testing.T) {
	basepath := ".."
	filelist := FileList{
		From: "files",
		Get: []string{"game.v","video.v","files.yaml","timing.sdc"},
	}
	foundpaths, e := find_files_in_path(basepath,filelist)
	if e!=nil { t.Error(e) }
	if total:=len(foundpaths);total!=4 {
		t.Errorf("Found %d paths, expected %d",total,len(filelist.Get))
	}
	for k,expected := range []string{
		"../files/hdl/game.v",
		"../files/hdl/video.v",
		"../files/cfg/files.yaml",
		"../files/syn/timing.sdc",} {
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

func Test_values_not_in_first(t *testing.T) {
	set_a := []string{"a","b","c"}
	set_b := []string{"d","c","e","a"}
	set_diff := values_not_in_first(set_a,set_b)
	expected := []string{"d","e"}
	make_paths_abs(expected)
	if slices.Compare(set_diff,expected)!=0 {
		t.Errorf("unexpected value")
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

func Test_expand_references(t *testing.T) {
	// no references
	filepaths := []string{"a.v","b.v","c.sdc"}
	new_paths, e := expand_references(filepaths)
	if e!=nil{ t.Error(e) }
	if len(new_paths)!=0 {
		t.Error("There are no references to expand")
	}
	// parsed references
	filepaths = []string{"used.yaml","b.v"}
	parsed = []string{"used.yaml"}
	new_paths, e = expand_references(filepaths)
	if e!=nil{ t.Error(e) }
	if len(new_paths)!=0 {
		t.Error("There are no references to expand")
	}
}

func Test_unmarshall(t *testing.T) {
	yaml_text := `here:
  - get:
    - files.go
    - types.go
`
	jtfiles, e := unmarshall([]byte(yaml_text))
	if e!= nil { t.Error(e) }
	if _,found := jtfiles["here"]; !found {
		t.Error("YAML unmarshall failed")
		return
	}
	contents := jtfiles["here"]
	if total:=len(contents);total!=1 {
		t.Errorf("Expecting 1 entries in Get, found %d",total)
	}
	filelist := contents[0]
	if total:=len(filelist.Get);total!=2 {
		t.Errorf("Expecting 2 entries in Get, found %d",total)
	}
}

// func Test_find_paths(t *testing.T) {
// 	jtfile := JTFiles{
// 		"modules": FileList{
// 			From: "jt12"
// 		},
// 	}
// }