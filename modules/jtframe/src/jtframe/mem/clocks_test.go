package mem

import "testing"

func TestParseFreqScientific(t *testing.T) {
	cfg := ClockCfg{Freq: "8e6"}
	if e := cfg.parse_freq(); e != nil {
		t.Fatalf("parse_freq failed: %v", e)
	}
	if cfg.freq != 8e6 {
		t.Fatalf("expected 8e6 got %f", cfg.freq)
	}
}

func TestParseFreqEngineering(t *testing.T) {
	cfg := ClockCfg{Freq: "8M"}
	if e := cfg.parse_freq(); e != nil {
		t.Fatalf("parse_freq failed: %v", e)
	}
	if cfg.freq != 8e6 {
		t.Fatalf("expected 8e6 got %f", cfg.freq)
	}
	cfg = ClockCfg{Freq: "12.5kHz"}
	if e := cfg.parse_freq(); e != nil {
		t.Fatalf("parse_freq failed: %v", e)
	}
	if cfg.freq != 12500 {
		t.Fatalf("expected 12500 got %f", cfg.freq)
	}
	cfg = ClockCfg{Freq: "8 MHz"}
	if e := cfg.parse_freq(); e != nil {
		t.Fatalf("parse_freq failed: %v", e)
	}
	if cfg.freq != 8e6 {
		t.Fatalf("expected 8e6 got %f", cfg.freq)
	}
}

func TestParseFreqCaseSensitive(t *testing.T) {
	cfg := ClockCfg{Freq: "8m"}
	if e := cfg.parse_freq(); e == nil {
		t.Fatalf("8m should be rejected because it is below 1 Hz")
	}
}

func TestParseFreqRejectsLowValues(t *testing.T) {
	for _, input := range []string{"0", "0.5", "1e-3Hz"} {
		cfg := ClockCfg{Freq: input}
		if e := cfg.parse_freq(); e == nil {
			t.Fatalf("expected rejection for %s", input)
		}
	}
}

func TestParseFreqRejectsBadInput(t *testing.T) {
	for _, input := range []string{"8mhz", "Hz", "foo"} {
		cfg := ClockCfg{Freq: input}
		if e := cfg.parse_freq(); e == nil {
			t.Fatalf("expected parse error for %s", input)
		}
	}
}

func TestFindFactorsKeepsMulOneWithFreq(t *testing.T) {
	cfg := ClockCfg{Mul: 1, freq: 10e6}
	if e := cfg.find_factors(48e6); e != nil {
		t.Fatalf("find_factors failed: %v", e)
	}
	if cfg.Mul != 1 {
		t.Fatalf("expected mul to remain 1 got %d", cfg.Mul)
	}
	if cfg.Div != 5 {
		t.Fatalf("expected fixed-mul divider 5 got %d", cfg.Div)
	}
}

func TestFindFactorsUsesFullSearchWhenMulMissing(t *testing.T) {
	cfg := ClockCfg{freq: 10e6}
	if e := cfg.find_factors(48e6); e != nil {
		t.Fatalf("find_factors failed: %v", e)
	}
	if cfg.Mul != 5 || cfg.Div != 24 {
		t.Fatalf("expected unrestricted factors 5/24 got %d/%d", cfg.Mul, cfg.Div)
	}
}

func TestFindFactorsRejectsFreqWithMulAboveOne(t *testing.T) {
	cfg := ClockCfg{Mul: 2, freq: 10e6}
	if e := cfg.find_factors(48e6); e == nil {
		t.Fatalf("expected freq with mul above one to be rejected")
	}
}
