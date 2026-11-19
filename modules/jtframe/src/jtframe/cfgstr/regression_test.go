package cfgstr

import (
	"os"
	"testing"
)

func Test_regression_macro_explicit_undef(t *testing.T) {
	if os.Getenv("JTROOT") == "" || os.Getenv("JTFRAME") == "" {
		t.Fatal("source setprj.sh before testing macro resolution")
	}
	cfg := Config{Core: "circus", Target: "mister"}
	if _, found := cfg.prepare_macros()["JTFRAME_REGRESSION"]; !found {
		t.Fatal("normal full-HDMI target should export JTFRAME_REGRESSION")
	}
	cfg.Discard = []string{"JTFRAME_REGRESSION"}
	if _, found := cfg.prepare_macros()["JTFRAME_REGRESSION"]; found {
		t.Fatal("explicit cfgstr --undef must remove the target default")
	}
}
