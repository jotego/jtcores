package mra

import(
	"testing"
)

func Test_get_first_match(t *testing.T) {
	cfg := []Selectable{
		Selectable{ Machine:"scontra"  },
		Selectable{ Machine:"thunderx" },
		Selectable{ Machine:"crimfght" },
		Selectable{ Machine:"gbusters" },
	}

	const exp=2
	machine := MachineXML{
		Name: cfg[exp].Machine,
	}
	if k:=machine.Find(cfg);k!=exp {
		t.Errorf("Expecting %d, got %d",exp,k)
	}

	const unknown = -1
	machine.Name="none"
	if k:=machine.Find(cfg);k!=unknown {
		t.Errorf("Expecting %d, got %d",unknown,k)
	}
}