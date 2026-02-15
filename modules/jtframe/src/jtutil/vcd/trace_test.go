package vcd

import(
	"testing"
)

func Test_trace_parser_t(t * testing.T) {
	nv := parseTrace("A=5,B=4* myline")
	if nv["A"]!=5 { t.Error("Did not read A correctly") }
	if nv["B"]!=4 { t.Error("Did not read B correctly") }
	nv = parseTrace("")
	if len(nv)!=0 { t.Error("Should be zero for empty lines")}
	nv = parseTrace("A=5,B=40,PC=1234* RTI")
	if nv["PC"]!=0x1234 { t.Error("Did not read PC correctly") }
	if nv["RTI"]!=1 { t.Error("Did not detect RTI")}
	nv = parseTrace("  (interrupted at C189, IRQ 0)")
	if len(nv)!=0 { t.Error("Did not ignore comment line correctly")}
}

func Test_trace_parser_longer(t *testing.T) {
	match_parse_namevalue("AF=1234",NameValue{"AF":0x1234},t)
	match_parse_namevalue("AF=1234,DE=5678",NameValue{"AF":0x1234,"DE":0x5678},t)
	match_parse_namevalue("AF=  34",NameValue{"AF":0x0034},t)
	match_parse_namevalue("AF=  34,DE=  78",NameValue{"AF":0x0034,"DE":0x0078},t)
}

func match_parse_namevalue(trace string,expected NameValue,t *testing.T) {
	got := parseTrace(trace)
	if len(got)!=len(expected) {
		t.Errorf("Got wrong number of elements: %d vs %d", len(got), len(expected))
		return
	}
	for name,val := range got {
		exp,found := expected[name]
		if !found {
			t.Errorf("Missing value for %s",name)
			return
		}
		if exp != val {
			t.Errorf("Wrong value for %s",name)
			return
		}
	}
}