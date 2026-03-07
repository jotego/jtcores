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
