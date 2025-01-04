/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Date: 4-1-2025 */

package mem

import (
	"encoding/json"
	"slices"
	"testing"

	"github.com/jotego/jtframe/macros"

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
	macros.MakeFromMap(macros_debug_pocket)
	delete_optional_ioctl(cfg.BRAM)
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
	macros.MakeFromMap(macros_release_mister)
	delete_optional_ioctl(cfg.BRAM)
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
	macros.MakeFromMap(map[string]string{"WHEN_MACRO":""})
	if !bram.Enabled() { t.Errorf("Should have been enabled")}

	macros.MakeFromMap(map[string]string{"xx":""})
	if  bram.Enabled() { t.Errorf("Should have been disabled")}

	macros.MakeFromMap(nil)
	if  bram.Enabled() { t.Errorf("Should have been disabled")}
}

func Test_delete_optional_bram(t *testing.T) {
	sample:=`bram:
  - {name: always }
  - {name: not_pocket, unless: [ POCKET ] }
  - {name: only_pocket, when: [ POCKET ] }
`
	var cfg MemConfig
	if e:=yaml.Unmarshal([]byte(sample),&cfg); e!=nil { t.Error(e); return }
	macros.MakeFromMap(map[string]string{ "POCKET": "" })
	delete_optional_bram(&cfg)
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
	if len(cfg.SDRAM.Banks)!=3 { t.Errorf("Expecting 3 SDRAM banks"); return}
	for k:=0;k<3;k++ {
		if total:=len(cfg.SDRAM.Banks[k].Buses); total!=3 {
			t.Errorf("Expecting 3 SDRAM buses at bank %d. Found %d",k,total);
			return
		}
	}

	macros.MakeFromMap(map[string]string{ "POCKET": "" })
	delete_optional_sdram(&cfg)

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