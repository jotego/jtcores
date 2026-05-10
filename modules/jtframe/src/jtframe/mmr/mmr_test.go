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
      event: write
      at: "077"
`
	var mmr = mmr_gen{
		corename: "shouse",
	}
	e := yaml.Unmarshal( []byte(text), &mmr.cfg ); if e != nil { t.Error(e) }
	e = mmr.generate(); if e != nil { t.Error(e); return }
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
	if os.Getenv("UPDATE_MMR_REF")!="" {
		e = os.WriteFile(ref_file,[]byte(mmr.converted[0]),0644)
		if e!=nil { t.Error(e) }
		return
	}
	compare(string(ref),mmr.converted[0],t)
}

func Test_parse_hex_range(t *testing.T) {
	reg := Register{
		Name: "hex_range",
		At: "0x00[1:0], 0x01",
	}
	var mmr = mmr_gen{
		bits: make([]int,1024*8),
	}
	e := reg.parse_chunks(&mmr); if e != nil { t.Fatal(e) }
	if len(reg.Chunks) != 2 {
		t.Fatalf("Expected 2 chunks, got %d",len(reg.Chunks))
	}
	if reg.Chunks[0] != (Chunk{Byte: 0, Msb: 1, Lsb: 0}) {
		t.Fatalf("Unexpected first chunk: %+v",reg.Chunks[0])
	}
	if reg.Chunks[1] != (Chunk{Byte: 1, Msb: 7, Lsb: 0}) {
		t.Fatalf("Unexpected second chunk: %+v",reg.Chunks[1])
	}
}

func Test_event_default_and_validation(t *testing.T) {
	var mmr = mmr_gen{
		bits: make([]int,1024*8),
	}
	reg := Register{
		Name: "plain",
		Dw: 8,
		At: "0x00",
	}
	e := reg.parse(&mmr,8); if e != nil { t.Fatal(e) }
	if reg.Event != event_none || reg.IsEvent() {
		t.Fatalf("Expected default non-event, got %q",reg.Event)
	}
	bad := Register{
		Name: "bad",
		Event: "invalid",
		At: "0x00",
	}
	e = bad.parse(&mmr,8)
	if e == nil { t.Fatal("Expected invalid event error") }
	one := Register{
		Name: "one",
		Event: event_one,
		At: "0x00",
	}
	e = one.parse(&mmr,8)
	if e == nil { t.Fatal("Expected bit-qualified location error") }
}

func Test_event_conditions(t *testing.T) {
	text := `
- name: evtest
  size: 16
  dw: 16
  regs:
    - { name: plain,   dw: 8, at: "0x00" }
    - { name: evwrite, event: write, at: "0x04" }
    - { name: evany,   event: any,   at: "0x05" }
    - { name: evone,   event: one,   at: "0x05[3]" }
    - { name: evzero,  event: zero,  at: "0x06[0]" }
`
	var mmr = mmr_gen{
		corename: "test",
	}
	e := yaml.Unmarshal( []byte(text), &mmr.cfg ); if e != nil { t.Fatal(e) }
	e = mmr.generate(); if e != nil { t.Fatal(e) }
	got := mmr.converted[0]
	must_contain(t, got, "if(cs && !rnw && addr=='d2 && !dsn[0]) evwrite <= 1;")
	must_contain(t, got, "if(cs && addr=='d2 && (rnw || !dsn[1])) evany <= 1;")
	must_contain(t, got, "if(cs && !rnw && addr=='d2 && !dsn[1] && din[11]==1'b1) evone <= 1;")
	must_contain(t, got, "if(cs && !rnw && addr=='d3 && !dsn[0] && din[0]==1'b0) evzero <= 1;")
}

func must_contain(t *testing.T, got, want string) {
	t.Helper()
	if !strings.Contains(got,want) {
		t.Fatalf("Expected generated output to contain %q",want)
	}
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
