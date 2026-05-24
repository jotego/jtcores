package mra

import(
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
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
	if e := os.WriteFile(filepath.Join(core_cfg, "macros.def"), []byte("CORENAME=JTTEST85\n"), 0664); e != nil {
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
		cmd := exec.Command(args[0], args[1:]...)
		cmd.Dir = root
		if out, e := cmd.CombinedOutput(); e != nil {
			t.Fatalf("%v failed: %v\n%s", args, e, out)
		}
	}
	readme := filepath.Join(root, "README")
	if e := os.WriteFile(readme, []byte("test\n"), 0664); e != nil {
		t.Fatal(e)
	}
	for _, args := range [][]string{{"git", "add", "README"}, {"git", "commit", "-m", "init"}} {
		cmd := exec.Command(args[0], args[1:]...)
		cmd.Dir = root
		if out, e := cmd.CombinedOutput(); e != nil {
			t.Fatalf("%v failed: %v\n%s", args, e, out)
		}
	}
}
