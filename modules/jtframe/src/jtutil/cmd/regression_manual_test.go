/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package cmd

import "testing"

func TestManualRegressionSelection(t *testing.T) {
	for _, tc := range []struct {
		core, set, manifest, run    string
		retry, valid, manual, jtbin bool
	}{
		{valid: true},
		{jtbin: true},
		{core: "shouse", set: "splatter", jtbin: true, valid: true, manual: true}, {core: "shouse", valid: true, manual: true}, {core: "shouse", set: "splatter", valid: true, manual: true},
		{core: "1942", set: "1942a", valid: true, manual: true}, {set: "splatter"}, {core: "../shouse"}, {core: "shouse", set: "x\nSITE LOAD bad"},
		{core: "shouse", manifest: "manifest.json"}, {core: "shouse", run: "676"}, {core: "shouse", retry: true},
		{manifest: "manifest.json", run: "676", retry: true, valid: true},
	} {
		manual, err := validate_regression_selection(tc.core, tc.set, tc.manifest, tc.run, tc.retry, tc.jtbin)
		if (err == nil) != tc.valid || err == nil && manual != tc.manual {
			t.Fatalf("selection %+v =>manual%v err%v", tc, manual, err)
		}
	}
}
