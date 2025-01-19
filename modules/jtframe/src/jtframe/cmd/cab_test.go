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
    Date: 21-1-2023 */

package cmd

import (
	"bufio"
	"bytes"
	"strings"
	"testing"
)


func TestCab2Hex_empty( t *testing.T ) {
	empty := strings.NewReader("")

	converted, e := cab2hex(empty); if e!=nil { t.Error(e) }
	if len(converted)!=0 { t.Errorf("Expected an empty value")}
}

func TestCab2Hex_lines( t *testing.T ) {
	cab := strings.NewReader("200")
	converted, e := cab2hex(cab); if e!=nil { t.Error(e) }
	reader := bytes.NewReader(converted)
	linecnt := 0
	for scanner := bufio.NewScanner(reader);scanner.Scan(); {
		linecnt++
		if scanner.Text()!="0" { t.Errorf("Expecting line to be 0")}
	}
	if linecnt!=200 { t.Errorf("Expecting 200 lines, got %d",linecnt)}
}

func TestCab2Hex_comment( t *testing.T ) {
	cab := strings.NewReader("#\n#\n5\n#\n#\n2\n")
	converted, e := cab2hex(cab); if e!=nil { t.Error(e) }
	reader := bytes.NewReader(converted)
	linecnt := 0
	for scanner := bufio.NewScanner(reader); scanner.Scan(); {
		linecnt++
		if scanner.Text()!="0" { t.Errorf("Expecting line to be 0")}
	}
	if linecnt!=7 { t.Errorf("Expecting 7 lines, got %d",linecnt)}
}

func TestCab2Hex_comment2( t *testing.T ) {
	cab := strings.NewReader("# prologue\n")
	converted, e := cab2hex(cab); if e!=nil { t.Error(e) }
	reader := bytes.NewReader(converted)
	linecnt := 0
	for scanner := bufio.NewScanner(reader); scanner.Scan(); {
		linecnt++
		if scanner.Text()!="0" { t.Errorf("Expecting line to be 0")}
	}
	const expected=0
	if linecnt!=expected { t.Errorf("Expecting %d lines, got %d",expected,linecnt)}
}

func TestCab2Hex_single( t *testing.T ) {
	cab := strings.NewReader(`coin
service
1p
2p
right
left
down
up
b1
b2
b3
test
`)
	converted, e := cab2hex(cab); if e!=nil { t.Error(e) }
	reader := bytes.NewReader(converted)
	scanner := bufio.NewScanner(reader)
	linecnt := 0
	expected := []string{ "1","2","4","8","10","20","40",
		"80","100","200","400","800" }
	for scanner.Scan() {
		linecnt++
		line := scanner.Text()
		if line!=expected[linecnt-1] {
			t.Errorf("Expecting line %2d to be %3s but got %3s",linecnt, expected[linecnt-1], line)
		}
	}
	if linecnt!=12 { t.Errorf("Expecting 12 lines, got %d",linecnt)}
}

func TestCab2Hex_1p( t *testing.T ) {
	cab := strings.NewReader(`
5
2 coin
5
2 1p
1
`)
	expected := `0
0
0
0
0
1
1
0
0
0
0
0
4
4
0
`
	converted, e := cab2hex(cab); if e!=nil { t.Error(e); return }
	test_cab2hex_compare(converted,expected,t)
}

func TestCab2Hex_multiple( t *testing.T ) {
	cab := strings.NewReader(`1
left b1
2
right b2
1
`)
	expected := `0
120
0
0
210
0
`
	converted, e := cab2hex(cab); if e!=nil { t.Error(e); return }
	test_cab2hex_compare(converted,expected,t)
}

func TestCab2Hex_loop( t *testing.T ) {
	cab := strings.NewReader(`1
loop
2 coin
2 1p
repeat 4
reset
`)
	expected := `0
1
1
4
4
1
1
4
4
1
1
4
4
1
1
4
4
1000
`
	converted, e := cab2hex(cab); if e!=nil { t.Error(e); return }
	test_cab2hex_compare(converted,expected,t)
}

func test_cab2hex_compare( converted []byte, expected string, t *testing.T) {
	text := string(converted)
	if text!=expected {
		t.Log("Got:")
		t.Log(text)
		t.Log("Expected:")
		t.Log(expected)
		t.Errorf("Failed conversion")
	}
}