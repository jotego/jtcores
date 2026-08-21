/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-1-2025 */

package macros

import(
	"fmt"
	"strconv"
	"strings"
)

const JTFRAME_RELEASE="JTFRAME_RELEASE"
const JTFRAME_CREDITS="JTFRAME_CREDITS"

var macros map[string]string

type MacroEnabled struct{
    When    []string `yaml:"when"`
    Unless  []string `yaml:"unless"`
}

func IsSet( name string ) (set bool) {
	_, set = macros[name]
	return set
}

func Get(name string) (value string) {
	value, _ = macros[name]
	return value
}

func GetInt(name string) (int) {
	as_string, _ := macros[name]
	if as_string=="" { return 0 }
	value, e := strconv.ParseInt(as_string,0,64)
	if e!=nil {
		panic(fmt.Errorf("Tried to parse macro %s=%s as integer",name,as_string))
	}
	return int(value)
}

func IsInt(name string) bool {
	val := Get(name)
	if val=="" { return false }
	_, e := strconv.ParseInt( val, 0, 64 )
	return e==nil
}

func Set(name, value string) {
	macros[strings.ToUpper(name)]=value
}

func Remove(all_names ...string) {
	for _, name := range all_names {
		delete(macros,name)
	}
}

func CopyToMap() (copy map[string]string) {
	copy = make(map[string]string)
	for key,val := range macros {
		copy[key]=val
	}
	return copy
}

func AddKeyValPairs( key_val ...string ) {
	for _, def := range key_val {
		split := strings.SplitN(def, "=", 2)
		var name, val string
		if len(split) >= 1 {
			name = split[0]
		}
		if name=="" { continue }
		if len(split) == 2 {
			val = split[1]
		} else {
			val="1"
		}
		Set(name,val)
	}
}

// Mostly meant to be used for unit tests
func MakeFromMap(ref map[string]string) {
	macros = make(map[string]string)
	for key,val := range ref {
		macros[key]=val
	}
}

func (item *MacroEnabled) Enabled() bool {
    for _,disabler := range item.Unless {
        if IsSet(disabler) {
            // if verbose { fmt.Printf("Disabled because %s was set\n",disabler)}
            return false
        }
    }
    for _,enabler := range item.When {
        if IsSet(enabler) {
            // if verbose { fmt.Printf("Enabled because %s was set\n",enabler)}
            return true
        }
    }
    return len(item.When)==0
}

// check incompatible macro settings
func CheckMacros() error {
	if IsSet("JTFRAME_PLL_TUNE") && Get("CORE_OSD") != "" {
		return fmt.Errorf("jtframe: JTFRAME_PLL_TUNE and CORE_OSD are incompatible because both use status bits 13:15")
	}
	// Check that MiST DIPs are defined after the
	// last used status bit
	dipbase, _ := strconv.Atoi(Get("JTFRAME_DIPBASE"))
	if target_uses_dipbase(Get("TARGET")) {
		if IsSet("JTFRAME_AUTOFIRE0") && dipbase < 17 {
			return fmt.Errorf("MiST DIP base is smaller than the required value by JTFRAME_AUTOFIRE0")
		}
		if IsSet("JTFRAME_OSD_TEST") && dipbase < 11 {
			return fmt.Errorf("MiST DIP base is smaller than the required value by JTFRAME_OSD_TEST")
		}
	}
	if IsSet("JTFRAME_MR_LF_BRAM") && !IsSet("JTFRAME_VERTICAL") {
		return fmt.Errorf("jtframe: JTFRAME_MR_LF_BRAM requires JTFRAME_VERTICAL")
	}
	if IsSet("JTFRAME_JOY1_POS") && GetInt("JTFRAME_DIPBASE")<20 {
		return fmt.Errorf("jtframe: JTFRAME_JOY1_POS requires JTFRAME_DIPBASE to be at least 20")
	}
	if IsSet("JTFRAME_SDRAM_XL") && IsSet("JTFRAME_SDRAM_LARGE") {
		return fmt.Errorf("jtframe: cannot define both JTFRAME_SDRAM_XL and JTFRAME_SDRAM_LARGE")
	}
	if IsSet("JTFRAME_SDRAM_XL") {
		for _, name := range []string{"JTFRAME_BA1_START", "JTFRAME_BA2_START", "JTFRAME_BA3_START"} {
			if IsSet(name) {
				return fmt.Errorf("jtframe: %s cannot be defined with JTFRAME_SDRAM_XL; use header.offset in mame2mra.toml", name)
			}
		}
	}
	// sim macros
	maxframe_str   := Get("MAXFRAME")
	dumpstart_str  := Get("DUMP_START")
	maxframe, _ := strconv.Atoi(maxframe_str)
	dumpstart,_ := strconv.Atoi(dumpstart_str)
	if dumpstart > maxframe {
		return fmt.Errorf("Set a frame start for dumping within the simulation range")
	}
	if IsSet("JTFRAME_HEADER") && !IsInt("JTFRAME_HEADER") {
		header := Get("JTFRAME_HEADER")
		return fmt.Errorf("Cannot parse JTFRAME_HEADER=%s\n", header )
	}
	if IsSet("JTFRAME_HEADER") && GetInt("JTFRAME_HEADER")%4!=0 {
		return fmt.Errorf("jtframe: JTFRAME_HEADER must be a multiple of four for Analogue Pocket compatibility")
	}
	if e:=check_integer("JTFRAME_WIDTH","JTFRAME_HEIGHT","JTFRAME_LF_HW","JTFRAME_LF_VW"); e!=nil {
		return e
	}
	return nil
}
