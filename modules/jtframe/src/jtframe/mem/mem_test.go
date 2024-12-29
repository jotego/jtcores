package mem

import (
	"testing"
	"encoding/json"
)

func TestDelete_optional_IOCTL( t *testing.T ) {
	cfg := MemConfig{
		BRAM: []BRAMBus{
			BRAMBus{
				Name: "onlydebug",
				Ioctl: BRAMBus_Ioctl{
					Order: 0,
					Restore: true,
					MacroEnabled: MacroEnabled{Unless: []string{"JTFRAME_RELEASE"}},
				},
			},
			BRAMBus{
				Name: "onlyrelease",
				Ioctl: BRAMBus_Ioctl{
					Order: 0,
					Restore: true,
					MacroEnabled: MacroEnabled{When: []string{"JTFRAME_RELEASE"}},
				},
			},
			BRAMBus{
				Name: "onlypocket",
				Ioctl: BRAMBus_Ioctl{
					Order: 1,
					Restore: true,
					MacroEnabled: MacroEnabled{When: []string{"POCKET"}},
				},
			},
		},
	}
	copy, e := json.Marshal(cfg)
	if e!=nil { t.Error(e); return }
	macros_debug_pocket:=map[string]string{
		"POCKET": "",
	}

	delete_optional(&cfg,macros_debug_pocket)
	if count_ioctl_buses(cfg.BRAM,t)!=2 {
		show_ioctl(cfg.BRAM,t)
		t.Error("Expected only entries for POCKET and debug")
	}

	macros_release_mister:=map[string]string{
		"MISTER": "",
		"JTFRAME_RELEASE": "",
	}

	// restores the test data
	if e := json.Unmarshal(copy,&cfg); e!=nil { t.Error(e); return }
	delete_optional(&cfg,macros_release_mister)
	if count:=count_ioctl_buses(cfg.BRAM,t);count!=1 {
		t.Logf("Found %d IOCTL buses.\nDump",count)
		show_ioctl(cfg.BRAM,t)
		t.Error("Expected only the entry for MiSTer")
	}
}

func count_ioctl_buses(bram_buses []BRAMBus, t *testing.T) int {
	total := 0
	for _,bus := range bram_buses {
		if bus.Ioctl.Save || bus.Ioctl.Restore || bus.Ioctl.Order>0 {
			t.Log(bus.Name)
			total++
		}
	}
	return total
}

func show_ioctl( bram_buses []BRAMBus, t *testing.T) {
	for _,bus := range bram_buses {
		t.Log(bus.Name)
		t.Log(bus.Ioctl)
	}
}
