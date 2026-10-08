package common

import(
	"bufio"
	"bytes"
	"io"
	"testing"
)

func Test_Hex64Reader( t *testing.T ) {
	data := []uint64{
		0x12fafe12347ea555,0x4621,
	}
	exp := "12FAFE12347EA555\n0000000000004621\n"
	hex := MakeHexReader(data)
	test_reader(hex, exp, t)
}

func test_reader( hex io.Reader, exp string, t *testing.T) {
	totest := bufio.NewScanner(hex)
	ref := bufio.NewScanner(bytes.NewReader([]byte(exp)))
	for totest.Scan() {
		ref.Scan()
		line := totest.Text()
		ref_txt := ref.Text()
		if line!=ref_txt {
			t.Log("Got",line)
			t.Log("Expected",ref_txt)
			t.Error("Mismatch")
			break
		}
	}
}

func Test_Hex32Reader( t *testing.T ) {
	data := []uint32{
		0x12fafe12,0x347ea555,0x4621,
	}
	exp := "12FAFE12\n347EA555\n00004621\n"
	hex := MakeHexReader(data)
	test_reader(hex, exp, t)
}

func Test_Hex16Reader( t *testing.T ) {
	data := []uint16{
		0x12,0xfafe,0x1234,0x7ea5,0x55,0x4621,
	}
	exp := "0012\nFAFE\n1234\n7EA5\n0055\n4621\n"
	hex := MakeHexReader(data)
	test_reader(hex, exp, t)
}

func Test_Hex8Reader( t *testing.T ) {
	data := []byte{
		0x12,0xfa,0xfe,0x12,0x34,0x7e,0xa5,0x55,0x46,0x21,
	}
	exp := "12\nFA\nFE\n12\n34\n7E\nA5\n55\n46\n21\n"
	hex := MakeHexReader(data)
	test_reader(hex, exp, t)
}

func Test_Bin16Reader( t *testing.T ) {
	data := []uint16{
		0x12,0xfa7e,
	}
	exp := "10010\n1111101001111110\n"
	hex := MakeBinReader(data)
	test_reader(hex, exp, t)
}