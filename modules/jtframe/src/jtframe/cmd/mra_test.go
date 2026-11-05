package cmd

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"jotego/jtframe/mra"
)

func Test_mra_audit_cli(t *testing.T) {
	if cores := os.Getenv("JTFRAME_TEST_AUDIT_CORES"); cores != "" {
		mra_args = mra.Args{SkipROM: true, SkipPocket: true, Rom_path: filepath.Join(os.Getenv("JTROOT"), "absent-roms")}
		runMRA(nil, strings.Fields(cores))
		return
	}
	root := t.TempDir()
	t.Setenv("JTROOT", root)
	t.Setenv("CORES", filepath.Join(root, "cores"))
	for _, args := range [][]string{{"init", root}, {"-C", root, "-c", "user.name=Test", "-c", "user.email=test@example.invalid", "commit", "--allow-empty", "-m", "fixture"}} {
		cmd := exec.Command("git", args...)
		for _, env := range os.Environ() {
			if !strings.HasPrefix(env, "GIT_") { cmd.Env = append(cmd.Env, env) }
		}
		if out, e := cmd.CombinedOutput(); e != nil { t.Fatalf("git: %v: %s", e, out) }
	}
	write := func(name, data string) {
		t.Helper()
		path := filepath.Join(root, name)
		if e := os.MkdirAll(filepath.Dir(path), 0775); e != nil { t.Fatal(e) }
		if e := os.WriteFile(path, []byte(data), 0664); e != nil { t.Fatal(e) }
	}
	xml := `<mame build="0.280">`
	for _, core := range []string{"abad", "bstale", "zgood"} {
		write("cores/"+core+"/cfg/macros.def", "CORENAME=JT"+strings.ToUpper(core)+"\nJTFRAME_WIDTH=320\nJTFRAME_HEIGHT=240\nJTFRAME_LF_HW=9\nJTFRAME_LF_VW=8\n")
		toml := fmt.Sprintf("[parse]\nsourcefile=[%q]\n[cheat]\ndisable=true\n[ROM]\norder=[\"maincpu\"]\n", core+".cpp")
		if core == "abad" { toml = "invalid TOML [" }
		if core == "bstale" { toml += "regions=[{name=\"oldcpu\"}]\n" }
		write("cores/"+core+"/cfg/mame2mra.toml", toml)
		xml += fmt.Sprintf(`<machine name="%s" sourcefile="%s.cpp"><description>%s</description><rom name="code.bin" size="16" region="maincpu" offset="0"/><display width="320" height="240" rotate="0"/></machine>`, core, core, core)
	}
	write("doc/mame.xml", xml+"</mame>")
	for _, tc := range []struct{ cores string; wants []string; failure bool }{
		{"shell", []string{"abad:", "TOML", "bstale:", "oldcpu"}, true},
		{"missing zgood", []string{"missing is not a valid core name"}, true},
		{"* zgood", []string{"* is not a valid core name"}, true},
		{"z* zgood", []string{"z* is not a valid core name"}, true},
		{"zgood", nil, false},
	} {
		cmd := exec.Command(os.Args[0], "-test.run=^Test_mra_audit_cli$")
		cmd.Env = append(os.Environ(), "JTFRAME_TEST_AUDIT_CORES="+tc.cores)
		if tc.cores == "shell" {
			cmd = exec.Command("bash", "-c", `export JTFRAME_TEST_AUDIT_CORES; JTFRAME_TEST_AUDIT_CORES=$(printf '%s\n' *); exec "$1" -test.run=^Test_mra_audit_cli$`, "audit", os.Args[0])
			cmd.Dir = filepath.Join(root, "cores")
		}
		out, e := cmd.CombinedOutput()
		if (e != nil) != tc.failure { t.Fatalf("cores %q: %v\n%s", tc.cores, e, out) }
		for _, want := range tc.wants {
			if !strings.Contains(string(out), want) { t.Fatalf("missing %q in %s", want, out) }
		}
		if _, e := os.Stat(filepath.Join(root, "release/mra/zgood.mra")); e != nil { t.Fatalf("last core not generated: %v\n%s", e, out) }
	}
	if _, e := os.Stat(filepath.Join(root, "rom")); !os.IsNotExist(e) { t.Fatalf("ROM output created: %v", e) }
}
