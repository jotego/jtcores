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
    if(this.scn.Scan()) {
        this.line++
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

