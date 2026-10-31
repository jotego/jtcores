package macros

import (
	"os"
	"path/filepath"
	"strconv"
	"strings"
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

func Test_make_clocks_pll7000_sdram96(t *testing.T) {
	MakeFromMap(map[string]string{
		"JTFRAME_PLL":     "jtframe_pll7000",
		"JTFRAME_SDRAM96": "1",
	})
	mclk := make_clocks("MISTER")
	if mclk != 112000000 {
		t.Fatalf("Bad JTFRAME_MCLK for jtframe_pll7000 with SDRAM96. Got %d", mclk)
	}
	if got := Get("JTFRAME_MCLK"); got != "112000000" {
		t.Fatalf("Bad JTFRAME_MCLK macro. Got %s", got)
	}
	if !IsSet("JTFRAME_PLL7000") {
		t.Fatal("Expected JTFRAME_PLL7000 macro to be set")
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

func Test_make_credits_pages_boundaries(t *testing.T) {
	root := t.TempDir()
	t.Setenv("JTROOT", root)
	msgpath := filepath.Join(root, "cores", "msgcore", "cfg", "msg")
	if err := os.MkdirAll(filepath.Dir(msgpath), 0o755); err != nil {
		t.Fatal(err)
	}
	for _, tc := range []struct{ rows, pages int }{
		{0, 1}, {1, 1}, {32, 1}, {33, 2}, {96, 3}, {129, 5}, {512, 16}, {513, 17},
	} {
		contents := [][]byte{[]byte(strings.Repeat("\n", tc.rows))}
		if tc.rows > 0 {
			contents = append(contents, []byte(strings.Repeat("\n", tc.rows-1)+"row"))
		}
		for _, content := range contents {
			if err := os.WriteFile(msgpath, content, 0o644); err != nil {
				t.Fatal(err)
			}
			make_credits_pages("msgcore")
			if got := Get("JTFRAME_CREDITS_PAGES"); got != strconv.Itoa(tc.pages) {
				t.Fatalf("Expected %d pages for %d rows, got %s", tc.pages, tc.rows, got)
			}
			err := check_credits_pages()
			if tc.pages > 16 && err == nil {
				t.Fatalf("Expected %d pages to be rejected", tc.pages)
			}
			if tc.pages <= 16 && err != nil {
				t.Fatalf("Unexpected error for %d pages: %v", tc.pages, err)
			}
		}
	}
}

func Test_make_credits_pages_keeps_default_without_msg(t *testing.T) {
	root := t.TempDir()
	t.Setenv("JTROOT", root)
	Set("JTFRAME_CREDITS_PAGES", "3")
	make_credits_pages("missing")
	if got := Get("JTFRAME_CREDITS_PAGES"); got != "3" {
		t.Fatalf("Expected the 3-page fallback without cfg/msg, got %s", got)
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

func Test_check_macros_rejects_pll_tune_and_core_osd(t *testing.T) {
	MakeFromMap(map[string]string{
		"TARGET":           "mister",
		"JTFRAME_PLL_TUNE": "1",
		"CORE_OSD":         "ODF,Extra,Off,On;",
		"JTFRAME_WIDTH":    "320",
		"JTFRAME_HEIGHT":   "224",
	})
	if err := CheckMacros(); err == nil {
		t.Fatal("Expected JTFRAME_PLL_TUNE with CORE_OSD to be rejected")
	}
}

func Test_check_macros_accepts_pll_tune_with_empty_core_osd(t *testing.T) {
	MakeFromMap(map[string]string{
		"TARGET":             "mister",
		"JTFRAME_LF_BUFFER":  "1",
		"JTFRAME_LF_HW":      "9",
		"JTFRAME_LF_VW":      "8",
		"JTFRAME_MR_DDRLOAD": "1",
		"JTFRAME_PLL_TUNE":   "1",
		"CORE_OSD":           "",
		"JTFRAME_WIDTH":      "320",
		"JTFRAME_HEIGHT":     "224",
	})
	if err := CheckMacros(); err != nil {
		t.Fatalf("Expected an empty CORE_OSD with PLL tuning to be accepted: %v", err)
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
	if err := CheckMacros(); err != nil {
		t.Fatalf("Expected vertical lf-buffer combination to be accepted: %v", err)
	}
}

func Test_check_macros_lf_bram_requires_vertical(t *testing.T) {
	MakeFromMap(map[string]string{
		"TARGET":             "mister",
		"JTFRAME_LF_BUFFER":  "1",
		"JTFRAME_LF_HW":      "9",
		"JTFRAME_LF_VW":      "8",
		"JTFRAME_MR_LF_BRAM": "1",
		"JTFRAME_WIDTH":      "320",
		"JTFRAME_HEIGHT":     "224",
	})
	if err := CheckMacros(); err == nil {
		t.Fatal("Expected JTFRAME_MR_LF_BRAM without JTFRAME_VERTICAL to be rejected")
	}
}

func Test_make_mr_lf_bram_macro(t *testing.T) {
	MakeFromMap(map[string]string{
		"JTFRAME_LF_BUFFER": "1",
		"JTFRAME_VERTICAL":  "1",
	})
	make_mr_lf_bram_macro("mister")
	if !IsSet("JTFRAME_MR_LF_BRAM") {
		t.Fatal("Expected MiSTer vertical lf-buffer combination to select BRAM lf-buffer")
	}
}

func Test_check_macros_lf_buffer_vertical_pocket(t *testing.T) {
	MakeFromMap(map[string]string{
		"TARGET":            "pocket",
		"JTFRAME_LF_BUFFER": "1",
		"JTFRAME_LF_HW":     "9",
		"JTFRAME_LF_VW":     "8",
		"JTFRAME_VERTICAL":  "1",
		"JTFRAME_WIDTH":     "256",
		"JTFRAME_HEIGHT":    "224",
	})
	if err := CheckMacros(); err != nil {
		t.Fatalf("Expected non-MiSTer vertical lf-buffer combination to be accepted: %v", err)
	}
}

func Test_check_macros_lf_buffer_vertical_sidi128(t *testing.T) {
	MakeFromMap(map[string]string{
		"TARGET":            "sidi128",
		"JTFRAME_LF_BUFFER": "1",
		"JTFRAME_LF_HW":     "9",
		"JTFRAME_LF_VW":     "8",
		"JTFRAME_VERTICAL":  "1",
		"JTFRAME_WIDTH":     "256",
		"JTFRAME_HEIGHT":    "224",
	})
	if err := CheckMacros(); err != nil {
		t.Fatalf("Expected sidi128 vertical lf-buffer combination to be accepted: %v", err)
	}
}

func Test_check_macros_header_alignment(t *testing.T) {
	for _, test := range []struct {
		name   string
		header string
		valid  bool
	}{
		{"aligned", "4", true},
		{"zero", "0", true},
		{"misaligned", "1", false},
		{"nonnumeric", "bad", false},
	} {
		t.Run(test.name, func(t *testing.T) {
			MakeFromMap(map[string]string{
				"JTFRAME_HEADER": test.header,
				"JTFRAME_WIDTH":  "320",
				"JTFRAME_HEIGHT": "240",
				"JTFRAME_LF_HW":  "9",
				"JTFRAME_LF_VW":  "8",
			})
			err := CheckMacros()
			if test.valid && err != nil {
				t.Fatalf("Expected JTFRAME_HEADER=%s to be accepted: %v", test.header, err)
			}
			if !test.valid && err == nil {
				t.Fatalf("Expected JTFRAME_HEADER=%s to be rejected", test.header)
			}
		})
	}
}

func Test_remove_lf_buffer_rotation_conflict(t *testing.T) {
	MakeFromMap(map[string]string{
		"JTFRAME_LF_BUFFER":      "1",
		"JTFRAME_SDRAM_ROTATION": "1",
	})
	remove_lf_buffer_rotation_conflict()
	if IsSet("JTFRAME_SDRAM_ROTATION") {
		t.Fatal("Expected JTFRAME_SDRAM_ROTATION to be removed when LF buffer is enabled")
	}
}

func Test_keep_sdram_rotation_without_lf_buffer(t *testing.T) {
	MakeFromMap(map[string]string{
		"JTFRAME_SDRAM_ROTATION": "1",
	})
	remove_lf_buffer_rotation_conflict()
	if !IsSet("JTFRAME_SDRAM_ROTATION") {
		t.Fatal("Expected JTFRAME_SDRAM_ROTATION to remain when LF buffer is disabled")
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

func Test_check_macros_game_ddr_mister(t *testing.T) {
	MakeFromMap(map[string]string{
		"TARGET":              "mister",
		"JTFRAME_MR_GAME_DDR": "1",
		"JTFRAME_LF_HW":       "9",
		"JTFRAME_LF_VW":       "9",
		"JTFRAME_WIDTH":       "512",
		"JTFRAME_HEIGHT":      "400",
	})
	if err := CheckMacros(); err != nil {
		t.Fatalf("Expected JTFRAME_MR_GAME_DDR on MiSTer to be accepted: %v", err)
	}
}

func Test_check_macros_game_ddr_conflicts(t *testing.T) {
	for _, name := range []string{"JTFRAME_VERTICAL", "JTFRAME_LF_BUFFER", "JTFRAME_MR_DDRLOAD"} {
		MakeFromMap(map[string]string{
			"TARGET":              "mister",
			"JTFRAME_MR_GAME_DDR": "1",
			"JTFRAME_LF_HW":       "9",
			"JTFRAME_LF_VW":       "9",
			"JTFRAME_WIDTH":       "512",
			"JTFRAME_HEIGHT":      "400",
			name:                  "1",
		})
		if err := CheckMacros(); err == nil || !strings.Contains(err.Error(), "JTFRAME_MR_GAME_DDR") {
			t.Fatalf("Expected JTFRAME_MR_GAME_DDR with %s to be rejected", name)
		}
	}
}
