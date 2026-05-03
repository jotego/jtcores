/*  This file is part of JTCORES.
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

package vcd

import (
	"bufio"
	"log"
	"os"
)

type LnFile struct {
	f           *os.File
	line        int // line count
	reset_line  int // line at which the file can be reset
	scn         *bufio.Scanner
	time        uint64
	fname       string
	offset      int64
	line_offset map[int]int64
}

func (ln *LnFile) Open(fname string) {
	var e error
	ln.f, e = os.Open(fname)
	if e != nil {
		log.Fatal(e)
	}
	ln.fname = fname
	ln.make_scanner()
}

func (ln *LnFile) make_scanner() {
	ln.scn = bufio.NewScanner(ln.f)
	ln.line = 0
	ln.offset = 0
	if ln.line_offset == nil {
		ln.line_offset = make(map[int]int64)
	}
	ln.line_offset[0] = 0
}

func (ln *LnFile) Scan() bool {
	if ln.scn.Scan() {
		if ln.line_offset == nil {
			ln.line_offset = make(map[int]int64)
		}
		line_offset := ln.offset
		txt := ln.scn.Text()
		ln.line++
		ln.line_offset[ln.line] = line_offset
		ln.offset += int64(len(txt) + 1)
		if ln.scn.Err() != nil {
			log.Fatal(ln.scn.Err())
		}
		return true
	} else {
		return false
	}
}

func (ln *LnFile) Close() {
	if ln.f != nil {
		ln.f.Close()
	}
}

func (ln *LnFile) SetResetLine() {
	ln.reset_line = ln.line
}

func (ln *LnFile) Reset() {
	if ln.f == nil {
		return
	}
	ln.f.Seek(0, 0)
	ln.time = 0
	ln.make_scanner()
	for ln.line != ln.reset_line && ln.Scan() {
	}
}

func (ln *LnFile) RewindTo(line int, time uint64) bool {
	if ln.f == nil {
		return ln.line == line
	}
	if ln.line == line {
		ln.time = time
		return true
	}
	offset, ok := ln.line_offset[line]
	if ok {
		ln.f.Seek(offset, 0)
		ln.scn = bufio.NewScanner(ln.f)
		ln.line = line - 1
		ln.offset = offset
		if line == 0 {
			ln.line = 0
			ln.time = time
			return true
		}
		ok = ln.Scan()
		ln.time = time
		return ok && ln.line == line
	}
	ln.f.Seek(0, 0)
	ln.time = time
	ln.make_scanner()
	for ln.line != line && ln.Scan() {
	}
	return ln.line == line
}

func (ln *LnFile) Time() uint64 {
	return ln.time
}

func (ln *LnFile) Text() string {
	return ln.scn.Text()
}
