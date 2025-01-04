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

package files

type Args struct {
	Corename string // JT core
	Parse    string // any file
	Rel      bool
	Local    bool
	Format   string
	Target   string
	AddMacro string // More macros, separated by commas
}

type Origin int

const (
	GAME Origin = iota
	FRAME
	TARGET
	MODULE
	JTMODULE
)

type FileList struct {
	From   string   `yaml:"from"`
	Get    []string `yaml:"get"`
	Unless string   `yaml:"unless"` // parses the section "unless" the macro is defined
	When   string   `yaml:"when"`   // parses the section "when" the macro is defined
}

type JTModule struct {
	Name   string `yaml:"name"`
	Unless string `yaml:"unless"`
	When   string   `yaml:"when"`
}

type UcDesc struct {
	Src		string `yaml:"src"`
	Output  string `yaml:"output"`
	// private
	modname string
}
type UcFiles map[string]UcDesc // if this is changed to a non reference type, update the functions that take it as an argument

type JTFiles struct {
	Game    []FileList `yaml:"game"`
	JTFrame []FileList `yaml:"jtframe"`
	Target  []FileList `yaml:"target"`
	Modules struct {
		JT    []JTModule `yaml:"jt"`
		Other []FileList `yaml:"other"`
	} `yaml:"modules"`
	Here []string `yaml:"here"`
	Ucode UcFiles `yaml:"ucode"`
}
