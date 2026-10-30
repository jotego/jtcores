package main

import (
    "os"
    "os/exec"
    "path/filepath"
)

func main() {
    task:=filepath.Join(os.Getenv("JTROOT"),"tasks","jtcores-143")
    capture:=os.Getenv("YAMAHA_REPLAY")
    if capture=="" { capture=filepath.Join(task,"artifacts","high.cap") }
    cmd:=exec.Command("go","run",filepath.Join(task,"host","analyze.go"),"-fixture","replay",capture)
    cmd.Stdout=os.Stdout
    cmd.Stderr=os.Stderr
    if e:=cmd.Run();e!=nil { panic(e) }
}
