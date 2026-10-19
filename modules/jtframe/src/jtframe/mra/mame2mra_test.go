package mra

import(
	"archive/zip"
	"crypto/md5"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"fmt"
)

func Test_get_altdir_name(t *testing.T) {
	dirname := get_altdir_name("Teenage Mutant Hero Turtles - Turtles in Time (2 Players ver EBA)")
	if dirname!="Turtles in Time" {
		t.Log(dirname)
		t.Errorf("Bad dir name")
	}
}

func Test_collect_alt_versions(t *testing.T) {
	machine := &MachineXML{Name: "gng"}
	cfg := Mame2MRA{}
	cfg.ROM.Patches = []struct {
		Selectable
		Altversion       string
		Offset           int
		Data             string
	}{
		{ Selectable: Selectable{Setname: "gng"}, Altversion: "color", Offset: 0x10, Data: "AA" },
		{ Selectable: Selectable{Setname: "gng"}, Altversion: "color", Offset: 0x20, Data: "BB" },
		{ Selectable: Selectable{Setname: "gng"}, Altversion: "boss",  Offset: 0x30, Data: "CC" },
		{ Selectable: Selectable{Setname: "other"}, Altversion: "skip", Offset: 0x40, Data: "DD" },
	}
	versions := collect_alt_versions(machine, cfg)
	if len(versions) != 2 || versions[0] != "color" || versions[1] != "boss" {
		t.Fatalf("unexpected altversions: %#v", versions)
	}
}

func Test_patch_is_skipped(t *testing.T) {
	if !patch_is_skipped("", "hack") {
		t.Fatalf("main patch should be skipped in alt mode")
	}
	if patch_is_skipped("", "") {
		t.Fatalf("main patch should be kept in regular mode")
	}
	if patch_is_skipped("hack", "hack") {
		t.Fatalf("selected altversion should be kept")
	}
	if !patch_is_skipped("other", "hack") {
		t.Fatalf("different altversion should be skipped")
	}
}

func Test_Convert_romless_mra(t *testing.T) {
	root := t.TempDir()
	init_test_git(t, root)
	t.Setenv("JTROOT", root)
	t.Setenv("CORES", filepath.Join(root, "cores"))
	t.Setenv("JTFRAME", filepath.Join(root, "modules", "jtframe"))
	core_cfg := filepath.Join(root, "cores", "test85", "cfg")
	core_hdl := filepath.Join(root, "cores", "test85", "hdl")
	if e := os.MkdirAll(core_cfg, 0775); e != nil {
		t.Fatal(e)
	}
	if e := os.MkdirAll(core_hdl, 0775); e != nil {
		t.Fatal(e)
	}
	macro_data := "CORENAME=JTTEST85\nJTFRAME_WIDTH=320\nJTFRAME_HEIGHT=240\nJTFRAME_LF_HW=9\nJTFRAME_LF_VW=8\n"
	if e := os.WriteFile(filepath.Join(core_cfg, "macros.def"), []byte(macro_data), 0664); e != nil {
		t.Fatal(e)
	}
	toml := []byte("[global]\nplatform=\"test85\"\n")
	if e := os.WriteFile(filepath.Join(core_cfg, "mame2mra.toml"), toml, 0664); e != nil {
		t.Fatal(e)
	}

	args := Args{Core: "test85", Target: "mister", SkipROM: true, SkipPocket: true}
	if e := args.Convert(); e != nil {
		t.Fatal(e)
	}
	mra_path := filepath.Join(root, "release", "mra", "test85.mra")
	got, e := os.ReadFile(mra_path)
	if e != nil {
		t.Fatal(e)
	}
	out := string(got)
	for _, want := range []string{"<name>test85</name>", "<setname>test85</setname>", "<rbf>jttest85</rbf>"} {
		if !strings.Contains(out, want) {
			t.Fatalf("ROM-less MRA is missing %q\n%s", want, out)
		}
	}
	if strings.Contains(out, "<rom") {
		t.Fatalf("ROM-less MRA should not contain a rom node\n%s", out)
	}
}

func init_test_git(t *testing.T, root string) {
	t.Helper()
	commands := [][]string{
		{"git", "init"},
		{"git", "config", "user.email", "test@example.invalid"},
		{"git", "config", "user.name", "test"},
	}
	for _, args := range commands {
		run_test_git(t, root, args)
	}
	readme := filepath.Join(root, "README")
	if e := os.WriteFile(readme, []byte("test\n"), 0664); e != nil {
		t.Fatal(e)
	}
	for _, args := range [][]string{{"git", "add", "README"}, {"git", "commit", "-m", "init"}} {
		run_test_git(t, root, args)
	}
}

func run_test_git(t *testing.T, root string, args []string) {
	t.Helper()
	cmd := exec.Command(args[0], args[1:]...)
	cmd.Dir = root
	cmd.Env = clean_test_git_env(os.Environ())
	if out, e := cmd.CombinedOutput(); e != nil {
		t.Fatalf("%v failed: %v\n%s", args, e, out)
	}
}

func clean_test_git_env(env []string) []string {
	local := map[string]bool{
		"GIT_ALTERNATE_OBJECT_DIRECTORIES": true,
		"GIT_CONFIG": true,
		"GIT_CONFIG_PARAMETERS": true,
		"GIT_CONFIG_COUNT": true,
		"GIT_OBJECT_DIRECTORY": true,
		"GIT_DIR": true,
		"GIT_WORK_TREE": true,
		"GIT_IMPLICIT_WORK_TREE": true,
		"GIT_GRAFT_FILE": true,
		"GIT_INDEX_FILE": true,
		"GIT_NO_REPLACE_OBJECTS": true,
		"GIT_REPLACE_REF_BASE": true,
		"GIT_PREFIX": true,
		"GIT_SHALLOW_FILE": true,
		"GIT_COMMON_DIR": true,
	}
	clean := make([]string, 0, len(env))
	for _, each := range env {
		name := each
		if eq := strings.IndexByte(each, '='); eq >= 0 {
			name = each[:eq]
		}
		if !local[name] {
			clean = append(clean, each)
		}
	}
	return clean
}

func Test_Convert_skipROM_audit(t *testing.T) {
	root := t.TempDir()
	init_test_git(t, root)
	t.Setenv("JTROOT", root)
	t.Setenv("CORES", filepath.Join(root, "cores"))
	t.Setenv("JTFRAME", filepath.Join(root, "modules", "jtframe"))
	write := func(name, data string) {
		t.Helper()
		path := filepath.Join(root, name)
		if e := os.MkdirAll(filepath.Dir(path), 0775); e != nil { t.Fatal(e) }
		if e := os.WriteFile(path, []byte(data), 0664); e != nil { t.Fatal(e) }
	}
	write("cores/audit/cfg/macros.def", "CORENAME=JTAUDIT\nJTFRAME_WIDTH=320\nJTFRAME_HEIGHT=240\nJTFRAME_LF_HW=9\nJTFRAME_LF_VW=8\n")
	write("cores/audit/cfg/mame2mra.toml", `[parse]
sourcefile=["audit.cpp"]
[cheat]
disable=true
[ROM]
order=["maincpu"]
regions=[
 {name="maincpu", setname="badfirst", parts=[{name="code.bin", length=32}]},
 {name="maincpu", setname="badsecond", singleton=true, width=64}
]
`)
	xml := "<mame build=\"0.280\">"
	for _, name := range []string{"badfirst", "badsecond", "goodlast"} {
		xml += fmt.Sprintf(`<machine name="%s" sourcefile="audit.cpp"><description>%s</description><rom name="code.bin" size="16" region="maincpu" offset="0"/><display width="320" height="240" rotate="0"/></machine>`, name, name)
	}
	write("doc/mame.xml", xml+"</mame>")
	args := Args{Core: "audit", Target: "mister", SkipROM: true, SkipPocket: true, Xml_path: filepath.Join(root, "doc/mame.xml"), Rom_path: filepath.Join(root, "no-rom-directory")}
	e := args.Convert()
	for _, want := range []string{"badfirst", "length+offset", "badsecond", "singleton"} {
		if e == nil || !strings.Contains(e.Error(), want) { t.Fatalf("missing %q in %v", want, e) }
	}
	mras, e := filepath.Glob(filepath.Join(root, "release/mra/*.mra"))
	if e != nil || len(mras) != 1 { t.Fatalf("expected only the valid MRA, got %v (%v)", mras, e) }
	data, e := os.ReadFile(mras[0])
	if e != nil || !strings.Contains(string(data), "goodlast") { t.Fatalf("later set was not generated: %s (%v)", data, e) }
	args.Setname = "goodlast"
	if e := args.Convert(); e != nil { t.Fatal(e) }
	if _, e := os.Stat(filepath.Join(root, "rom")); !os.IsNotExist(e) { t.Fatalf("ROM output created: %v", e) }
	args.Md5 = true
	args.Rom_path = filepath.Join(root, "rom-zips")
	if e := os.MkdirAll(args.Rom_path, 0775); e != nil { t.Fatal(e) }
	zip_file, e := os.Create(filepath.Join(args.Rom_path, "goodlast.zip"))
	if e != nil { t.Fatal(e) }
	writer := zip.NewWriter(zip_file)
	part, e := writer.Create("code.bin")
	if e != nil { t.Fatal(e) }
	rom_data := []byte("0123456789abcdef")
	if _, e := part.Write(rom_data); e != nil { t.Fatal(e) }
	if e := writer.Close(); e != nil { t.Fatal(e) }
	if e := zip_file.Close(); e != nil { t.Fatal(e) }
	if e := args.Convert(); e != nil { t.Fatal(e) }
	data, e = os.ReadFile(mras[0])
	if e != nil { t.Fatal(e) }
	want_md5 := fmt.Sprintf(`asm_md5="%x"`, md5.Sum(rom_data))
	if !strings.Contains(string(data), want_md5) { t.Fatalf("MRA missing ZIP payload checksum %s: %s", want_md5, data) }
	if _, e := os.Stat(filepath.Join(root, "rom")); !os.IsNotExist(e) { t.Fatalf("--skipROM --md5 created ROM output: %v", e) }
}
