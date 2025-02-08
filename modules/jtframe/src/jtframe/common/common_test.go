package common

import(
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