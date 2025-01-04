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
    "fmt"
    "strings"
    "os"
)

type CmpArgs struct {
    Ignore_rst bool
    Mismatch_n int
    Time0a, Time0b uint64
}

type cmpData struct {
    file   *LnFile
    data    vcdData
    signal *VCDSignal
    resets []*VCDSignal
}

func (this cmpData) next() bool {
    return this.file.NextVCD(this.data)
}

func in_reset(cmpd *cmpData) bool {
    for _, rst := range cmpd.resets {
        if rst.Value==1 { return true }
    }
    return false
}

func mv_reset( cmpd *cmpData ) {
    // ensure that we are in reset state
    for _, rst := range cmpd.resets {
        for rst.Value!=1 && cmpd.file.NextVCD(cmpd.data) { }
    }
    // next, come out of it
    for _, rst := range cmpd.resets {
        for rst.Value!=0 && cmpd.file.NextVCD(cmpd.data) { }
    }
}

func CompareAll( fnames []string, args CmpArgs ) {
    var c [2]cmpData
    for k,_ := range c{
        c[k].file = &LnFile{}
        if !strings.HasSuffix(fnames[k],".vcd") {
            fnames[k] += ".vcd"
        }
        c[k].file.Open(fnames[k])
        c[k].data = GetSignals(c[k].file)
        c[k].resets=c[k].data.GetAll("rst",false)
    }
    if c[0].resets!=nil {
        fmt.Println("rst signals found")
    }
    pairs := make(map[string]*VCDSignal)
    k:=0
    // find each signal pair in the other set
    for _, signal := range c[0].data {
        matched := c[1].data.Get( signal.FullName() )
        if matched == nil {
            for _, each := range c[1].data {
                fmt.Println(each.FullName())
            }
            fmt.Println("Cannot find pair for signal ", signal.FullName())
            return
        }
        pairs[signal.alias] = matched
        k++
    }
    // function to compare the two sets
    equal := func() (bool, string, uint64, uint64) {
        for ref, cmp := range pairs {
            if c[0].data[ref].Value != cmp.Value {
                // fmt.Printf("%s <--> %s\n", c[0].data[ref].FullName(), cmp.FullName())
                return false, cmp.FullName(), c[0].data[ref].Value, cmp.Value
            }
        }
        return true,"",0,0
    }
    c[0].file.MoveTo(c[0].data,args.Time0a)
    c[1].file.MoveTo(c[1].data,args.Time0b)
    // run through the VCD
    for c[0].file.NextVCD(c[0].data) {
        matched := false
        var offender string
        var v0,v1 uint64
        more := true
        t1 := c[1].file.time
        more = c[1].file.NextVCD(c[1].data)
        if args.Ignore_rst {
            if in_reset(&c[0]) || in_reset(&c[1]) {
                mv_reset(&c[0])
                mv_reset(&c[1])
            }
        }
        matched, offender, v0, v1 = equal()
        if !matched {
            fmt.Printf("Time %d (%s) and %d (%s): %s\t %X != %X\n",
                c[0].file.time, c[0].file.fname,
                t1, c[1].file.fname, offender,
                v0, v1)
            args.Mismatch_n--
            if( args.Mismatch_n<=0 ) { break }
        }
        if !more {
            fmt.Println("EOF")
            break
        }
    }
}

func Compare( fnames []string, sname string, args CmpArgs ) {
    d,_ := cmpReadin( fnames, sname )
    defer d[0].file.Close()
    defer d[1].file.Close()
    mismatch := false
    d0Names := []string{ d[0].signal.alias }
    d1Names := []string{ d[1].signal.alias }
    d[0].file.MoveTo(d[0].data,args.Time0a)
    d[1].file.MoveTo(d[1].data,args.Time0b)
    if args.Ignore_rst {
        for k:=0; k<len(d); k++ {
            d[k].resets=d[k].data.GetAll("rst",false)
        }
        if d[0].resets!=nil {
            fmt.Println("rst signals found")
        }
    }
    more := true
    for more {
        more = more && d[0].file.NextChangeIn( d[0].data, d0Names )
        more = more && d[1].file.NextChangeIn( d[1].data, d1Names )
        if args.Ignore_rst {
            if in_reset(&d[0]) || in_reset(&d[1]) {
                mv_reset(&d[0])
                mv_reset(&d[1])
            }
        }
        mismatch = d[0].signal.Value != d[1].signal.Value
        if mismatch {
            fmt.Printf("Mismatch at times %d (%s) and %d (%s)\n\t%X != %X\n",
                d[0].file.time, d[0].file.fname,
                d[1].file.time, d[1].file.fname,
                d[0].signal.Value, d[1].signal.Value )
            args.Mismatch_n--
            if( args.Mismatch_n<=0 ) { break }
        }
    }
    if !mismatch {
        fmt.Println("No differences found")
    }
}

// Open the VCD files, get the VCD signal information and
// find the required signal to compare. Caller must close the files
func cmpReadin( fnames []string, sname string ) ([2]cmpData,[2]cmpData) {
    var c,r [2]cmpData // compare and reset signals

    for k:=0; k<2; k++ {
        c[k].file = &LnFile{}
        if !strings.HasSuffix(fnames[k],".vcd") {
            fnames[k] += ".vcd"
        }
        c[k].file.Open(fnames[k])
        c[k].data = GetSignals(c[k].file)
        c[k].signal=getOne(c[k],sname, true)
        r[k].signal=getOne(c[k],"rst", false)
    }
    return c,r
}

func getOne( cd cmpData, sname string, must bool ) *VCDSignal {
    matchScope := strings.Index(sname,".")>-1
    all := cd.data.GetAll(sname, matchScope)
    if all == nil {
        if must {
            fmt.Println("Cannot find any signal named",sname,"in",cd.file.fname)
            os.Exit(1)
        }
        return nil
    }
    if len(all)>1 {
        fmt.Println("Found multiple signals named similarly to",sname)
        for _,k := range all {
            fmt.Println("\t",k.Name)
        }
        fmt.Println("Please specify the name better")
        os.Exit(1)
    }
    fmt.Println("Found",all[0].FullName(), "in", cd.file.fname)
    return all[0]
}