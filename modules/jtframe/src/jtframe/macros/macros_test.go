package macros

import(
	"testing"
)

func Test_set_sdram_refresh_rate(t *testing.T) {
	var mclk int64
	mclk = 48000000
	set_sdram_refresh_rate(mclk)
	if got, _ := macros["JTFRAME_RFSH_N"]; got !="9'd1" {
		t.Errorf("Bad JTFRAME_RFSH_N. Got %s", got )
	}
	if got, _ := macros["JTFRAME_RFSH_M"]; got !="9'd375" {
		t.Errorf("Bad JTFRAME_RFSH_M. Got %s", got )
	}
	if got, _ := macros["JTFRAME_RFSH_WC"]; got !="9" {
		t.Errorf("Bad JTFRAME_RFSH_WC. Got %s", got )
	}
}