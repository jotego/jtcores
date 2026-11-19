package macros

import (
	"os"
	"path/filepath"
	"testing"
)

func Test_mister_regression_target_policy(t *testing.T) {
	for _, tc := range []struct {
		name   string
		target string
		extra []string
		want   bool
	}{
		{"normal mister", "mister", nil, true},
		{"quick keeps HDMI", "mister", []string{"NOSOUND", "JTFRAME_OSD_NOLOGO", "JTFRAME_NOSTA"}, true},
		{"mrq hard disables", "mister", []string{"JTFRAME_REGRESSION", "MISTER_DEBUG_NOHDMI"}, false},
		{"explicit no-HDMI with value zero disables", "mister", []string{"MISTER_DEBUG_NOHDMI=0"}, false},
		{"zero regression value remains defined", "mister", []string{"JTFRAME_REGRESSION=0"}, true},
		{"mist has no default", "mist", nil, false},
		{"sidi has no default", "sidi", nil, false},
		{"sidi128 has no default", "sidi128", nil, false},
		{"pocket has no default", "pocket", nil, false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			MakeMacros("circus", tc.target, tc.extra...)
			if got := IsSet(JTFRAME_REGRESSION); got != tc.want {
				t.Fatalf("JTFRAME_REGRESSION defined=%v, want %v", got, tc.want)
			}
		})
	}
}

func Test_mister_regression_can_be_removed_by_core_definition(t *testing.T) {
	frame := t.TempDir()
	root := t.TempDir()
	t.Setenv("JTFRAME", frame)
	t.Setenv("JTROOT", root)
	target_def := filepath.Join(frame, "target", "mister", "target.def")
	core_def := filepath.Join(root, "cores", "fixture", "cfg", "macros.def")
	if err := os.MkdirAll(filepath.Dir(target_def), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Dir(core_def), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(target_def, []byte(JTFRAME_REGRESSION+"\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(core_def, []byte("-"+JTFRAME_REGRESSION+"\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	MakeFromMap(map[string]string{})
	read_target_macros("mister")
	parse_def(core_def, "mister")
	remove_regression_without_hdmi("mister")
	if IsSet(JTFRAME_REGRESSION) {
		t.Fatal("core -JTFRAME_REGRESSION must remove the target default")
	}
}

func Test_mister_regression_removed_with_ddr_video(t *testing.T) {
	for _, tc := range []struct {
		name  string
		extra []string
		want  bool
	}{
		{"plain core", nil, true},
		{"LF buffer in DDR", []string{"JTFRAME_LF_BUFFER"}, false},
		{"vertical LF buffer moves to BRAM", []string{"JTFRAME_LF_BUFFER", "JTFRAME_VERTICAL"}, true},
		{"game DDR", []string{"JTFRAME_MR_GAME_DDR"}, false},
		{"vertical without LF buffer", []string{"JTFRAME_VERTICAL"}, true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			MakeMacros("gng", "mister", tc.extra...)  // gng is horizontal
			if got := IsSet(JTFRAME_REGRESSION); got != tc.want {
				t.Fatalf("JTFRAME_REGRESSION defined=%v, want %v", got, tc.want)
			}
		})
	}
}

func Test_ddr_video_policy_only_on_mister(t *testing.T) {
	MakeFromMap(map[string]string{JTFRAME_REGRESSION: "", "JTFRAME_LF_BUFFER": ""})
	remove_regression_with_ddr_video("sidi128")
	if !IsSet(JTFRAME_REGRESSION) {
		t.Fatal("non-MiSTer targets must keep their regression macro")
	}
}
