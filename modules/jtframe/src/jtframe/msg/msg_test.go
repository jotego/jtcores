/*  This file is part of JTFRAME.
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
    Date: 26-1-2025 */

package msg

import(
    "fmt"
    "strings"
	"testing"
)

func Test_Run(t *testing.T) {

}

func Test_roundup_1k(t *testing.T) {
    var msg Compiler
    msg.data=make(ChData,1)
    const ref=12
    msg.data[0]=ref
    msg.roundup_1k()
    if len(msg.data)!=1024 { t.Errorf("wrong capacity. Got %d entries",len(msg.data))}
    if msg.data[0]!=ref {t.Errorf("wrong content")}
}

func Test_compiler_parse_stream(t *testing.T) {
    full_lines(t)
    too_long(t)
    palette(t)
}

func full_lines(t *testing.T) {
    content:=`01234567890123456789012345678912
01234567890123456789012345678912
01234567890123456789012345678912
`
    var msg Compiler
    lines, e := msg.parse_stream( strings.NewReader(content) )
    if e!=nil { t.Error(e) }
    if lines!=4 { t.Errorf("Wrong number of parsed lines. Got %d",lines)}
}

func too_long(t *testing.T) {
    content:=`01234567890123456789012345678912
01234567890123456789012345678912
012345678901234567890123456789123
`
    var msg Compiler
    lines, e := msg.parse_stream( strings.NewReader(content) )
    if e==nil { t.Error("Line too long was not detected") }
    if lines!=3 { t.Errorf("Wrong number of parsed lines. Got %d",lines)}
}

func palette(t *testing.T) {
    content:=`NO COLOR
\RRED
\GGREEN
\BBLUE
WHITE
`
    var msg Compiler
    lines, e := msg.parse_stream( strings.NewReader(content) )
    if e!=nil { t.Error(e) }
    if lines!=6 { t.Errorf("Wrong number of parsed lines. Got %d",lines)}
    expected := []int{3,0,1,2,3}
    show_content:=false
    for line:=0;line<len(expected);line++ {
        pal := expected[line]
        for col:=0; col<32; col++ {
            char := msg.data[line*32+col]
            pal_got := int(char)>>7
            if pal_got!=pal && char!=0 {
                t.Errorf("Palette mismatch at line %d(%d). Got %d (%X), expected %d",
                    line, col, pal_got, char, pal)
                show_content = true
                break
            }
        }
    }
    if show_content {
        t.Log(content)
        t.Logf("Message lines %d\n",len(msg.data)/32)
        t.Logf("Parsed content:\n%s",show_hex(msg.data))
    }
}

func show_hex(d ChData) string {
    var sb strings.Builder
    for k, v := range d {
        sb.WriteString(fmt.Sprintf("%03X ",v))
        if k%16==15 {
            if k%32==31 {
                sb.WriteString(" (line end)\n")
            }
            sb.WriteString("\n")
        }
    }
    return sb.String()
}