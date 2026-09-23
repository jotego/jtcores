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

func TestSeedWorstSetupSlack(t *testing.T) {
	dir := t.TempDir()
	reports := map[string]string{
		"cold.sta.rpt": "Worst-case setup slack is 0.154\nWorst-case setup slack is -0.212\n",
		"hot.sta.rpt":  "Worst-case setup slack is 0.276\nWorst-case setup slack is 0.004\n",
	}
	for name, text := range reports {
		if e := os.WriteFile(filepath.Join(dir, name), []byte(text), 0600); e != nil {
			t.Fatal(e)
		}
	}
	if got := worst_setup_slack(dir); got != "-0.212" {
		t.Fatalf("got %s, want -0.212", got)
	}
}
