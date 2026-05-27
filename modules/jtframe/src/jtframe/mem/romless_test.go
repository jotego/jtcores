package mem

import (
	"os"
	"path/filepath"
	"testing"

	"jotego/jtframe/macros"
)

func TestBankOffsetAllowsMissingMame2MraToml(t *testing.T) {
	t.Setenv("CORES", t.TempDir())

	var cfg MemConfig
	if err := bankOffset(&cfg, "romless"); err != nil {
		t.Fatal(err)
	}
	if cfg.Balut != 0 || cfg.Lutsh != 0 {
		t.Fatalf("missing TOML should not enable header offset: %+v", cfg)
	}
}

func TestBankOffsetCopiesHeaderReverse(t *testing.T) {
	tmp := t.TempDir()
	t.Setenv("CORES", tmp)

	for _, tc := range []struct {
		name        string
		tomlReverse string
		wantReverse bool
	}{
		{name: "forward", tomlReverse: "false", wantReverse: false},
		{name: "reverse", tomlReverse: "true", wantReverse: true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			core := "header_" + tc.name
			cfgDir := filepath.Join(tmp, core, "cfg")
			if err := os.MkdirAll(cfgDir, 0755); err != nil {
				t.Fatal(err)
			}
			toml := "[header]\n" +
				"offset = { bits=12, reverse=" + tc.tomlReverse + ", regions=[\"maincpu\",\"gfx\"] }\n"
			if err := os.WriteFile(filepath.Join(cfgDir, "mame2mra.toml"), []byte(toml), 0644); err != nil {
				t.Fatal(err)
			}

			var cfg MemConfig
			if err := bankOffset(&cfg, core); err != nil {
				t.Fatal(err)
			}
			if cfg.Balut != 1 || cfg.Lutsh != 12 || cfg.BalutReverse != tc.wantReverse {
				t.Fatalf("wrong header offset config: %+v", cfg)
			}
		})
	}
}

func TestRomlessSingleCacheLaneWithFlush(t *testing.T) {
	cfg := MemConfig{
		SDRAM: SDRAMCfg{
			Burst: "1kB",
			Cache_lanes: []SDRAMCacheLine{{
				Name:       "cpu",
				Data_width: 8,
				Rw:         true,
				Flush:      SDRAMCacheFlush{Enable: true},
				Blocks:     SDRAMCacheCfg{Count: 1, Size: "1kB"},
				At:         SDRAMCacheAddr{Bank: 0, Length: "16MB"},
			}},
		},
	}
	macros.MakeFromMap(map[string]string{"JTFRAME_SDRAM_LARGE": ""})
	if e := cfg.check_sdram(); e != nil {
		t.Fatal(e)
	}
	if got := cfg.SDRAM.Burst_len; got != 1024 {
		t.Fatalf("wrong burst length: got %d, want 1024", got)
	}
	line := cfg.SDRAM.Cache_lanes[0]
	if !line.Rw || !line.Flush.Enable {
		t.Fatalf("single cache lane lost rw/flush settings: %+v", line)
	}
}
