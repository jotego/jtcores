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
	if IsSet("JTFRAME_LF_BUFFER") && IsSet("JTFRAME_MR_DDRLOAD") {
		return fmt.Errorf("jtframe: cannot define both JTFRAME_LF_BUFFER and JTFRAME_MR_DDRLOAD")
	}
	if IsSet("JTFRAME_JOY1_POS") && GetInt("JTFRAME_DIPBASE")<20 {
		return fmt.Errorf("jtframe: JTFRAME_JOY1_POS requires JTFRAME_DIPBASE to be at least 20")
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
	if e:=check_integer("JTFRAME_WIDTH","JTFRAME_HEIGHT"); e!=nil {
		return e
	}
	return nil
}