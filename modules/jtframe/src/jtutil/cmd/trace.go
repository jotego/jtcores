/*  This file is part of JTCORES.
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
    Date: 4-1-2025 */

package cmd

import (
	"bufio"
	"fmt"
	"os"
	"strings"

	"github.com/spf13/cobra"
	"jtutil/vcd"
)

func init() {
	traceCmd := &cobra.Command{
		Use:   "trace",
		Short: "Compare VCD file with CSV MAME trace output",
		Long:  man_blurb("jtutil-trace", "Compare a VCD file with MAME trace output."),
		Run:   run_trace_cmd,
	}
	rootCmd.AddCommand(traceCmd)
	flg := traceCmd.Flags()

	flg.StringP("make", "m", "", "Create trace.mame (CSV format) for the given CPU")
	flg.StringP("base-name", "b", "debug", "Use <name>.csv and <name>.vcd files (defaults: debug.csv/debug.vcd)")
}

func run_trace_cmd(cmd *cobra.Command, args []string) {
	if make_sample_file, _ := cmd.Flags().GetString("make"); make_sample_file != "" {
		makeMAME(make_sample_file)
		return
	}
	basename, _ := cmd.Flags().GetString("base-name")
	run_trace_comparison(basename)
}

func run_trace_comparison(basename string) {
	vcdf := &vcd.LnFile{}
	vcd.Verbose = verbose
	if !is_vcd_file(basename + ".vcd") {
		fmt.Printf("%s.vcd does not look like a VCD file; MAME CSV traces belong in %s.csv\n", basename, basename)
		return
	}
	vcdf.Open(basename + ".vcd")
	defer vcdf.Close()
	signals := vcd.GetSignals(vcdf)
	vcd.RenameRegs(signals)

	trace_file := &vcd.TraceReader{}
	trace_file.Open(basename + ".csv")
	defer trace_file.Close()

	// MakeCSV parser requires the first non-empty line to be the register header.
	if _, ok := trace_file.Next(); !ok {
		fmt.Printf("No trace data in %s.csv\n", basename)
		return
	}
	if len(trace_file.Header()) == 0 {
		fmt.Printf("%s.csv does not start with a CSV header\n", basename)
		return
	}
	if !trace_file.RewindTo(1, 0) {
		fmt.Printf("Cannot restart %s.csv at line 1\n", basename)
		return
	}
	mame_alias := vcd.MakeAlias(trace_file, signals)
	vcd.NewVCDPrompt(vcdf, trace_file, signals, mame_alias).Run()
}

func is_vcd_file(fname string) bool {
	f, e := os.Open(fname)
	if e != nil {
		fmt.Println(e)
		return false
	}
	defer f.Close()
	scn := bufio.NewScanner(f)
	for scn.Scan() {
		txt := strings.TrimSpace(scn.Text())
		if txt == "" {
			continue
		}
		return strings.HasPrefix(txt, "$")
	}
	if e := scn.Err(); e != nil {
		fmt.Println(e)
	}
	return false
}

func makeMAME(cpu string) {
	var s string
	switch strings.ToLower(cpu) {
	case "z80":
		s = `trace debug.csv,maincpu,noloop,{tracelog "%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,",pc,af,bc,de,hl,af2,bc2,de2,hl2,ix,iy,sp}
tracelog "PC,AF,BC,DE,HL,AF2,BC2,DE2,HL2,IX,IY,SP\n"
softreset
`
	case "t900h":
		s = `trace debug.csv,maincpu,noloop,{tracelog "%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,",pc,xwa0,xbc0,xde0,xhl0,xwa1,xbc1,xde1,xhl1,xwa2,xbc2,xde2,xhl2,xwa3,xbc3,xde3,xhl3,xix,xiy,xiz,xssp}
tracelog "PC,XWA0,XBC0,XDE0,XHL0,XWA1,XBC1,XDE1,XHL1,XWA2,XBC2,XDE2,XHL2,XWA3,XBC3,XDE3,XHL3,XIX,XIY,XIZ,XSP\n"
softreset
`
	case "6301", "6800", "6801":
		s = `focus 1
trace off
trace debug.csv,sub,noloop,{tracelog "%X,%X,%X,%X,%X,%X,%X,",pc,s,x,cc|c0,a,b,frame}
tracelog "PC,S,X,CC,A,B,frame_cnt\n"
softreset
`
	case "6502":
		s = `focus 1
trace off
trace debug.csv,sub,noloop,{tracelog "%X,%X,%X,%X,%X,%X,%X,%X,",pc,sp&0xff,x,y,a,p&0xef,ir,frame}
tracelog "PC,S,X,Y,A,P,IR,frame_cnt\n"
softreset
x=0
p=30
`
	case "6805":
		s = `focus 1
trace off
trace debug.csv,mcu,noloop,{tracelog "%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,",pc,s,x,cc|c0,a,latcha,latchb,latchc,ddra,ddrb,ddrc,frame}
tracelog "PC,S,X,CC,A,PA_OUT,PB_OUT,PC_OUT,PA_DDR,PB_DDR,PC_DDR,frame_cnt\n"
softreset
`
	case "m68000", "m68k", "68k", "68000":
		s = `focus 0
trace off
trace debug.csv,maincpu,noloop,{tracelog "%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,",rPC,SSP,d0,d1,d2,d3,d4,d5,d6,d7,a0,a1,a2,a3,a4,a5,a6,USP,ir,frame}
tracelog "PC,SSP,D0,D1,D2,D3,D4,D5,D6,D7,A0,A1,A2,A3,A4,A5,A6,A7,IR,frame_cnt\n"
softreset
`
	case "konami", "kcpu", "6809":
		s = `focus 0
trace off
trace debug.csv,maincpu,noloop,{tracelog "%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,",pc,cc,dp,a,b,x,y,u,s,totalcycles,frame}
tracelog "PC,cc,dp,a,b,x,y,u,s,ticks,frame_cnt\n"
softreset
`
	case "sh7604", "sh-2":
		s = `trace off
trace debug.csv,maincpu,noloop,{tracelog "%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,",pc,sr,pr,gbr,vbr,r0,r1,r2,r3,r4,r5,r6,r7,r8,r9,r10,r11,r12,r13,r14,r15,frame}
tracelog "PC,SR,PR,GBR,VBR,R0,R1,R2,R3,R4,R5,R6,R7,R8,R9,R10,R11,R12,R13,R14,R15,frame_cnt\n"
softreset
`
	case "qsnd", "qsound":
		s = `trace debug.csv,2,,{tracelog "%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,%X,",pc,pt,pr,pi,i,r0,r1,r2,r3,rb,re,j,k,x,y,p,a0,a1,c0,c1,c2,auc,psw}
tracelog "PC,PT,PR,PI,I,R0,R1,R2,R3,RB,RE,J,K,X,Y,P,A0,A1,C0,C1,C2,AUC,PSW\n"
softreset
`
	}
	if s == "" {
		fmt.Printf("No default trace.mame file for %s CPU. Add it to trace.go\n", cpu)
		fmt.Printf(`Supported CPUs names and aliases:
z80
t900h
6800, 6301, 6801,
m68000, m68k, 68k, 68000
konami, kcpu, 6809
sh7604
qsnd, qsound
`)
		return
	}
	s += `
gtime 100
traceflush
`
	f, e := os.Create("trace.mame")
	defer f.Close()
	if e != nil {
		fmt.Println(e)
		return
	}
	f.WriteString(s)
	fmt.Println("trace.mame created")
}
