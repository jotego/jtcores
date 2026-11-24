package cmd

import (
	"os"
	"path/filepath"
	"testing"
)

func TestSeedSTAAllCorners(t *testing.T) {
	cases := []struct {
		name   string
		report string
		want   float64
		valid  bool
	}{
		{"positive hot negative cold", "Info (332146): Worst-case setup slack is 0.154\nInfo (332146): Worst-case setup slack is -0.212\nInfo (332146): Worst-case setup slack is 2.100", -0.212, true},
		{"all positive", "Worst-case setup slack is 0.276\nWorst-case setup slack is 0.004\nWorst-case setup slack is 2.653", 0.004, true},
		{"worst first", "Worst-case setup slack is -0.466\nWorst-case setup slack is -0.100", -0.466, true},
		{"zero", "Worst-case setup slack is 0.000", 0, true},
		{"missing setup", "Worst-case hold slack is 0.100", 0, false},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got, valid := parse_seed_sta(tc.report)
			if got != tc.want || valid != tc.valid {
				t.Fatalf("got (%v, %v), want (%v, %v)", got, valid, tc.want, tc.valid)
			}
		})
	}
}

func TestSeedTimingAllCorners(t *testing.T) {
	report := "Worst-case setup slack is 0.148\nWorst-case hold slack is -0.027\nWorst-case recovery slack is 0.600\n" +
		"Worst-case setup slack is 0.223\nWorst-case hold slack is 0.083\nWorst-case recovery slack is -0.031\n"
	want := seed_timing{setup: "0.148", hold: "-0.027", recovery: "-0.031"}
	if got := parse_seed_timing(report); got != want {
		t.Fatalf("got %+v, want %+v", got, want)
	}
}

func TestSeedWorstTimingSlacks(t *testing.T) {
	dir := t.TempDir()
	reports := map[string]string{
		"cold.sta.rpt": "Worst-case setup slack is -0.212\nWorst-case hold slack is 0.100\nWorst-case recovery slack is 0.500\n",
		"hot.sta.rpt":  "Worst-case setup slack is 0.004\nWorst-case hold slack is -0.015\nWorst-case recovery slack is 0.200\n",
	}
	for name, text := range reports {
		if e := os.WriteFile(filepath.Join(dir, name), []byte(text), 0600); e != nil {
			t.Fatal(e)
		}
	}
	want := seed_timing{setup: "-0.212", hold: "-0.015", recovery: "0.200"}
	if got := worst_timing_slacks(dir); got != want {
		t.Fatalf("got %+v, want %+v", got, want)
	}
}

func TestSeedTimingMissingValues(t *testing.T) {
	want := seed_timing{setup: "0.100", hold: "n/a", recovery: "n/a"}
	if got := parse_seed_timing("Worst-case setup slack is 0.100"); got != want {
		t.Fatalf("got %+v, want %+v", got, want)
	}
}
