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
	"github.com/spf13/cobra"
	"io"
	. "jotego/jtframe/common"
	"os"
	"strconv"
	"strings"
)

func init() {
	var cabCmd = &cobra.Command{
		Use:   "cab <filename>",
		Short: "Convert cabinet input files (.cab) to sim_inputs.hex",
		Long: man_blurb("jtframe-cab", `Convert cabinet input files (.cab) to sim_inputs.hex.

Use "man jtframe-cab" for the full syntax, timing semantics, loop behavior, and
jtsim integration details.`),
		Example: `  jtframe cab reg.cab
  jtsim -inputs reg.cab -video 600 -w 500`,
		Run:  run_cab,
		Args: cobra.ExactArgs(1),
	}
	rootCmd.AddCommand(cabCmd)
}

func run_cab(cmd *cobra.Command, args []string) {
	var filename string
	defer func() {
		if r := recover(); r != nil {
			fmt.Printf("Problem found while parsing cab file %s\n", filename)
			fmt.Println(r)
			os.Exit(1)
		}
	}()
	filename = args[0]
	f, e := os.Open(filename)
	Must(e)
	defer f.Close()
	var cab cab_converter
	converted, e := cab.make_hexfile(f)
	if e != nil {
		Must(fmt.Errorf("%w of file %s", e, filename))
	}
	os.WriteFile("sim_inputs.hex", converted, 0660)
}

type loopCase int
type cab_converter struct {
	frame_cnt, linecnt int
}

const (
	CAB_COIN    = 0x0001
	CAB_SERVICE = 0x0002
	CAB_START1  = 0x0004
	CAB_START2  = 0x0008
	CAB_RIGHT1  = 0x0010
	CAB_LEFT1   = 0x0020
	CAB_DOWN1   = 0x0040
	CAB_UP1     = 0x0080
	CAB_B1_1    = 0x0100
	CAB_B2_1    = 0x0200
	CAB_B3_1    = 0x0400
	CAB_TEST    = 0x0800
	CAB_RESET   = 0x1000
	CAB_COIN2   = 0x2000
	CAB_RIGHT2  = 0x4000
	CAB_LEFT2   = 0x8000
	CAB_DOWN2   = 0x10000
	CAB_UP2     = 0x20000
	CAB_B1_2    = 0x40000
	CAB_B2_2    = 0x80000
	CAB_B3_2    = 0x100000
)

const (
	NO_LOOP    = 0
	LOOP_START = -1
	// positive values mean that the loop sequence must be executed that number of times
)

func (cab *cab_converter) make_hexfile(cabfile io.Reader) (hex []byte, e error) {
	cab.frame_cnt = 0
	hex = make([]byte, 0, 8*1024)
	scanner := bufio.NewScanner(cabfile)
	cab.linecnt = 0
	var loop_body []byte
	looping := false
	for scanner.Scan() {
		cab.linecnt++
		trimmed := strings.TrimSpace(scanner.Text())
		tokens := strings.Split(trimmed, " ")
		loop_case, e := cab.detect_loop(tokens)
		if e != nil {
			return nil, e
		}
		var parsed []byte
		switch loop_case {
		case NO_LOOP:
			{
				parsed, e = cab.parse_tokens(tokens)
				if e != nil {
					return nil, fmt.Errorf("%w at line %d", e, cab.linecnt)
				}
				if looping {
					loop_body = append(loop_body, parsed...)
				}
			}
		case LOOP_START:
			{
				loop_body = make([]byte, 0, 256)
				looping = true
				continue
			}
		default:
			{
				parsed = cab.execute_loop(loop_body, int(loop_case))
				loop_body = nil
				looping = false
			}
		}
		hex = append(hex, parsed...)
		cab.frame_cnt += cab.count_lines(parsed)
	}
	return hex, nil
}

func (cab *cab_converter) count_lines(bb []byte) int {
	lines := 0
	for _, b := range bb {
		if b == '\n' {
			lines++
		}
	}
	return lines
}

func (cab *cab_converter) detect_loop(tokens []string) (loopCase, error) {
	if len(tokens) == 0 || (len(tokens) == 1 && tokens[0] == "") {
		return NO_LOOP, nil
	}
	keyword := strings.ToLower(tokens[0])
	switch keyword {
	case "loop":
		{
			if len(tokens) != 1 {
				return NO_LOOP, fmt.Errorf("Extra text after keyword loop: %s", tokens[1])
			}
			return LOOP_START, nil
		}
	case "repeat":
		{
			if len(tokens) < 2 {
				return NO_LOOP, fmt.Errorf("Missing number of repeats after keyword repeat")
			}
			if len(tokens) > 2 {
				return NO_LOOP, fmt.Errorf("Extra text after keyword repeat: %s", tokens[2])
			}
			repeat, e := strconv.ParseInt(tokens[1], 0, 32)
			if e != nil {
				return NO_LOOP, fmt.Errorf("Cannot parse repeat number: %s", tokens[1])
			}
			if repeat <= 0 {
				return NO_LOOP, fmt.Errorf("The number of repeats must be positive")
			}
			return loopCase(repeat), nil
		}
	}
	return NO_LOOP, nil
}

func (cab *cab_converter) execute_loop(body []byte, times int) (unwrapped []byte) {
	if times <= 1 {
		return nil
	}
	unwrapped = make([]byte, 0, len(body)*times)
	for ; times > 1; times-- {
		unwrapped = append(unwrapped, body...)
	}
	return unwrapped
}

func (cab *cab_converter) parse_tokens(tokens []string) (parsed []byte, e error) {
	if len(tokens) == 0 ||
		(len(tokens) >= 1 && (tokens[0] == "" || tokens[0][0] == '#')) {
		return nil, nil
	}
	pos := 0
	repeat, valid := cab.calc_repetitions(tokens[pos])
	if valid {
		pos++
	}
	value := 0
	for ; pos < len(tokens); pos++ {
		action := strings.ToLower(tokens[pos])
		switch action {
		case "":
			break
		case "coin":
			value |= CAB_COIN
		case "2coin":
			value |= CAB_COIN2
		case "service":
			value |= CAB_SERVICE
		case "1p":
			value |= CAB_START1
		case "2p":
			value |= CAB_START2
		case "right":
			value |= CAB_RIGHT1
		case "2right":
			value |= CAB_RIGHT2
		case "left":
			value |= CAB_LEFT1
		case "2left":
			value |= CAB_LEFT2
		case "down":
			value |= CAB_DOWN1
		case "2down":
			value |= CAB_DOWN2
		case "up":
			value |= CAB_UP1
		case "2up":
			value |= CAB_UP2
		case "b1":
			value |= CAB_B1_1
		case "2b1":
			value |= CAB_B1_2
		case "b2":
			value |= CAB_B2_1
		case "2b2":
			value |= CAB_B2_2
		case "b3":
			value |= CAB_B3_1
		case "2b3":
			value |= CAB_B3_2
		case "test":
			value |= CAB_TEST
		case "reset":
			value |= CAB_RESET
		default:
			return nil, fmt.Errorf("Unknown action '%s'", action)
		}
	}
	parsed = make([]byte, 0, 3*repeat)
	for ; repeat > 0; repeat-- {
		encoded := fmt.Sprintf("%x\n", value)
		parsed = append(parsed, []byte(encoded)...)
	}
	return parsed, nil
}

func (cab *cab_converter) calc_repetitions(expr string) (repeat int, valid bool) {
	var e error
	var aux int64
	aux, e = strconv.ParseInt(expr, 0, 32)
	repeat = int(aux)
	if e == nil {
		return repeat, true
	}
	if expr[0] == '=' {
		aux, e = strconv.ParseInt(expr[1:], 0, 32)
		final_frame := int(aux)
		if e != nil {
			msg := fmt.Sprintf("a valid number must be entered after =\nbut found %s at line %d", expr, cab.linecnt)
			panic(msg)
		}
		repeat = final_frame - cab.frame_cnt + 1
		if repeat < 0 {
			msg := fmt.Sprintf("The frame count is already at %d, cannot wait until frame %d (at line %d)", cab.frame_cnt, final_frame, cab.linecnt)
			panic(msg)
		}
		return repeat, true
	}
	return 1, false
}
