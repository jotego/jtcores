package common

import(
	"fmt"
	"os"
	"path/filepath"
	"testing"
)

func Test_ConfigFilePath(t *testing.T) {
	cfg := ConfigFilePath("gng","mem.yaml")
	expected := filepath.Join(os.Getenv("JTROOT"),"cores","gng","cfg","mem.yaml")
	if cfg!=expected { t.Errorf("Path mismatch %s != %s",cfg,expected)}

	cfg = ConfigFilePath("1942","")
	expected = filepath.Join(os.Getenv("JTROOT"),"cores","1942","cfg")
	if cfg!=expected { t.Errorf("Path mismatch %s != %s",cfg,expected)}
}

func Test_FindFileInFolders(t *testing.T) {
	jtframe_path := os.Getenv("JTFRAME")
	cores_path := filepath.Join(os.Getenv("CORES"),"1942","cfg")
	search_paths := []string{jtframe_path,cores_path}
	path, e := FindFileInFolders("files.yaml",search_paths)
	if e!=nil { t.Error(e) }
	if path=="" { t.Errorf("File not found!") }
	if !FileExists(path) { t.Errorf("File does not exist") }

	// not a recursive search:
	cores_path = filepath.Join(os.Getenv("CORES"))
	search_paths = []string{jtframe_path,cores_path}
	path, e = FindFileInFolders("files.yaml",search_paths)
	if e==nil { t.Errorf("The search should have failed") }
	if path!="" { t.Errorf("File should not be found!") }
}

func Test_MakeJTpath(t *testing.T ) {
	old_jtroot := os.Getenv("JTROOT")
	jtroot := "/jtdev"
	os.Setenv("JTROOT",jtroot)
	got := MakeJTpath("doc","mame.xml")
	exp := filepath.Join(jtroot,"doc","mame.xml")
	if got!=exp {
		t.Errorf("got %s, wanted %s",got, exp)
	}

	got = MakeJTpath("a","b","c","d")
	exp = filepath.Join(jtroot,"a","b","c","d")
	if got!=exp {
		t.Errorf("got %s, wanted %s",got, exp)
	}

	os.Setenv("JTROOT",old_jtroot)
}

func Test_JoinErrors(t *testing.T) {
	e := JoinErrors(nil)
	if e!=nil { t.Errorf("nil input must produce nil output")}
	e = JoinErrors(nil, nil, nil)
	if e!=nil { t.Errorf("nil input must produce nil output")}

	e1 := fmt.Errorf("one error")
	e = JoinErrors(e1)
	if e==nil {
		t.Errorf("blank output for non-nil input")
	} else {
		if e.Error()!=e1.Error() { t.Errorf("wrong output for single error") }
	}

	e = JoinErrors(nil,e1)
	if e==nil {
		t.Errorf("blank output for non-nil input")
	} else {
		if e.Error()!=e1.Error() { t.Errorf("wrong output for single error") }
	}

	e2 := fmt.Errorf("Another one")
	e = JoinErrors(e1,e2)
	if e==nil {
		t.Errorf("blank output for non-nil input")
	} else {
		if e.Error()!="one error\nAnother one" {
			t.Errorf("wrong output for double error")
		}
	}
}