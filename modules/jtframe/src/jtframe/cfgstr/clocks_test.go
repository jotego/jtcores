/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 5-11-2026 */

package cfgstr

import "testing"

func Test_pll_sim_period(t *testing.T) {
	for _, tc := range []struct {
		mclk    string
		doubled bool
		want    string
	}{
		{"48000000", false, "10.417"},
		{"96000000", true, "10.417"},
		{"49000000", false, "10.204"},
		{"56000000", false, "8.929"},
		{"54432000", false, "9.186"},
		{"108864000", true, "9.186"},
	} {
		def := map[string]string{"JTFRAME_MCLK": tc.mclk}
		if tc.doubled {
			def["JTFRAME_SDRAM96"] = "1"
		}
		if got := pll_sim_period(def); got != tc.want {
			t.Errorf("period for %s (doubled=%v) = %s, want %s", tc.mclk, tc.doubled, got, tc.want)
		}
	}
}
