/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-1-2025 */

package files

import(
	"jotego/jtframe/macros"
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