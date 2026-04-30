package macros

import (
	"os"
	"path/filepath"
	"testing"
)

func Test_set_sdram_refresh_rate(t *testing.T) {
	var mclk int64
	mclk = 48000000
	set_sdram_refresh_rate(mclk)
	if got, _ := macros["JTFRAME_RFSH_N"]; got != "11'd1" {
		t.Errorf("Bad JTFRAME_RFSH_N. Got %s", got)
	}
	if got, _ := macros["JTFRAME_RFSH_M"]; got != "11'd1536" {
		t.Errorf("Bad JTFRAME_RFSH_M. Got %s", got)
	}
	if got, _ := macros["JTFRAME_RFSH_WC"]; got != "11" {
		t.Errorf("Bad JTFRAME_RFSH_WC. Got %s", got)
	}
}

func Test_uses_sdram_cache(t *testing.T) {
	root := t.TempDir()
	t.Setenv("JTROOT", root)
	t.Setenv("CORES", filepath.Join(root, "cores"))
	cfg_dir := filepath.Join(root, "cores", "cachecore", "cfg")
	if err := os.MkdirAll(cfg_dir, 0o755); err != nil {
		t.Fatal(err)
	}
	main_mem := "include:\n  - file: cache.yaml\n"
	if err := os.WriteFile(filepath.Join(cfg_dir, "mem.yaml"), []byte(main_mem), 0o644); err != nil {
		t.Fatal(err)
	}
	cache_mem := "sdram:\n  cache-lanes:\n    - tiles:\n      cache: { blocks: 1, size: 1kB, data_width: 16 }\n      at: { length: 8MB }\n"
	if err := os.WriteFile(filepath.Join(cfg_dir, "cache.yaml"), []byte(cache_mem), 0o644); err != nil {
		t.Fatal(err)
	}
	if !uses_sdram_cache("cachecore") {
		t.Fatal("Expected cache-lane usage to be detected")
	}
}
