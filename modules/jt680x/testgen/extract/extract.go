package extract

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"

	"gopkg.in/yaml.v2"
)

func (ex *Extractor)Extract(testName string) error {
	tb, e := read_yaml(testName); if e!=nil { return e }
	asm_file := ""
	if ex.Keep { asm_file = "test.asm" }
	e = tb.WriteAsm(asm_file); if e!=nil { return e }
	e = tb.Assemble();         if e!=nil { return e }
	e = tb.SaveMem();          if e!=nil { return e }
	e = tb.SaveTestVectors();  if e!=nil { return e }
	if !ex.Keep {
		tb.CleanUp()
	}
	ex.DisplayVerilogMacros(&tb)
	return nil
}

func read_yaml(testName string) (AsmTest,error) {
	buf, e := os.ReadFile("tests.yaml")
	if e!=nil { return AsmTest{},fmt.Errorf("Cannot read file %s: %w", testName, e) }
	var entries map[string]AsmTest
	e = yaml.Unmarshal(buf, &entries)
	if e!=nil { return AsmTest{},fmt.Errorf("Error while parsing file %s: %w", testName, e) }
	asmtest, found := entries[testName]
	if !found { return AsmTest{},fmt.Errorf("Cannot find test %s in tests.yaml", testName) }
	asmtest.Name = testName
	return asmtest, nil
}

func (tb *AsmTest)WriteAsm(filename string) error {
	if len(tb.Test)==0 { return fmt.Errorf("Test %s does not contain assembly code", tb.Name )}
	var f *os.File
	var e error
	if filename=="" {
		f, e = os.CreateTemp(".","*.asm")
	} else {
		f, e = os.Create(filename)
	}
	if e!=nil { return e }
	defer f.Close()
	fmt.Fprintf(f,"CPU 65C02\nPAGE 0,132\n* = $F000\n")
	tb.asm_lines=0
	for _, line := range tb.Test {
		if line.Asm=="" {fmt.Errorf("All test lines must have a non-empty asm field")}
		fmt.Fprintf(f,"%s\n",line.Asm)
		if tb.is_org(line.Asm) { continue }
		tb.asm_lines++
	}
	fmt.Fprintf(f,"NOP\nNOP\nNOP\nNOP\n")
	tb.asm_file = f.Name()
	return nil
}

func (tb *AsmTest)is_org(line string) bool {
	trim := strings.TrimSpace(line)
	return trim[0]=='*'
}

func (tb *AsmTest)Assemble() error {
	if tb.asm_file=="" {return fmt.Errorf("Call WriteAsm first")}
	tb.hex_file = tb.asm_file[0:len(tb.asm_file)-4]+".s"
	cmd := exec.Command("./crasm",tb.asm_file,"-o",tb.hex_file)
	log, e := cmd.Output()
	if e!=nil {return fmt.Errorf("Problem while running crasm:\n%w",e)}
	logstr := string(log)
	if strings.Index(logstr,"ERRORS:       0")==-1 {
		return fmt.Errorf("%s",logstr)
	}
	return nil
}

func (tb *AsmTest)SaveMem() (e error) {
	tb.reset_mem()
	e = tb.parse_mem_entries(); if e!=nil {return e}
	e = tb.parse_program();     if e!=nil {return e}
	e = tb.dump_mem("mem.bin"); if e!=nil {return e}
	return nil
}

func (tb *AsmTest)reset_mem() {
	for k,_ := range tb.mem {
		tb.mem[k] = 0
	}
	const code_page=0xf0;
	const reset_vector=0xfffc
	const rst_vector_msb=reset_vector+1
	tb.mem[rst_vector_msb]=code_page;
}

func (tb *AsmTest)parse_mem_entries() error {
	for k, cfg := range tb.Mem {
		if cfg.From<0 || cfg.From>0xffff {
			return fmt.Errorf("Wrong value for FROM in memory entry. Found $%X",cfg.From)
		}
		e := tb.parse_mem_data(k)
		if e!=nil { return e }
	}
	return nil
}

func (tb *AsmTest)parse_mem_data(idx int) error {
	from := tb.Mem[idx].From
	filtered := strings.ReplaceAll(tb.Mem[idx].HexData,"\n"," ")
	parts := strings.Split(filtered," ")
	if len(parts)==0 {return fmt.Errorf("Memory line contains no data")}
	for _, hex := range parts {
		if hex=="" { continue }
		if from>0xffff { return fmt.Errorf("Memory data goes beyond 0xFFFF") }
		if len(hex)>2 {
			return fmt.Errorf("Invalid hex entry '%s' in memory data",hex)
		}
		value, e := strconv.ParseInt(hex,16,32)
		if e!=nil { return e }
		tb.mem[from] = byte(value)
		from++
	}
	return nil
}

func (tb *AsmTest)parse_program() error {
	f, e := os.Open(tb.hex_file); if e!=nil { return e }
	defer f.Close()
	scn := bufio.NewScanner(f)
	count := 0
	for scn.Scan() {
		count++
		line := scn.Text()
		if line=="" { continue }
		if line[0]!='S' {
			return fmt.Errorf("Each line in the Motorola S code file should start with an S but found %s at line %d",line,count)
		}
		if line[1]=='9' { break }
		if line[1]!='1' { return fmt.Errorf("Unexpected line %d in S code file: %s",count,line)}
		bytecount, e := strconv.ParseInt(line[2:4],16,32)
		if e!=nil { return fmt.Errorf("Wrong byte count at line %d: %s",count,line[2:4])}
		const address_bytes  = 2
		const checksum_bytes = 1
		bytecount -= address_bytes + checksum_bytes
		addr, e := strconv.ParseInt(line[4:8],16,32)
		if e!=nil { return fmt.Errorf("Wrong address value at line %d: %s",count,line[4:8])}
		idx := 8
		for k:=0; k<int(bytecount); k++ {
			if addr>0xffff {
				return fmt.Errorf("Cannot write past 0xffff")
			}
			value, e := strconv.ParseInt(line[idx:idx+2],16,32)
			if e!=nil { return fmt.Errorf("Invalid hex value at line %d: %s",count,line)}
			tb.mem[addr] = byte(value)
			addr++
			idx+=2
		}
	}
	return nil
}

func (tb *AsmTest)dump_mem(fname string) error {
	return os.WriteFile(fname,tb.mem[:],0666)
}

func (tb *AsmTest)CleanUp() {
	os.Remove(tb.hex_file)
	os.Remove(tb.asm_file)
	tb.hex_file = ""
	tb.asm_file = ""
}

func (ex *Extractor)DisplayVerilogMacros(tb *AsmTest) {
	fmt.Printf("-DOPCNT=%d\n",tb.GetAsmCnt())
}

func (tb *AsmTest)GetAsmCnt() int {
	return tb.asm_lines
}

func (tb *AsmTest)SaveTestVectors() error {
	e := tb.make_test_vectors(); if e!=nil {return e}
	e  = tb.dump_test_vectors()
	return e
}

func (tb *AsmTest)make_test_vectors() error {
	var vector test_vector
	vector.i = 1
	vector.S = 0xfd
	tb.all_vectors = make([]test_vector,len(tb.Test))
	k := 0
	for _, line := range tb.Test {
		if tb.is_org(line.Asm) { continue }
		if line.Check=="" {
			tb.all_vectors[k] = vector
			k++
			continue
		}
		parts := strings.Split(line.Check,",")
		e := vector.update(parts)
		if e!=nil {return fmt.Errorf("Error in %s: %w",line.Check,e)}
		tb.all_vectors[k] = vector
		k++
	}
	return nil
}

func (tv *test_vector)update(parts []string) error {
	for _, pair := range parts {
		pair = strings.TrimSpace(pair)
		pair = strings.ToUpper(pair)
		kv := strings.Split(pair,"=")
		if len(kv)!=2 {
			return fmt.Errorf("No pair value for %s",pair)
		}
		kv[1] = strings.ReplaceAll(kv[1],"$","0x")
		value, e := strconv.ParseInt(kv[1],0,32); if e!=nil {return e}
		v := int(value)
		switch(kv[0]) {
		case "A": tv.A = v
		case "X": tv.X = v
		case "Y": tv.Y = v
		case "S": tv.S = v
		case "V": tv.v = v & 1
		case "N": tv.n = v & 1
		case "Z": tv.z = v & 1
		case "C": tv.c = v & 1
		case "D": tv.d = v & 1
		case "I": tv.i = v & 1
		default:
			return fmt.Errorf("Unsupported name %s",kv[0])
		}
	}
	return nil
}

func (tb *AsmTest)dump_test_vectors() error {
	vec_file := tb.asm_file[0:len(tb.asm_file)-4]+".tv"
	f, e := os.Create(vec_file); if e!=nil {return e}
	defer f.Close()
	for _, v := range tb.all_vectors {
		P := v.get_flags()
		fmt.Fprintf(f,"%02X%02X%02X%02X%02X\n",v.A,v.X,v.Y,v.S,P)
	}
	for k:=len(tb.all_vectors);k<256;k++ {
		fmt.Fprintf(f,"0\n")
	}
	return nil
}

func (tv *test_vector)get_flags() int {
	return (tv.n<<7) | (tv.v<<6) | 0x20 | (tv.d<<3) | (tv.i<<2) | (tv.z<<1) | (tv.c)
}