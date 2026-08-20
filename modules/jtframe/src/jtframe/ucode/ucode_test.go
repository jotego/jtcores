/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Author: Jose Tejada Gomez. Twitter: @topapate */

package ucode

import "testing"

func Test_fix_cycles_adds_leading_idle_cycles(t *testing.T) {
	desc := UcDesc{}
	desc.Cfg.EntryLen = 16
	desc.Cfg.Entries = 1
	desc.Cfg.CycleK = 4
	desc.Ops = []UcOp{{Name: "EXEC", Op: 0, Cycles: 2}}
	code := make([]string, 16)
	code[0] = "DO NI"
	fix_cycles(code, &desc, false)
	if code[0] != "" || code[7] != "DO NI" {
		t.Fatalf("expected the instruction to be delayed by seven microcycles: %#v", code[:8])
	}
	if actual := calc_cycles(0, code, true, &desc, nil); actual != 8 {
		t.Fatalf("expected 8 microcycles after padding, got %d", actual)
	}
}
