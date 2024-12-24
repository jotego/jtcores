package vcd

import (
    "fmt"
    "strings"
    "os"
)

type cmpData struct{
    file   *LnFile
    data    vcdData
    signal *VCDSignal
}

func (this cmpData) next() bool {
    return this.file.NextVCD(this.data)
}

func CompareAll( fnames []string, mismatch_n int ) {
    var c [2]cmpData
    for k,_ := range c{
        c[k].file = &LnFile{}
        if !strings.HasSuffix(fnames[k],".vcd") {
            fnames[k] += ".vcd"
        }
        c[k].file.Open(fnames[k])
        c[k].data = GetSignals(c[k].file)
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
    // run through the VCD
    for c[0].file.NextVCD(c[0].data) {
        matched := false
        var offender string
        var v0,v1 uint64
        more := true
        t1 := c[1].file.time
        more = c[1].file.NextVCD(c[1].data)
        matched, offender, v0, v1 = equal()
        if !matched {
            fmt.Printf("Time %d (%s) and %d (%s): %s\t %X != %X\n",
                c[0].file.time, c[0].file.fname,
                t1, c[1].file.fname, offender,
                v0, v1)
            mismatch_n--
            if( mismatch_n<=0 ) { break }
        }
        if !more {
            fmt.Println("EOF")
            break
        }
    }
}

func Compare( fnames []string, sname string, ignore_rst bool, mismatch_n int ) {
    d,_ := cmpReadin( fnames, sname )
    defer d[0].file.Close()
    defer d[1].file.Close()
    mismatch := false
    d0Names := []string{ d[0].signal.alias }
    d1Names := []string{ d[1].signal.alias }
    if ignore_rst {
        fmt.Println("reset parsing not supported")
        return
    }
    more := true
    for more {
        more = more && d[0].file.NextChangeIn( d[0].data, d0Names )
        more = more && d[1].file.NextChangeIn( d[1].data, d1Names )
        mismatch = d[0].signal.Value != d[1].signal.Value
        if mismatch {
            fmt.Printf("xxMismatch at times %d (%s) and %d (%s)\n\t%X != %X\n",
                d[0].file.time, d[0].file.fname,
                d[1].file.time, d[1].file.fname,
                d[0].signal.Value, d[1].signal.Value )
            mismatch_n--
            if( mismatch_n<=0 ) { break }
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