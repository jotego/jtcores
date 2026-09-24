package files

import (
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"
)

func Test_module_mmr_dependencies(t *testing.T) {
	root := t.TempDir()
	t.Setenv("MODULES", root)
	module := filepath.Join(root, "test_mmr")
	for _, dir := range []string{"cfg", "hdl"} {
		if e := os.MkdirAll(filepath.Join(module, dir), 0755); e != nil {
			t.Fatal(e)
		}
	}
	write := func(name, data string) {
		t.Helper()
		if e := os.WriteFile(filepath.Join(module, name), []byte(data), 0644); e != nil {
			t.Fatal(e)
		}
	}
	write("cfg/mmr.yaml", `- name: test
  no_core_name: true
  size: 4
  regs:
    - {name: value, dw: 8, at: "0"}
`)
	write("cfg/files.yaml", "test_mmr:\n  - get: [jttest_mmr.v]\n")
	generated := filepath.Join(module, "hdl", "jttest_mmr.v")
	parsed = nil
	generated_mmr = make(map[string]bool)
	t.Cleanup(func() { parsed = nil; generated_mmr = make(map[string]bool) })
	// Disabled entries must not generate RTL, even if their MMR is invalid.
	disabled := JTFiles{"test_mmr": {{When: []string{"MMR_TEST_DISABLED"}, Get: []string{"jttest_mmr.v"}}}}
	if _, e := find_paths(disabled); e != nil {
		t.Fatal(e)
	}
	if _, e := os.Stat(generated); !os.IsNotExist(e) {
		t.Fatal("disabled module generated MMR")
	}
	// An empty dependency expands cfg/files.yaml, whose HDL does not exist yet.
	paths, e := find_paths(JTFiles{"test_mmr": nil})
	if e != nil {
		t.Fatal(e)
	}
	if !slices.Contains(paths, generated) {
		t.Fatalf("generated RTL missing from %v", paths)
	}
	data, e := os.ReadFile(generated)
	if e != nil {
		t.Fatal(e)
	}
	if !strings.Contains(string(data), "module jttest_mmr") {
		t.Fatal("incorrect generated RTL")
	}
	// Multiple references generate only once per invocation.
	write("cfg/mmr.yaml", "invalid: [")
	direct := JTFiles{"test_mmr": {{Get: []string{"jttest_mmr.v"}}}}
	if _, e = find_paths(direct); e != nil {
		t.Fatal(e)
	}
	// A new invocation must read the definition again and propagate errors.
	generated_mmr = make(map[string]bool)
	if _, e = find_paths(disabled); e != nil {
		t.Fatal(e)
	}
	if _, e = find_paths(direct); e == nil || !strings.Contains(e.Error(), "module test_mmr") {
		t.Fatalf("expected contextual MMR error, got %v", e)
	}
}
