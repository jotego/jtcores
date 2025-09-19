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

func (ln *LnFile) Open(fname string) {
    var e error
    ln.f, e = os.Open(fname)
    if e != nil {
        log.Fatal(e)
    }
    ln.fname=fname
    ln.scn = bufio.NewScanner(ln.f)
    ln.line = 0
}

func (ln *LnFile) Scan() bool {
    if ln.scn.Scan() {
        ln.line++
        if ln.scn.Err()!=nil {
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

func (ln *LnFile) Time() uint64 {
    return ln.time
}

func (ln *LnFile) Text() string {
    return ln.scn.Text()
}

