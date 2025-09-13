package mmr

import(
	"bufio"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"

	"gopkg.in/yaml.v2"
)

func Test_generate(t *testing.T) {
	text := `
- name: cus30
  size: 63
  read_only: true
  regs:
    - name: lvol
      desc: "left volume"
      dw: 0o40
      at: "000[3:0],010[3:0],020[3:0],030[3:0],040[3:0],050[3:0],060[3:0],070[3:0]"
    - name: rvol
      desc: "right volume"
      dw: 0o40
      at: "004[3:0],014[3:0],024[3:0],034[3:0],044[3:0],054[3:0],064[3:0],074[3:0]"
    - name: no_en
      desc: "noise enable"
      dw: 0o10
      at: "074[7],004[7],014[7],024[7],034[7],044[7],054[7],064[7]"
    - name: wsel
      desc: "waveform selection"
      dw: 0o40
      at: "001[7:4],011[7:4],021[7:4],031[7:4],041[7:4],051[7:4],061[7:4],071[7:4]"
    - name: freq
      dw: 0o240 # 20 bits per channel
      desc: "frequency"
      at: "001[3:0],002,003,011[3:0],012,013,021[3:0],022,023,031[3:0],032,033,041[3:0],042,043,051[3:0],052,053,061[3:0],062,063,071[3:0],072,073"
    - name: ack
      wr_event: true
      at: "077"
`
	var mmr = mmr_gen{
		corename: "shouse",
	}
	e := yaml.Unmarshal( []byte(text), &mmr.cfg ); if e != nil { t.Error(e) }
	mmr.generate()
	if total:=len(mmr.converted); total!=1 {
		t.Errorf("Expected one conversion, got %d",total)
		return
	}
	const ref_filename="test_ref.v"
	ref_file := add_path_from_this_file(ref_filename)
	ref, e := os.ReadFile(ref_file)
	if e!=nil {
		t.Error(e)
		return
	}
	if len(mmr.converted[0])==0 { t.Error("Empty conversion"); return }
	compare(string(ref),mmr.converted[0],t)
	os.WriteFile(ref_filename,[]byte(mmr.converted[0]),0644) // uncomment to update the reference file
}

func add_path_from_this_file(fname string) string {
	_,file,_,_ := runtime.Caller(0)
	dirname := filepath.Dir(file)
	return filepath.Join(dirname,fname)
}

func compare(ref_str, rslt_str string, t *testing.T) {
	ref  := bufio.NewScanner(strings.NewReader(ref_str))
	rslt := bufio.NewScanner(strings.NewReader(rslt_str))
	line := 0
	for rslt.Scan() {
		line++
		rslt_txt := rslt.Text()
		if !ref.Scan() {
			t.Errorf("result string has more lines than the reference.")
			return
		}
		ref_txt := ref.Text()
		if len(ref_txt)!=len(rslt_txt) {
			t.Log(ref_txt)
			t.Log(rslt_txt)
			t.Errorf("Line %d has different length",line)
			return
		}
		for k,_ := range rslt_txt {
			if rslt_txt[k]!=ref_txt[k] {
				t.Errorf("Different at line %d, column %d",line,k+1)
				return
			}
		}
	}
}