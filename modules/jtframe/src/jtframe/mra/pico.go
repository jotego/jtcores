package mra

import (
	"bufio"
	"encoding/binary"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

func store(data []byte, data_size *int, val int64) {
	data[*data_size] = byte(val & 0xff)
	val >>= 8
	*data_size++
	data[*data_size] = byte(val & 0xff)
	*data_size++
}

func basename(s string) string {
	i := strings.LastIndex(s, ".")
	if i == -1 {
		return s
	} else {
		return s[0:i]
	}
}

func swap_bits(d *byte, bit0, bit1 int) {
	e := *d
	val0 := ((*d) >> bit0) & 1
	val1 := ((*d) >> bit1) & 1
	e = e & ((1 << bit0) ^ 0xff)
	e = e & ((1 << bit1) ^ 0xff)
	e = e | (val0 << bit1)
	e = e | (val1 << bit0)
	*d = e
}

func encrypt_data(data []byte, code int) {
	for k, d := range data {
		mask := k ^ code
		e := d
		for bit := 3; bit >= 0; bit-- {
			if (mask & (0x10 << bit)) != 0 {
				swap_bits(&e, bit*2, bit*2+1)
			}
		}
		e = e ^ byte(code>>8)
		// second swap
		for bit := 3; bit >= 0; bit-- {
			if (mask & (1 << bit)) != 0 {
				swap_bits(&e, bit*2, bit*2+1)
			}
		}
		data[k] = e
	}
}

// convert the hex dump produced by opbasm (Open PicoBlaze Assembler)
// to an 8-bit hex format
//
func pico2hex(filename string, encrypt int16) []byte {
	file, err := os.Open(filename)
	if err != nil {
		log.Fatal(err)
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	data := make([]byte, 4096)
	data_size := 0
	var rest int64
	bytecnt := 0
	rest = 0
	for scanner.Scan() {
		s := strings.TrimSpace(scanner.Text())
		if len(s) == 0 || s[0] == '@' {
			continue
		}
		val, _ := strconv.ParseInt(s, 16, 0)
		switch bytecnt & 3 {
		case 0:
			{
				store(data[:], &data_size, val)
				rest = (val >> 16) & 3 // 2 bits left
			}
		case 1:
			{
				val = (val << 2) | (rest & 3) // 20 bits
				store(data[:], &data_size, val)
				rest = (val >> 16) & 0xf // 4 bits left
			}
		case 2:
			{
				val = (val << 4) | (rest & 0xf) // 22 bits
				store(data[:], &data_size, val)
				rest = (val >> 16) & 0x3f // 6 bits left
			}
		case 3:
			{
				val = (val << 6) | (rest & 0x3f) // 24 bits
				store(data[:], &data_size, val)
				val = val >> 16
				data[data_size] = byte(val & 0xff)
				data_size++
				rest = 0
			}
		}
		bytecnt++
	}

	if encrypt != 0 {
		encrypt_data(data[0:data_size], int(encrypt))
	}
	return data[0:bytecnt]
}

func dump_bin(fname string, data []byte) {
	f, err := os.Create(fname)
	defer f.Close()
	if err != nil {
		fmt.Println("Error creating binary file: ", err)
		return
	}
	err = binary.Write(f, binary.LittleEndian, data)
	if err != nil {
		fmt.Println("Error creating binary file: ", err)
		return
	}
}

func picoasm(filename string, cfg Mame2MRA, args Args) []byte {
	olddir, _ := os.Getwd()
	path := filepath.Join(os.Getenv("CORES"), args.Def_cfg.Core, "cheat")
	// Check if the cheat folder exists
	f, e := os.Open(path)
	folder_ok := e == nil
	f.Close()
	e = os.Chdir(path)
	defer os.Chdir(olddir)
	if e != nil {
		if folder_ok || args.Verbose { // only warns when the core/cheat folder exists but the file was not present
			fmt.Printf("Warning: cannot open %s/%s\n", path, filename)
		}
		return nil
	}
	// Open PicoBlaze Assembler
	// https://github.com/kevinpt/opbasm.git
	cmd := exec.Command("opbasm", "-6", "-x", "-m", "1024", filename)
	if cmd.Run() != nil {
		return nil
	}
	re := regexp.MustCompile("\\..*$")
	basename := re.ReplaceAllString(filename, "")
	hexfile := basename + ".hex"
	binfile := basename + ".bin"
	data := pico2hex(hexfile, 0)
	if !args.JTbin { // Prepare a zip if needed
		dump_bin(binfile, data)
		// Zip the binary
		zipfile := filepath.Join(args.cheatdir, basename+"_cheat.zip")
		os.MkdirAll(args.cheatdir, 0775)
		cmd = exec.Command("zip", zipfile, basename+".bin")
		cmd.Run()
	}
	return data
}
