package vcd

import(
	"bufio"
	"strings"
	"testing"
)

func Test_set_option(t *testing.T) {
	var cmp Comparator
	e := cmp.set_option("kmax")
	if e==nil { t.Error("Expecting error on setting kmax") }
	e = cmp.set_option("retry")
	if e!=nil { t.Error(e.Error()) }
	if !cmp.retry_step { t.Error("retry_step should be true")}
	e = cmp.set_option("retry=false")
	if cmp.retry_step { t.Error("retry_step should be false")}
	e = cmp.set_option("retry=true")
	if !cmp.retry_step { t.Error("retry_step should be true")}
}

func Test_nxTraceChange(t *testing.T) {
	var cmp Comparator
	cmp.trace = &LnFile{}
	test_content:=`PC=C189,SP=FF,X=1,Y=80,A=0,P=33,IR=0,frame_cnt=c* C189: lda $50
PC=C189,SP=FF,X=1,Y=80,A=0,P=33,IR=0,frame_cnt=c* C189: lda $50
PC=C189,SP=FF,X=1,Y=80,A=0,P=33,IR=0,frame_cnt=c* C189: lda $50

   (interrupted at C189, IRQ 0)

PC=C19D,SP=FC,X=1,Y=80,A=1,P=37,IR=48,frame_cnt=d* C19D: pha
PC=C19E,SP=FB,X=1,Y=80,A=2,P=37,IR=DA,frame_cnt=d* C19E: phx
`
	cmp.trace.scn = bufio.NewScanner(strings.NewReader(test_content))
	cmp.trace.Scan()
	var mame_st MAMEState
	mame_st.data = parseTrace( cmp.trace.Text() )
	mame_st.alias=mameAlias{
		"PC": nil, "SP": nil, "X": nil, "Y": nil, "A": nil,
		"P": nil, "IR": nil, "frame_cnt": nil,
	}
	if mame_st.data["PC"]!=0xC189 { t.Error("Did not read first line well")}
	_, found := cmp.nxTraceChange(&mame_st)
	if !found {
		t.Log(mame_st.data)
		t.Error("Did not found new data!")
	}
	if mame_st.data["PC"]!=0xc19d { t.Error("Did not found the right line to stop at")}
}