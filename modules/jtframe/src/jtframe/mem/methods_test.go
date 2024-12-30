package mem

import (
	"testing"
)


func TestEnabled(t *testing.T) {
	verbose=true
	item := MacroEnabled{
		When: []string{"ENABLE"},
		Unless: []string{"DISABLE"},
	}
	enable_macros := map[string]string{
		"ENABLE": "",
	}
	disable_macros :=map[string]string{
		"DISABLE": "",
	}
	var empty MacroEnabled
	if !item.Enabled(enable_macros)  { t.Error("Disabled when it should not"); return }
	if  item.Enabled(disable_macros) { t.Error("Enabled when it should not"); return }
	if !empty.Enabled(nil)           { t.Error("Disabled for empty set of macros"); return }
	verbose=false
}