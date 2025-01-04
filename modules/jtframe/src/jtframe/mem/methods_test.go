package mem

import (
	"testing"

	"github.com/jotego/jtframe/macros"
)

func TestEnabled(t *testing.T) {
	Verbose=true
	item := MacroEnabled{
		When: []string{"ENABLE"},
		Unless: []string{"DISABLE"},
	}
	macros.MakeFromMap(map[string]string{"ENABLE":""})
	if !item.Enabled()  { t.Error("Disabled when it should not"); return }
	macros.MakeFromMap(map[string]string{"DISABLE":""})
	macros.Set("DISABLE","")
	macros.MakeFromMap(nil)
	if  item.Enabled() { t.Error("Enabled when it should not"); return }
	Verbose=false
}