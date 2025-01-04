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
	"strings"
	"testing"
)

func TestCalcA(t *testing.T) {
	rc := AudioRC{ R: "1k", C: "159.15n" };
	const fs=float64(192000)
	const bits=15
	var a string
	var fc int
	a,fc=calc_a(rc,fs,bits)
	if fc!=1000 { t.Errorf("Got %d expected 1000",fc) }
	if a!="7BE0" { t.Errorf("Got %s expected 7BE0",a) }
	rc.R = "1k"
	rc.C = "15.915n";
	a,fc=calc_a(rc,fs,bits)
	if fc!=10000 { t.Errorf("Got %d expected 10000",fc) }
	if a!="5BB9" { t.Errorf("Got %s expected 5BB9",a) }
	// higher than fs/2
	rc.R = "1k"
	rc.C = "1n"
	a,fc=calc_a(rc,fs,bits)
	if fc!=159155 { t.Errorf("Got %d expected 159155",fc) }
	if a!="0000" { t.Errorf("Got %s expected 0000",a) }
}

func TestMake_rc(t *testing.T) {
	ch := AudioCh{
		RC: []AudioRC{
			{ R: "1k", C: "10n" }, // 15.915 kHz
			{ R: "5k", C: "10n" }, //  3.183 kHz
		},
	}
	const fs=float64(192000)
	make_rc(&ch,fs)
	if( ch.Filters!=1 ) { t.Errorf("Expecting 1 filter, got %d",ch.Filters) }
	if( ch.Fcut[0]!=15915 ) { t.Errorf("Expecting 15915Hz, got %d",ch.Fcut[0])}
	if( ch.Fcut[1]!= 3183 ) { t.Errorf("Expecting  3183Hz, got %d",ch.Fcut[1])}
	if( ch.Pole   !="{15'h7350,15'h4A23}" ) { t.Errorf("Wrong pole coefficients. Got %x",ch.Pole)}
	// different values
	ch.RC=[]AudioRC{
		{ R: "10k", C:  "47n" },
		{ R: " 1k", C: "220n" },
	}
	make_rc(&ch,fs)
	if( ch.Filters!=1 ) { t.Errorf("Expecting 1 filter, got %d",ch.Filters) }
	if( ch.Fcut[0]!=339 ) { t.Errorf("Expecting 339Hz, got %d",ch.Fcut[0])}
	if( ch.Fcut[1]!=723 ) { t.Errorf("Expecting 723Hz, got %d",ch.Fcut[1])}
	if( strings.Index(ch.Pole,"-")!=-1 ) { t.Errorf("Invalid pole encoding %s",ch.Pole)}
	t.Logf("ch.Pole=%s",ch.Pole)
	// final one
	ch.RC=[]AudioRC{
		{ R: "2.5k", C: "1n" },
		{ R: "10k",  C: "47p" },
	}
	make_rc(&ch,fs)
	if( ch.Filters!=1 ) { t.Errorf("Expecting 1 filter, got %d",ch.Filters) }
	if( ch.Fcut[0]!=63662  ) { t.Errorf("Expecting 63662Hz, got %d",ch.Fcut[0])}
	if( ch.Fcut[1]!=338628 ) { t.Errorf("Expecting 338628Hz, got %d",ch.Fcut[1])}
	if( strings.Index(ch.Pole,"-")!=-1 ) { t.Errorf("Invalid pole encoding %s",ch.Pole)}
	t.Logf("ch.Pole=%s",ch.Pole)
}

func Test_normalize_gains(t *testing.T) {
	channels := []AudioCh{
		{ gain: 1.0 },
		{ gain: 2.0 },
		{ gain: 3.0 },
		{ gain: 4.0 },
	}
	const global_gain=1.5
	normalize_gains(channels,global_gain)
	expected := []float64{
		1.0/4.0*global_gain,
		2.0/4.0*global_gain,
		3.0/4.0*global_gain,
		4.0/4.0*global_gain,
	}
	for k,_ := range expected {
		if channels[k].gain!=expected[k] {
			t.Errorf("Expected gain %.2f for channel %d. Got %.2f",
				expected[k], k, channels[k].gain)
		}
	}
}
