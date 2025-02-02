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
    Date: 21-1-2023 */

package cmd

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"strconv"
	"strings"
	"github.com/spf13/cobra"
	. "github.com/jotego/jtframe/common"
)

// cabCmd represents the cab command
var cabCmd = &cobra.Command{
	Use:   "cab <filename>",
	Short: "Convert cabinet input files (.cab) to sim_inputs.hex",
	Long: `Converts a given cabinet input file (.cab) to sim_inputs.hex.
The cab file has the following syntax:

# comment
[number of frames] [button pressed] [button pressed]...
loop
[number of frames] [button pressed] [button pressed]...
...
repeat <1 or more>

If the number of frames is not explicit, the buttons are pressed for one frame.
The valid button names are:

	service, 1p, 2p, right, left, down, up, b1, b2, b3, test, reset

The loop line indicates the start of the loop and it does not take a frame.
The repeat line indicates the loop end and it must indicate the number of times
to repeat the loop section (at least 1).
`,
	Run: func(cmd *cobra.Command, args []string) {
		filename := args[0]
		f, e := os.Open(filename); Must(e)
		defer f.Close()
		converted, e := cab2hex(f);
		if e!=nil {
			Must(fmt.Errorf("%w of file %s",e,filename))
		}
		os.WriteFile("sim_inputs.hex",converted, 0660 )
	},
	Args: cobra.ExactArgs(1),
}

func init() {
	rootCmd.AddCommand(cabCmd)
}

type loopCase int

const (
	NO_LOOP    = 0
	LOOP_START = -1
	// positive values mean that the loop sequence must be executed that number of times
)

func cab2hex(cab io.Reader) (hex []byte, e error) {
	hex = make([]byte,0,8*1024)
	scanner := bufio.NewScanner(cab)
	linecnt := 0
	var loop_body []byte
	looping := false
	for scanner.Scan() {
		linecnt++
		trimmed := strings.TrimSpace(scanner.Text())
		tokens := strings.Split( trimmed, " ")
		loop_case, e := detect_loop(tokens)
		if e!=nil { return nil, e }
		var parsed []byte
		switch loop_case {
			case NO_LOOP: {
				parsed, e = parse_tokens( tokens )
				if e!=nil { return nil, fmt.Errorf("%w at line %d",e,linecnt) }
				if looping {
					loop_body = append(loop_body,parsed...)
				}
			}
			case LOOP_START: {
				loop_body = make([]byte,0,256)
				looping = true
				continue
			}
			default: {
				parsed = execute_loop(loop_body, int(loop_case))
				loop_body = nil
				looping = false
			}
		}
		hex=append(hex,parsed...)
	}
	return hex, nil
}

func detect_loop(tokens []string) (loopCase, error) {
	if len(tokens)==0 || (len(tokens)==1 && tokens[0]=="") { return NO_LOOP, nil }
	keyword := strings.ToLower(tokens[0])
	switch keyword {
		case "loop": {
			if len(tokens)!=1 { return NO_LOOP, fmt.Errorf("Extra text after keyword loop: %s",tokens[1])}
			return LOOP_START, nil
		}
		case "repeat": {
			if len(tokens)<2 { return NO_LOOP, fmt.Errorf("Missing number of repeats after keyword repeat")}
			if len(tokens)>2 { return NO_LOOP, fmt.Errorf("Extra text after keyword repeat: %s",tokens[2])}
			repeat, e := strconv.ParseInt(tokens[1],0,32)
			if e!=nil { return NO_LOOP, fmt.Errorf("Cannot parse repeat number: %s",tokens[1])}
			if repeat<=0 { return NO_LOOP,fmt.Errorf("The number of repeats must be positive")}
			return loopCase(repeat),nil
		}
	}
	return NO_LOOP,nil
}

func execute_loop(body []byte,times int) (unwrapped []byte) {
	if times<=1 { return nil }
	unwrapped = make([]byte,0,len(body)*times)
	for ;times>1;times-- {
		unwrapped=append(unwrapped,body...)
	}
	return unwrapped
}

func parse_tokens( tokens []string ) (parsed []byte, e error) {
	if len(tokens)==0 ||
	  (len(tokens)>=1 && (tokens[0]=="" || tokens[0][0]=='#')) {
		return nil, nil
	}
	pos := 0
	repeat, e := strconv.ParseInt(tokens[pos],0,32)
	pos++
	if e!=nil { repeat=1; pos=0 }
	value := 0
	for ;pos<len(tokens);pos++ {
		action := strings.ToLower(tokens[pos])
		switch action {
			case "": 		break
			case "coin": 	value |= 0x0001;
			case "service": value |= 0x0002;
			case "1p": 		value |= 0x0004;
			case "2p": 		value |= 0x0008;
			case "right": 	value |= 0x0010;
			case "left":  	value |= 0x0020;
			case "down":  	value |= 0x0040;
			case "up":    	value |= 0x0080;
			case "b1":    	value |= 0x0100;
			case "b2":    	value |= 0x0200;
			case "b3":    	value |= 0x0400;
			case "test":  	value |= 0x0800;
			case "reset":  	value |= 0x1000;
			default: return nil, fmt.Errorf("Unknown action '%s'",action)
		}
	}
	parsed = make([]byte,0,2*repeat)
	for ;repeat>0;repeat-- {
		encoded := fmt.Sprintf("%x\n",value)
		parsed=append(parsed,[]byte(encoded)...)
	}
	return parsed,nil
}