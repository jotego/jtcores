/*
Copyright © 2023 Jose Tejada <jose.tejada@jotego.es>

*/
package cmd

import (
	"jtutil/vcd"
	"fmt"
	"os"
	"strings"
	"github.com/spf13/cobra"
)

var trace_flags struct {
	make string
}

// traceCmd represents the trace command
var traceCmd = &cobra.Command{
	Use:   "trace",
	Short: "Compare VCD file with MAME trace output",
	Long: `Use to debug a simulation against MAME.
Prepare a MAME trace file with register dumps, and a VCD file with the registers
you want to compare.

debug.trace		text file generated with MAME
debug.vcd		VCD file for comparison

File names cannot be overriden.

An automatic matching  between the MAME variables and the VCD signal names will
be attempted. If a signal is not matched to MAME, manually add it with the alias
command.

The comparison is interactive, although a script can also be run to help in
debugging sessions. Type help to obtain the list of commands.

The VCD comparison will not be done while these signals are high:

- alu_busy      the ALU is busy solving a long operation
- str_busy      a long string operation is in progress
- stack_busy    processing long stack related operations
`,
	Run: func(cmd *cobra.Command, args []string) {
		runTrace()
	},
}

func init() {
	rootCmd.AddCommand(traceCmd)
	flg  := traceCmd.Flags()

	flg.StringVarP(&trace_flags.make,"make","m", "", "Create MAME trace file for the given CPU")
}

func runTrace() { //////////////// command's main function
	if trace_flags.make != "" {
		makeMAME(trace_flags.make)
		return
	}
	trace := &vcd.LnFile{}
	vcdf  := &vcd.LnFile{}
	vcdf.Open("debug.vcd")
	defer vcdf.Close()
	signals := vcd.GetSignals(vcdf)
	vcd.RenameRegs( signals )

	trace.Open("debug.trace")
	defer trace.Close()

	trace.Scan()
	mame_alias := vcd.MakeAlias(trace.Text(), signals)
	vcd.Prompt( vcdf, trace, signals, mame_alias  )
}

func makeMAME( cpu string ) {
	var s string
	switch strings.ToLower(cpu) {
		case "t900h": s=`trace debug.trace,maincpu,noloop,{tracelog "PC=%X,XWA0=%X,XBC0=%X,XDE0=%X,XHL0=%X,XWA1=%X,XBC1=%X,XDE1=%X,XHL1=%X,XWA2=%X,XBC2=%X,XDE2=%X,XHL2=%X,XWA3=%X,XBC3=%X,XDE3=%X,XHL3=%X,XIX=%X,XIY=%X,XIZ=%X,XSP=%X,* ",pc,xwa0,xbc0,xde0,xhl0,xwa1,xbc1,xde1,xhl1,xwa2,xbc2,xde2,xhl2,xwa3,xbc3,xde3,xhl3,xix,xiy,xiz,xssp}
`
		case "6301","6800","6801":
			s=`focus 1
trace off
trace debug.trace,sub,noloop,{tracelog "PC=%X,S=%X,X=%X,CC=%X,A=%X,B=%X,frame_cnt=%x* ",pc,s,x,cc|c0,a,b,frame}
`
		case "m68000","m68k","68k","68000":
			s=`focus 0
trace off
trace debug.trace,maincpu,noloop,{tracelog "PC=%X,SSP=%X,D0=%X,D1=%X,D2=%X,D3=%X,D4=%X,D5=%X,D6=%X,D7=%X,A0=%X,A1=%X,A2=%X,A3=%X,A4=%X,A5=%X,A6=%X,A7=%X,IR=%X,frame_cnt=%x* ",rPC,SSP,d0,d1,d2,d3,d4,d5,d6,d7,a0,a1,a2,a3,a4,a5,a6,USP,ir,frame}
`
		case "konami","kcpu","6809": s=`focus 0
trace off
trace debug.trace,maincpu,noloop,{tracelog "PC=%X,cc=%X,dp=%x,a=%x,b=%x,x=%x,y=%x,u=%x,s=%x,frame_cnt=%x* ",pc,cc,dp,a,b,x,y,u,s,frame}
`
		case "qsnd","qsound": s=`trace debug.trace,2,,{tracelog "! pc=%X pt=%X pr=%X pi=%X i=%X r0=%X r1=%X r2=%X r3=%X rb=%X re=%X j=%X k=%X x=%X y=%X p=%X a0=%X a1=%X c0=%X c1=%X c2=%X auc=%X psw=%X\n",pc,pt,pr,pi,i,r0,r1,r2,r3,rb,re,j,k,x,y,p,a0,a1,c0,c1,c2,auc,psw}
`
	}
	if s=="" {
		fmt.Printf("No default trace.mame file for %s CPU. Add it to trace.go\n", cpu)
		fmt.Printf(`Supported CPUs names and aliases:
t900h
6800, 6301, 6801,
m68000, m68k, 68k, 68000
konami, kcpu, 6809
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
	if e!=nil {
		fmt.Println(e)
		return
	}
	f.WriteString(s)
	fmt.Println("trace.mame created")
}