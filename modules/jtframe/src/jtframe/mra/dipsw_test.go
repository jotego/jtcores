package mra

import(
	"slices"
	"testing"
)

var td struct { // Test Data
	mame MachineDIP
	cfg DipswCfg
}

func reset_tst_obj() {
	td.mame = MachineDIP{
		Name: "Maker",
		Dipvalue: []MAMEDIPValue{},
	}
	td.cfg = DipswCfg{
		Rename: []DipswCfgRename{
			{Name: "Maker", To: "Year", Values: []string{"1","2","3"} },
		},
	}
}

func Test_dip_rename(t *testing.T) {
	reset_tst_obj()
	td.cfg.rename(&td.mame)
	if td.mame.Name!="Year" { t.Errorf("Failed to rename")}

	td.mame = MachineDIP{ Name: "Other" }
	td.cfg.rename(&td.mame)
	if td.mame.Name!="Other" { t.Errorf("Should not rename")}

}

func Test_dip_rename_values(t *testing.T) {
	reset_tst_obj()
	td.mame.Dipvalue = []MAMEDIPValue{
		{Name: "a" },
		{Name: "b" },
		{Name: "c" },
	}
	td.cfg.rename(&td.mame)
	ref := td.cfg.Rename[0].Values
	got := make_strings(td.mame.Dipvalue)
	if slices.Compare(ref,got)!=0 {
		t.Errorf("DIP values not overwritten correctly")
	}
}

func make_strings(vv MAMEDIPValues) (ss []string) {
	ss = make([]string,len(vv))
	for k,v := range vv {
		ss[k]=v.Name
	}
	return ss
}