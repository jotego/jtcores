package common

import(
	"os"
	"path/filepath"
	"testing"
)

func Test_ConfigFilePath(t *testing.T) {
	cfg := ConfigFilePath("gng","mem.yaml")
	expected := filepath.Join(os.Getenv("JTROOT"),"cores","gng","cfg","mem.yaml")
	if cfg!=expected { t.Errorf("Path mismatch %s != %s",cfg,expected)}

	cfg = ConfigFilePath("1942","")
	expected = filepath.Join(os.Getenv("JTROOT"),"cores","1942","cfg")
	if cfg!=expected { t.Errorf("Path mismatch %s != %s",cfg,expected)}
}