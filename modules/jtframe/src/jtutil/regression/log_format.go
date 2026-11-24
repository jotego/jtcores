/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
    "fmt"
    "strings"
    "time"
)

// FormatLogEntry keeps date/time, game, runtime and verdict in fixed columns.
// A negative runtime means no measured game duration is available yet.
func FormatLogEntry(stamp time.Time,game string,seconds float64,verdict,message string) string {
    if game==""{game="-"}
    if len([]rune(game))>32{message=game+": "+message;game=string([]rune(game)[:29])+"..."}
    runtime:="-"
    if seconds>=0{runtime=fmt.Sprintf("%.1fs",seconds)}
    if len(runtime)>10{runtime=fmt.Sprintf("%.2gs",seconds)}
    prefix:=fmt.Sprintf("%s %-32.32s %10.10s %-11.11s",LogTime(stamp),game,runtime,strings.ToUpper(verdict))
    lines:=strings.Split(strings.TrimSpace(bounded_message(message)),"\n")
    for i,line:=range lines{
        lines[i]=prefix
        if line!=""{lines[i]+=" "+strings.TrimRight(line,"\r")}
    }
    return strings.Join(lines,"\n")+"\n"
}
