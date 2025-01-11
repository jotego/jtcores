package cmd

import(
	"testing" 
)

func Test_valid_core(t *testing.T) {
	if e:=valid_core("gng");e!=nil { t.Errorf("gng should be a valid name, but got %s",e.Error())}
	if e:=valid_core("");e==nil { t.Errorf("a blank should not be a valid name")}
	if e:=valid_core(".");e==nil { t.Errorf("'.' should not be a valid name")}
	if e:=valid_core("..");e==nil { t.Errorf("'..' should not be a valid name")}
	if e:=valid_core("cores/gng");e==nil { t.Errorf("cores/gng should not be a valid name")}
}
