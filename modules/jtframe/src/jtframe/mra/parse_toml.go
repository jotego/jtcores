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
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"

	"github.com/komkom/toml"
	"github.com/jotego/jtframe/macros"
)

func ParseTomlFile(corename string) (mra_cfg Mame2MRA,e error) {
	toml_path := TomlPath(corename)
	toml_file, e := os.Open(toml_path)
	if e != nil {
		return Mame2MRA{},e
	}
	defer toml_file.Close()
	return ParseToml(corename,toml_file)
}

func TomlPath(corename string) string {
	return filepath.Join(os.Getenv("CORES"), corename, "cfg", "mame2mra.toml")
}

func ParseToml(corename string, toml_file io.Reader) (mra_cfg Mame2MRA, e error) {
	if mra_cfg, e = NewMRAcfgFromTOML(toml_file); e!=nil {
		return Mame2MRA{},e
	}
	if len(mra_cfg.Global.Author)==0 {
		mra_cfg.Global.Author=[]string{"jotego"}
	}
	mra_cfg.apply_macros()
	if e = mra_cfg.prepare_regions(); e!=nil {
		return Mame2MRA{},fmt.Errorf("%w in core %s",e,corename)
	}
	return mra_cfg, nil
}

func NewMRAcfgFromTOML(toml_file io.Reader) (mra_cfg Mame2MRA, e error) {
	json_enc := toml.New(toml_file)
	dec := json.NewDecoder(json_enc)

	e = dec.Decode(&mra_cfg)
	if e != nil {
	    return mra_cfg, fmt.Errorf("problem while parsing TOML file after JSON transformation: %w", e)
	}
	return mra_cfg,nil
}

func (mra_cfg *Mame2MRA) apply_macros() {
	mra_cfg.Dipsw.base = macros.GetInt("JTFRAME_DIPBASE")
	// Set the number of buttons to the definition in the macros.def
	if mra_cfg.Buttons.Core == 0 {
		mra_cfg.Buttons.Core = macros.GetInt("JTFRAME_BUTTONS")
	}

	mra_cfg.Header.len = macros.GetInt("JTFRAME_HEADER")
	if len(mra_cfg.Dipsw.Delete) == 0 {
		mra_cfg.Dipsw.Delete = []DIPswDelete{
			{ Names: []string{"Unused", "Unknown"} },
		}
	}
	// Add the NVRAM section if it was in the .def file
	if macros.Get("JTFRAME_IOCTL_RD") != "" {
		aux := macros.GetInt("JTFRAME_IOCTL_RD")
		mra_cfg.ROM.Nvram.length = int(aux)
	}
}

// For each ROM region, set the no_offset flag if a
// sorting option was selected
// And translate the Start macro to the private start integer value
func (mra_cfg *Mame2MRA) prepare_regions() error {
	for k := 0; k < len(mra_cfg.ROM.Regions); k++ {
		this := &mra_cfg.ROM.Regions[k]
		if this.Start != "" {
			if !macros.IsInt(this.Start) {
				return fmt.Errorf("ROM region %s uses macro %s, but it is not defined or it is not an integer",
					this.Name, this.Start)
			}
			this.start = macros.GetInt(this.Start)
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
	return nil
}