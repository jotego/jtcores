/*  This file is part of JT_FRAME.
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
    Date: 28-8-20122 */

// Use the Cobra Generator to add more commands
// github.com/spf13/cobra/cobra

package main

import (
    "fmt"
    "os"
    "log"
    "github.com/jotego/jtframe/cmd"
    "github.com/jotego/jtframe/betas"
)

func RequireEnv( v string ) {
    if os.Getenv(v)=="" {
        fmt.Println("Define and export the ",v," environment variable before calling jtframe")
        os.Exit(1)
    }
}

func main() {
    log.SetOutput(os.Stderr)
    for _, each := range []string{"JTROOT","CORES","JTBIN","JTFRAME"} {
        RequireEnv(each)
    }
    betas.Init()
	cmd.Execute()
}
