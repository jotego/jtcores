package cmd

import(
	"testing"
)

func Test_compare(t *testing.T) {
	var new, ref MRACollection
	ref = MRACollection{
		&MRA{Setname:"a",Rom: []MRAROM{ MRAROM{Index: 0, Md5: "1234"} }},
		&MRA{Setname:"b",Rom: []MRAROM{ MRAROM{Index: 0, Md5: "5678"} }},
		&MRA{Setname:"c",Rom: []MRAROM{ MRAROM{Index: 0, Md5: "9abc"} }},
	}

	var diff []string
	if diff = compare_md5(ref,ref); diff!=nil {
		t.Log(diff)
		t.Errorf("Selfcomparison should be true")
	}
	if diff = compare_md5(new,ref); diff!=nil { t.Errorf("Comparison to nil should be nil")}
	if diff = compare_md5(ref,new); diff!=nil { t.Errorf("Comparison to nil should be nil")}

	new = MRACollection{
		&MRA{Setname:"a",Rom: []MRAROM{ MRAROM{Index: 0, Md5: "1234"} }},
	}
	if diff = compare_md5(new,ref); diff!=nil {
		t.Errorf("Missing setnames should be ok")
	}

	new = MRACollection{
		&MRA{Setname:"a",Rom: []MRAROM{ MRAROM{Index: 0, Md5: "1235"} }},
	}
	if diff = compare_md5(new,ref); diff==nil { t.Errorf("Must detect differences") }

	new = MRACollection{
		&MRA{Setname:"b",Rom: []MRAROM{ MRAROM{Index: 0, Md5: "1234"} }},
	}
	if diff = compare_md5(new,ref); diff==nil || len(diff)!=1 || diff[0]!="b" {
		t.Errorf("Must compare matching sets")
	}

	new = MRACollection{
		&MRA{Setname:"a",Rom: []MRAROM{ MRAROM{Index: 0, Md5: "5678"} }},
		&MRA{Setname:"b",Rom: []MRAROM{ MRAROM{Index: 0, Md5: "5678"} }},
		&MRA{Setname:"d",Rom: []MRAROM{ MRAROM{Index: 0, Md5: "1234"} }},
	}
	if diff = compare_md5(new,ref); diff==nil || len(diff)!=1 || diff[0]!="a" {
		t.Errorf("Must find differences")
	}
}