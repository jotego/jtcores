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

type LnFile struct{
    f *os.File
    line int    // line count
    scn *bufio.Scanner
    time uint64
    fname string
}

func (this *LnFile) Open(fname string) {
    var e error
    this.f, e = os.Open(fname)
    if e != nil {
        log.Fatal(e)
    }
    this.fname=fname
    this.scn = bufio.NewScanner(this.f)
    this.line = 0
}

func (this *LnFile) Scan() bool {
    if this.scn.Scan() {
        this.line++
        if this.scn.Err()!=nil {
            log.Fatal(this.scn.Err())
        }
        return true
    } else {
        return false
    }
}

func (this *LnFile) Close() {
    if this.f != nil {
        this.f.Close()
    }
}

func (this *LnFile) Text() string {
    return this.scn.Text()
}

