package mem

import "testing"

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
