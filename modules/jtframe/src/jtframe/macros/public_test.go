package macros

import(
	"testing"
)

func Test_getint(t *testing.T) {
	macros["realint"]="12"
	macros["blank"]=""
	macros["alpha"]="alpha"
	if GetInt("realint")!=12 { t.Errorf("Wrong value")}
	if GetInt("blank")!=0 { t.Errorf("Blank values should get parsed as 0")}
	if GetInt("does not exist")!=0 { t.Errorf("Non existing macros should get parsed as 0")}
	panicked := false
	defer func() {
		recover()
		panicked = true

	}()
	GetInt("alpha")
	if !panicked { t.Errorf("Should panic for non convertible values")}
}