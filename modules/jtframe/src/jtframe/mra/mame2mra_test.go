package mra

import(
	"testing"
)

func Test_get_altdir_name(t *testing.T) {
	dirname := get_altdir_name("Teenage Mutant Hero Turtles - Turtles in Time (2 Players ver EBA)")
	if dirname!="Turtles in Time" {
		t.Log(dirname)
		t.Errorf("Bad dir name")
	}
}