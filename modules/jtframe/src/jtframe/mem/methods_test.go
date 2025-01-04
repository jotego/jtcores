package mem

import (
	"testing"

	"github.com/jotego/jtframe/def"
)

func TestEnabled(t *testing.T) {
	verbose=true
	item := MacroEnabled{
		When: []string{"ENABLE"},
		Unless: []string{"DISABLE"},
	}
	def.MakeFromMap(map[string]string{"ENABLE":""})
	if !item.Enabled()  { t.Error("Disabled when it should not"); return }
	def.MakeFromMap(map[string]string{"DISABLE":""})
	def.Macros.Set("DISABLE","")
	def.MakeFromMap(nil)
	if  item.Enabled() { t.Error("Enabled when it should not"); return }
	verbose=false
}