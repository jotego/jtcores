/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-1-2025 */

package mem

import (
	"testing"

	"jotego/jtframe/macros"
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