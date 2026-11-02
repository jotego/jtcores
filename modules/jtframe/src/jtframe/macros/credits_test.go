package macros

import (
	"os"
	"path/filepath"
	"testing"
)

func Test_credits_target_defaults(t *testing.T) {
	for _, release := range []bool{false, true} {
		for _, tc := range []struct {
			target  string
			credits bool
		}{
			{"mist", false}, {"sidi", false},
			{"mister", true}, {"sidi128", true}, {"pocket", true},
		} {
			var extra []string
			if release {
				extra = append(extra, JTFRAME_RELEASE)
			}
			want := tc.credits && release
			for _, core := range []string{"1942", "gals", "slap", "roller", "88game", "flstory", "karnov"} {
				// These cores have cfg/msg but rely on target credits defaults.
				MakeMacros(core, tc.target, extra...)
				if got := IsSet(JTFRAME_CREDITS); got != want {
					t.Errorf("core=%s target=%s release=%v: credits=%v, want %v", core, tc.target, release, got, want)
				}
			}
		}
	}
}

func Test_credits_core_definitions(t *testing.T) {
	MakeMacros("1942", "sidi", JTFRAME_CREDITS)
	if !IsSet(JTFRAME_CREDITS) {
		t.Fatal("Command line must be able to enable credits on SiDi")
	}
	frame := t.TempDir()
	t.Setenv("JTFRAME", frame)
	defpath := filepath.Join(frame, "target", "sidi", "target.def")
	if err := os.MkdirAll(filepath.Dir(defpath), 0o755); err != nil {
		t.Fatal(err)
	}
	core_def := filepath.Join(frame, "macros.def")
	for _, tc := range []struct {
		target_def string
		core_def   string
		release    bool
		credits    bool
	}{
		{"release JTFRAME_CREDITS\n", "-JTFRAME_CREDITS\n", true, false},
		{"", "release JTFRAME_CREDITS\n", true, true},
		{"", "release JTFRAME_CREDITS\n", false, false},
	} {
		MakeFromMap(map[string]string{})
		if tc.release {
			Set(JTFRAME_RELEASE, "1")
		}
		if err := os.WriteFile(defpath, []byte(tc.target_def), 0o644); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(core_def, []byte(tc.core_def), 0o644); err != nil {
			t.Fatal(err)
		}
		read_target_macros("sidi")
		parse_def(core_def, "sidi")
		if got := IsSet(JTFRAME_CREDITS); got != tc.credits {
			t.Errorf("target=%q core=%q release=%v: credits=%v, want %v", tc.target_def, tc.core_def, tc.release, got, tc.credits)
		}
	}
}
