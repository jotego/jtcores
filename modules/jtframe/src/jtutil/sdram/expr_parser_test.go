package sdram

import (
	"testing"

	"jotego/jtframe/macros"
	"jotego/jtframe/mem"
)

func TestExpressionResolverEvaluatesParamsAndMacros(t *testing.T) {
	macros.MakeFromMap(map[string]string{
		"JTFRAME_BA2_START": "0x200000",
		"SCR_START":         "0x280000",
		"JTFRAME_HEADER":    "0x100",
	})
	params := []mem.Param{
		{Name: "SCR_OFFSET", Value: "(`SCR_START-`JTFRAME_BA2_START)>>1"},
		{Name: "SCR_NEXT", Value: "SCR_OFFSET+16"},
		{Name: "CONST_HEX", Value: "'h30000"},
	}
	resolver := newExpressionResolver(params)
	got, err := resolver.eval("SCR_NEXT+`JTFRAME_HEADER")
	if err != nil {
		t.Fatalf("eval returned error: %v", err)
	}
	if got != (0x40000 + 16 + 0x100) {
		t.Fatalf("eval mismatch: got=%X", got)
	}
	got, err = resolver.eval("CONST_HEX")
	if err != nil {
		t.Fatalf("eval const returned error: %v", err)
	}
	if got != 0x30000 {
		t.Fatalf("const mismatch: got=%X want=%X", got, 0x30000)
	}
}

func TestExpressionResolverUsesMacroForEmptyParamValue(t *testing.T) {
	macros.MakeFromMap(map[string]string{
		"OBJ_OFFSET": "0x1800",
	})
	params := []mem.Param{
		{Name: "OBJ_OFFSET", Value: ""},
	}
	resolver := newExpressionResolver(params)
	got, err := resolver.eval("OBJ_OFFSET")
	if err != nil {
		t.Fatalf("eval returned error: %v", err)
	}
	if got != 0x1800 {
		t.Fatalf("eval mismatch: got=%X want=%X", got, 0x1800)
	}
}
