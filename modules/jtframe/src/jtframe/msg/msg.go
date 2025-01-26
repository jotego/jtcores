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
    Date: 30-10-2022 */

package msg

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"time"

	"github.com/jotego/jtframe/common"
)

type Compiler struct {
	core      string
	date	  string
	line_cnt  int
	data      ChData
}

type ChData []int16

func MakeCompiler(core_name string) (cmp Compiler) {
	cmp.core    = core_name
	return cmp
}

func (msg *Compiler) Convert() (e error) {
	msgpath := common.ConfigFilePath(msg.core,"msg")
	fmsg, e := os.Open(msgpath); if e!=nil { return e }
	defer fmsg.Close()
	_, e = msg.parse_stream(fmsg); if e!=nil { return e }
	msg.roundup_1k()
	return msg.dump_msg()
}

func (msg *Compiler) parse_stream(fmsg io.Reader) (parsed_lines int, e error) {
	scanner  := bufio.NewScanner(fmsg)
	msg.data  = make(ChData,0,1024)
	msg.line_cnt = 1
	for scanner.Scan() {
		var line line_parser
		text := scanner.Text()
		e := line.parse(text)
		if e!=nil {
			return msg.line_cnt, fmt.Errorf("%w at line %d",e,msg.line_cnt)
		}
		msg.data=append(msg.data,line.data...)
		msg.line_cnt++
	}
	return msg.line_cnt, nil
}

type line_parser struct {
	escape   bool
	col int
	pal      int16
	data     []int16
}

func (line *line_parser) parse(text string) error {
	line.escape = false
	line.data   = make([]int16,32)
	line.col    = 0
	line.pal    = 3
	for _, c := range text {
		e := line.parse_char(c); if e!=nil { return e }
	}
	return nil
}

func (line *line_parser) parse_char(c rune) error {
	if c == '\\' {
		line.escape = true
		return nil
	}
	if line.escape {
		return line.process_escape_char(c)
	}
	return line.push(c)
}

func (line *line_parser) process_escape_char(c rune) (e error) {
	switch c {
		case 'R': line.pal=0
		case 'G': line.pal=1
		case 'B': line.pal=2
		case 'W': line.pal=3
		// add the date
		case 'D': {
			date := get_date()
			e = line.push_str(date)
		}
		// add the commit
		case 'C': {
			commit, _ := common.GetCommit()
			e = line.push_str(commit)
		}
		default: e = fmt.Errorf("invalid palette code")
	}
	line.escape = false
	return e
}

func get_date() string {
	return fmt.Sprintf("%d-%d-%d", time.Now().Year(), time.Now().Month(), time.Now().Day())
}

func (line *line_parser) push_str( s string ) error {
	for _,c := range s {
		e := line.push(c)
		if e!=nil { return e }
	}
	return nil
}

func (line *line_parser) push(c rune) error {
	if line.col==32 {
		return fmt.Errorf("Line is longer than 32 characters")
	}
	coded := int16(c)
	if coded<0x20 || coded>0x7f {
		return fmt.Errorf("character code out of range")
	}
	coded = (line.pal<<7) | ((coded-0x20)&0x7f)
	line.data[line.col] = coded
	line.col++
	return nil
}

func (msg *Compiler)roundup_1k() {
	rest := len(msg.data)%1024
	if rest==0 { return }
	chunks := 1+len(msg.data)/1024
	expanded := make(ChData,chunks*1024)
	copy(expanded,msg.data)
	msg.data=expanded
}

func (msg *Compiler)dump_msg() error {
	hex := common.MakeHexBytes(msg.data)
	e := os.WriteFile("msg.hex",hex,0644)
	if e!=nil { return e }
	bin := common.MakeBinBytes(msg.data)
	e = os.WriteFile("msg.bin",bin,0644)
	return e
}