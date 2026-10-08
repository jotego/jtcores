/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 28-8-20122 */

// Use the Cobra Generator to add more commands
// github.com/spf13/cobra/cobra

package main

import (
    "runtime/debug"
    "fmt"
    "os"
    "log"
    "jotego/jtframe/cmd"
    "jotego/jtframe/betas"
)

func RequireEnv( v string ) {
    if os.Getenv(v)=="" {
        fmt.Println("Define and export the ",v," environment variable before calling jtframe")
        os.Exit(1)
    }
}

func main() {
    defer func(){
        if r:= recover(); r!=nil {
            fmt.Println(r)
            fmt.Printf("\n\n")
            debug.PrintStack()
            os.Exit(1)
        }
    }()
    log.SetOutput(os.Stderr)
    for _, each := range []string{"JTROOT","CORES","JTBIN","JTFRAME"} {
        RequireEnv(each)
    }
    betas.Init()
	cmd.Execute()
}
