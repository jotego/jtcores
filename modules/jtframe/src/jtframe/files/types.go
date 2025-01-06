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

import(
	"github.com/jotego/jtframe/macros"
)

type Args struct {
	Corename string // JT core
	Parse    string // any file
	Rel      bool
	Local    bool
	Format   string
	Target   string
	AddMacro string // More macros, separated by commas
}

type FileList struct {
	Unless []string `yaml:"unless"` // parses the section "unless" the macro is defined
	When   []string `yaml:"when"`   // parses the section "when" the macro is defined

	From   string   `yaml:"from"`
	Get    []string `yaml:"get"`

	Ucode  UcDesc   `yaml:"ucode"`
}

type FileListGroup []FileList

type UcDesc struct {
	Src		string `yaml:"src"`
	Output  string `yaml:"output"`
	// private
	modname string
}
type UcFiles map[string]UcDesc // if this is changed to a non reference type, update the functions that take it as an argument

type JTFiles map[string]FileListGroup

func (item FileList) Enabled() bool {
    aux := macros.MacroEnabled{
        When: item.When,
        Unless: item.Unless,
    }
    return aux.Enabled()
}