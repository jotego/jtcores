package vcd

import(
	"testing"
)

func Test_parseTrace(t *testing.T) {
	match_parse_namevalue("AF=1234",NameValue{"AF":0x1234},t)
	match_parse_namevalue("AF=1234,DE=5678",NameValue{"AF":0x1234,"DE":0x5678},t)
	match_parse_namevalue("AF=  34",NameValue{"AF":0x0034},t)
	match_parse_namevalue("AF=  34,DE=  78",NameValue{"AF":0x0034,"DE":0x0078},t)
}

func match_parse_namevalue(trace string,expected NameValue,t *testing.T) {
	got := parseTrace(trace)
	if len(got)!=len(expected) {
		t.Error("Got wrong number of elements")
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