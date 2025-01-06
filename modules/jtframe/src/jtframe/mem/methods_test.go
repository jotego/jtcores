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
	"testing"

	"github.com/jotego/jtframe/macros"
)

func TestEnabled(t *testing.T) {
	Verbose=true
	item := macros.MacroEnabled{
		When: []string{"ENABLE"},
		Unless: []string{"DISABLE"},
	}
	macros.MakeFromMap(map[string]string{"ENABLE":""})
	if !item.Enabled()  { t.Error("Disabled when it should not"); return }
	macros.MakeFromMap(map[string]string{"DISABLE":""})
	macros.Set("DISABLE","")
	macros.MakeFromMap(nil)
	if  item.Enabled() { t.Error("Enabled when it should not"); return }
	Verbose=false
}