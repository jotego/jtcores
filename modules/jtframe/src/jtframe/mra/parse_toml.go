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

package mra

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strconv"

	toml "github.com/komkom/toml"
	"github.com/jotego/jtframe/macros"
)

func TomlPath( corename string ) string {
	return filepath.Join(os.Getenv("CORES"), corename, "cfg", "mame2mra.toml")
}

func ParseToml( toml_path string, corename string) (mra_cfg Mame2MRA) {
	toml_file, err := os.ReadFile(toml_path)
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
	json_enc := toml.New(bytes.NewBuffer(toml_file))
	dec := json.NewDecoder(json_enc)

	err = dec.Decode(&mra_cfg)
	if err != nil {
	       fmt.Println("jtframe mra: problem while parsing TOML file after JSON transformation:\n\t", err)
	       fmt.Println(json_enc)
	       os.Exit(1)
	}

	if len(mra_cfg.Global.Author)==0 {
		mra_cfg.Global.Author=[]string{"jotego"}
	}
	mra_cfg.Dipsw.base = macros.GetInt("JTFRAME_DIPBASE")
	// Set the number of buttons to the definition in the macros.def
	if mra_cfg.Buttons.Core == 0 {
		mra_cfg.Buttons.Core = macros.GetInt("JTFRAME_BUTTONS")
	}

	if mra_cfg.Header.Len > 0 {
		fmt.Println(`The use of header.len in the TOML file is deprecated.
Set JTFRAME_HEADER=length in macros.def instead`)
	}
	aux := macros.GetInt("JTFRAME_HEADER")
	mra_cfg.Header.Len = int(aux)
	if len(mra_cfg.Dipsw.Delete) == 0 {
		mra_cfg.Dipsw.Delete = []DIPswDelete{
			{ Names: []string{"Unused", "Unknown"} },
		}
	}
	// Add the NVRAM section if it was in the .def file
	if macros.Get("JTFRAME_IOCTL_RD") != "" {
		aux := macros.GetInt("JTFRAME_IOCTL_RD")
		mra_cfg.ROM.Nvram.length = int(aux)
		if err != nil {
			fmt.Println("JTFRAME_IOCTL_RD was ill defined")
			fmt.Println(err)
		}
	}
	// For each ROM region, set the no_offset flag if a
	// sorting option was selected
	// And translate the Start macro to the private start integer value
	for k := 0; k < len(mra_cfg.ROM.Regions); k++ {
		this := &mra_cfg.ROM.Regions[k]
		if this.Start != "" {
			if !macros.IsSet(this.Start) {
				fmt.Printf("ERROR: ROM region %s uses undefined macro %s in core %s\n", this.Name, this.Start, corename)
				os.Exit(1)
			}
			start_str := macros.Get(this.Start)
			aux, err := strconv.ParseInt(start_str, 0, 64)
			if err != nil {
				fmt.Printf("ERROR: Macro %s is used as a ROM start, but its value (%s) is not a number\n",
					this.Start, start_str)
				os.Exit(1)
			}
			this.start = int(aux)
			if Verbose {
				fmt.Printf("Start in .ROM set to %X for region %s",this.start, this.Name)
				if this.Rename!="" { fmt.Printf(" (%s)",this.Rename)}
				fmt.Println()
			}
		}
		if  this.Sort_even ||
			this.Singleton || len(this.Ext_sort) > 0 ||
			len(this.Name_sort) > 0 || len(this.Sequence) > 0 {
			this.No_offset = true
		}
	}
	return mra_cfg
}