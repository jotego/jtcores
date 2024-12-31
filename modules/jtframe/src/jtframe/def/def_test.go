package def

import(
	"testing"
)

func Test_make_commit_macro(t *testing.T) {
	if make_commit_macro("019ff900a")!="019ff90" { t.Error("Bad value")}
	if make_commit_macro("019ff900a_dirty")!="019ff90" { t.Error("Bad value")}
	if make_commit_macro("nocommit")!="0" { t.Error("Bad value")}
}