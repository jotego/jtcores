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

func Test_make_clocks_pll5369_sdram96(t *testing.T) {
	MakeFromMap(map[string]string{
		"JTFRAME_PLL":     "jtframe_pll5369",
		"JTFRAME_SDRAM96": "1",
	})
	mclk := make_clocks("MISTER")
	if mclk != 85909088 {
		t.Fatalf("Bad JTFRAME_MCLK for jtframe_pll5369 with SDRAM96. Got %d", mclk)
	}
	if got := Get("JTFRAME_MCLK"); got != "85909088" {
		t.Fatalf("Bad JTFRAME_MCLK macro. Got %s", got)
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

func Test_check_macros_lf_buffer_ddrload_mister(t *testing.T) {
	MakeFromMap(map[string]string{
		"TARGET":             "mister",
		"JTFRAME_LF_BUFFER":  "1",
		"JTFRAME_LF_HW":      "9",
		"JTFRAME_LF_VW":      "8",
		"JTFRAME_MR_DDRLOAD": "1",
		"JTFRAME_WIDTH":      "320",
		"JTFRAME_HEIGHT":     "224",
	})
	if err := CheckMacros(); err != nil {
		t.Fatalf("Expected MiSTer lf-buffer DDR-load combination to be accepted: %v", err)
	}
}

func Test_check_macros_lf_buffer_vertical(t *testing.T) {
	MakeFromMap(map[string]string{
		"TARGET":            "mister",
		"JTFRAME_LF_BUFFER": "1",
		"JTFRAME_LF_HW":     "9",
		"JTFRAME_LF_VW":     "8",
		"JTFRAME_VERTICAL":  "1",
		"JTFRAME_WIDTH":     "320",
		"JTFRAME_HEIGHT":    "224",
	})
	if err := CheckMacros(); err == nil {
		t.Fatal("Expected vertical lf-buffer combination to be rejected")
	}
}

func Test_check_macros_rejects_sdram_xl_and_large(t *testing.T) {
	MakeFromMap(map[string]string{
		"TARGET":              "mister",
		"JTFRAME_SDRAM_XL":    "1",
		"JTFRAME_SDRAM_LARGE": "1",
		"JTFRAME_WIDTH":       "320",
		"JTFRAME_HEIGHT":      "224",
	})
	if err := CheckMacros(); err == nil {
		t.Fatal("Expected JTFRAME_SDRAM_XL with JTFRAME_SDRAM_LARGE to be rejected")
	}
}

func Test_check_macros_rejects_sdram_xl_ba_start(t *testing.T) {
	MakeFromMap(map[string]string{
		"TARGET":             "mister",
		"JTFRAME_SDRAM_XL":   "1",
		"JTFRAME_BA1_START":  "0x100000",
		"JTFRAME_WIDTH":      "320",
		"JTFRAME_HEIGHT":     "224",
	})
	if err := CheckMacros(); err == nil {
		t.Fatal("Expected JTFRAME_SDRAM_XL with JTFRAME_BA1_START to be rejected")
	}
}
