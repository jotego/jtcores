package mem

import (
	"encoding/json"
	"slices"
	"testing"

	"gopkg.in/yaml.v2"
)

func TestDelete_optional_IOCTL( t *testing.T ) {
	cfg := MemConfig{
		BRAM: []BRAMBus{
			BRAMBus{
				Name: "onlydebug",
				Ioctl: BRAMBus_Ioctl{
					Order: 0,
					Restore: true,
					Unless: []string{"JTFRAME_RELEASE"},
				},
			},
			BRAMBus{
				Name: "onlyrelease",
				Ioctl: BRAMBus_Ioctl{
					Order: 0,
					Restore: true,
					When: []string{"JTFRAME_RELEASE"},
				},
			},
			BRAMBus{
				Name: "onlypocket",
				Ioctl: BRAMBus_Ioctl{
					Order: 1,
					Restore: true,
					When: []string{"POCKET"},
				},
			},
		},
	}
	copy, e := json.Marshal(cfg)
	if e!=nil { t.Error(e); return }
	macros_debug_pocket:=map[string]string{
		"POCKET": "",
	}

	delete_optional_ioctl(cfg.BRAM,macros_debug_pocket)
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
	delete_optional_ioctl(cfg.BRAM,macros_release_mister)
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

func Test_BRAMBus_When_Unless(t *testing.T) {
	sample := `name: sample_BRAM
when: [ WHEN_MACRO ]
unless: [ UNLESS_MACRO ]
rw: true
`
	var bram BRAMBus
	if e:=yaml.Unmarshal([]byte(sample),&bram); e!=nil { t.Error(e) }
	if bram.Name!="sample_BRAM" { t.Errorf("Bad name: %s",bram.Name)}
	if slices.Compare(bram.When,[]string{"WHEN_MACRO"})!=0 { t.Errorf("Bad 'when' field: %s",bram.When)}
	if slices.Compare(bram.Unless,[]string{"UNLESS_MACRO"})!=0 { t.Errorf("Bad 'unless' field: %s",bram.Unless)}
	if !bram.Rw { t.Errorf("Bad RW (should be true)")}
	if !bram.Enabled(map[string]string{"WHEN_MACRO":""}) { t.Errorf("Should have been enabled")}
	if  bram.Enabled(map[string]string{"xx":""}) { t.Errorf("Should have been disabled")}
	if  bram.Enabled(nil) { t.Errorf("Should have been disabled")}
}

func Test_delete_optional_bram(t *testing.T) {
	sample:=`bram:
  - {name: always }
  - {name: not_pocket, unless: [ POCKET ] }
  - {name: only_pocket, when: [ POCKET ] }
`
	var cfg MemConfig
	if e:=yaml.Unmarshal([]byte(sample),&cfg); e!=nil { t.Error(e); return }
	macros := map[string]string{ "POCKET": "" }
	delete_optional_bram(&cfg,macros)
	var always, not_pocket, only_pocket bool
	for _,bram := range cfg.BRAM {
		switch bram.Name {
			case "always": always=true
			case "not_pocket": not_pocket=true
			case "only_pocket": only_pocket=true
		}
	}
	if total:=len(cfg.BRAM);total!=2 { t.Errorf("Expecting 2 elements, found %d",total)}
	if !always { t.Error("Missing 'always'")}
	if not_pocket { t.Error("'not_pocket' should not appear")}
	if !only_pocket { t.Error("missing 'only_pocket")}
}

func Test_delete_optional_sdram(t *testing.T) {
	sample:=`sdram:
  banks:
    - buses:
      - {name: always }
      - {name: not_pocket, unless: [ POCKET ] }
      - {name: only_pocket, when: [ POCKET ] }
    - buses:
      - {name: always }
      - {name: not_pocket, unless: [ POCKET ] }
      - {name: only_pocket, when: [ POCKET ] }
    - buses:
      - {name: not_pocket1, unless: [ POCKET ] }
      - {name: not_pocket2, unless: [ POCKET ] }
      - {name: not_pocket3, unless: [ POCKET ] }
`
	var cfg MemConfig
	if e:=yaml.Unmarshal([]byte(sample),&cfg); e!=nil { t.Error(e); return }
	macros := map[string]string{ "POCKET": "" }
	if len(cfg.SDRAM.Banks)!=3 { t.Errorf("Expecting 3 SDRAM banks"); return}
	for k:=0;k<3;k++ {
		if total:=len(cfg.SDRAM.Banks[k].Buses); total!=3 {
			t.Errorf("Expecting 3 SDRAM buses at bank %d. Found %d",k,total);
			return
		}
	}

	delete_optional_sdram(&cfg,macros)

	if len(cfg.SDRAM.Banks)!=3 { t.Errorf("Expecting 3 SDRAM banks"); return }
	for k:=0;k<2;k++ {
		if total:=len(cfg.SDRAM.Banks[k].Buses); total!=2 {
			t.Errorf("Expecting 2 SDRAM buses at bank %d. Found %d",k,total);
			return
		}
	}
	if len(cfg.SDRAM.Banks[2].Buses)!=0 {
		t.Errorf("Bank 2 should be empty")
	}

	var always, not_pocket, only_pocket bool
	for k:=0;k<2;k++  {
		for _, bus := range cfg.SDRAM.Banks[k].Buses {
			t.Logf("bank[%d]: %s",k,bus.Name)
			switch bus.Name {
				case "always": always=true
				case "not_pocket": not_pocket=true
				case "only_pocket": only_pocket=true
			}
		}
		if !always { t.Errorf("Missing 'always' at bank %d",k)}
		if not_pocket { t.Errorf("'not_pocket' should not appear at bank %d",k)}
		if !only_pocket { t.Errorf("missing 'only_pocket at bank %d",k)}
	}
}

func Test_empty_bank(t *testing.T) {
	mem_yaml := `
sdram:
  banks:
    -
    - buses:
        - name: cart0
`
	var cfg MemConfig
	e := unmarshal([]byte(mem_yaml),&cfg)
	if e!=nil { t.Error(e); return }
	if total:=len(cfg.SDRAM.Banks);total!=2 {t.Errorf("Expecting 2 banks, got %d",total); return}
	if total:=len(cfg.SDRAM.Banks[1].Buses);total!=1 {t.Errorf("Expecting 2 buses on bank 1, got %d",total); return}
	if cfg.SDRAM.Banks[1].Buses[0].Name!="cart0" { t.Error("Bus 0 of Bank 1 is not named cart0") }
}