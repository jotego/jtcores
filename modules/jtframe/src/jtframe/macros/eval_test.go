package macros

import "testing"

func Test_eval(t *testing.T) {
	MakeFromMap(map[string]string{
		"BAR":     "16",
		"BAZ":     "4",
		"GLOBAL":  "0x20",
		"FOO":     "23'h100",
		"SHIFT":   "(FOO>>1)",
		"COMBO":   "3<<8 | BAZ",
		"GLOBAL2": "`GLOBAL+4",
	})
	cases := map[string]int64{
		"0x10":            0x10,
		"23'h2_00000":     0x200000,
		"FOO+22'h20":      0x120,
		"(FOO>>1)+BAR":    0x90,
		"3<<8 | BAZ":      0x304,
		"SHIFT+GLOBAL2":   0x80 + 0x24,
		"`GLOBAL + COMBO": 0x20 + 0x304,
		"-4 + 10":         6,
	}
	for expr, expected := range cases {
		got, err := Eval(expr)
		if err != nil {
			t.Fatalf("Eval(%q) failed: %v", expr, err)
		}
		if got != expected {
			t.Fatalf("Eval(%q)=%d, wanted %d", expr, got, expected)
		}
	}
}

func Test_eval_rejects_bad_input(t *testing.T) {
	MakeFromMap(map[string]string{
		"A":      "B",
		"B":      "A",
		"BADHEX": "8'hx1",
	})
	cases := []string{
		"",
		"UNKNOWN",
		"(1+2",
		"BADHEX",
		"A",
	}
	for _, expr := range cases {
		if _, err := Eval(expr); err == nil {
			t.Fatalf("Eval(%q) should have failed", expr)
		}
	}
}
