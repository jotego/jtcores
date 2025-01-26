package common

import(
	"bytes"
	"golang.org/x/exp/constraints"
	"io"
	"fmt"
)

func MakeHexReader[S ~[]E, E constraints.Integer](data S) (io.Reader) {
	bytechunk := MakeHexBytes(data)
	return bytes.NewReader(bytechunk)
}

func MakeHexBytes[S ~[]E, E constraints.Integer](data S) []byte {
	chars := make([]byte,0,len(data)*4)
	for k,_ := range data {
		s := hex_format(data[k])
		chars = append(chars,[]byte(s)...)
	}
	return chars
}

func hex_format(data any) string {
	switch t := data.(type) {
		case int16, uint16: return fmt.Sprintf("%04X\n",data)
		case int32,uint32: return fmt.Sprintf("%08X\n",data)
		case int, uint,int64,uint64: return fmt.Sprintf("%016X\n",data)
		case int8, uint8: return fmt.Sprintf("%02X\n",data)
		default: panic(fmt.Sprintf("unsupported type %T",t))
	}
}

func MakeBinReader[S ~[]E, E constraints.Integer](data S) (io.Reader) {
	bytechunk := MakeBinBytes(data)
	return bytes.NewReader(bytechunk)
}

func MakeBinBytes[S ~[]E, E constraints.Integer](data S) []byte {
	chars := make([]byte,0,len(data)*4)
	for k,_ := range data {
		s := fmt.Sprintf("%b\n",data[k])
		chars = append(chars,[]byte(s)...)
	}
	return chars
}