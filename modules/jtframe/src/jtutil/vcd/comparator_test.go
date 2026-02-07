package vcd

import(
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