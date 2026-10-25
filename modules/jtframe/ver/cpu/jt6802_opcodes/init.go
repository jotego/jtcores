package main

import (
	"encoding/csv"
	"fmt"
	"os"
	"os/exec"
	"strconv"
)

func main() {
	// Generate the selected profile's includes in the simunit scratch directory.
	cmd := exec.Command("jtframe", "ucode", "jt680x", "6802", "--output", "6801")
	cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr
	if err := cmd.Run(); err != nil {
		panic(err)
	}

	// Sparse $A000 ROM, reset vector, and comparison words. The CPU accesses
	// this image through jtframe_ram's synchronous read path.
	program := []byte{
		0xce, 0x12, 0x00, // LDX #$1200
		0x0d,             // SEC
		0x8c, 0x12, 0x01, // CPX #$1201
		0x9c, 0x20, // CPX $0020
		0xac, 0x00, // CPX $00,X -> $1200
		0xbc, 0x00, 0x20, // CPX $0020 extended
		0x0c,             // CLC
		0x8c, 0x12, 0x01, // CPX #$1201
		0x9c, 0x20, // CPX $0020
		0xac, 0x00, // CPX $00,X -> $1200
		0xbc, 0x00, 0x20, // CPX $0020 extended
		0xce, 0x80, 0x00, // LDX #$8000
		0x0d,             // SEC
		0x8c, 0x00, 0x01, // CPX #$0001
		0x9c, 0x22, // CPX $0022
		0xac, 0x00, // CPX $00,X -> $8000
		0xbc, 0x00, 0x22, // CPX $0022 extended
		0x0c,             // CLC
		0x8c, 0x00, 0x01, // CPX #$0001
		0x9c, 0x22, // CPX $0022
		0xac, 0x00, // CPX $00,X -> $8000
		0xbc, 0x00, 0x22, // CPX $0022 extended
		0x01,             // NOP marker
		0x8e, 0x00, 0xff, // LDS #$00FF
		0x86, 0x7f, // LDAA #$7F
		0x26, 0x02, // BNE, Z=0, taken over LDAA #$AA
		0x86, 0xaa,
		0x27, 0x02, // BEQ, Z=0, not taken
		0x36,       // PSHA
		0x4f,       // CLRA
		0x32,       // PULA
		0x97, 0x30, // STAA $30
		0xce, 0x00, 0x30, // LDX #$0030
		0x6c, 0x00, // INC $00,X
		0x8d, 0x04, // BSR to $A04E
		0x86, 0xa5, // return path
		0x20, 0x03, // skip the subroutine body
		0x86, 0x33, // subroutine body
		0x39, // RTS
		0x01, // end marker
	}
	ordinary := []byte{
		0x8e, 0x00, 0x00, // LDS #$0000
		0x86, 0x7f, // LDAA #$7F
		0x8b, 0x01, // ADDA #$01 -> $80, N/V set
		0x97, 0x30, // STAA $30
		0x96, 0x30, // LDAA $30
		0xce, 0x12, 0x34, // LDX #$1234
		0xdf, 0x40, // STX $40
		0xde, 0x40, // LDX $40
		0xfe, 0x00, 0x50, // LDX $0050
		0xff, 0x00, 0x52, // STX $0052
		0xee, 0x00, // LDX $00,X from $ABCD
		0xef, 0x00, // STX $00,X to $5678
		0x86, 0x45, // LDAA #$45
		0x8b, 0x55, // ADDA #$55 -> $9A
		0x19,             // DAA -> $00 with C=1
		0x8e, 0x00, 0x00, // LDS #$0000
		0x86, 0x5a, // LDAA #$5A
		0x36,             // PSHA wraps from $0000 to $FFFF
		0x4f,             // CLRA
		0x32,             // PULA restores A and S
		0x8e, 0x12, 0x34, // LDS #$1234
		0x9f, 0x42, // STS $42
		0xbf, 0x00, 0x54, // STS $0054
		0x86, 0x0f, // LDAA #$0F
		0x0d,       // SEC
		0x89, 0x01, // ADCA #$01 -> $11
		0x86, 0x00, // LDAA #$00
		0x0d,       // SEC
		0x82, 0x00, // SBCA #$00 -> $FF
		0x86, 0x80, // LDAA #$80
		0x81, 0x01, // CMPA #$01, A preserved
		0x86, 0xf0, // LDAA #$F0
		0x84, 0x0f, // ANDA #$0F -> $00
		0x88, 0x55, // EORA #$55
		0x8a, 0x80, // ORAA #$80 -> $D5
		0x86, 0x10, // LDAA #$10
		0x80, 0x01, // SUBA #$01 -> $0F
		0x86, 0x81, // LDAA #$81
		0x48, // ASLA -> $02, C/V set
		0x44, // LSRA -> $01, C clear
		0x46, // RORA -> $00, C set
		0x01, // marker
	}
	f, err := os.Create("program.hex")
	if err != nil {
		panic(err)
	}
	defer f.Close()
	fmt.Fprintln(f, "@a000")
	for _, b := range program {
		fmt.Fprintf(f, "%02x\n", b)
	}
	fmt.Fprintln(f, "@0020\n12\n01\n@0022\n00\n01\n@1200\n12\n01\n@8000\n00\n01\n@0050\nab\ncd\n@abcd\n56\n78\n@fffe\na0\n00")
	fmt.Fprintln(f, "@b000")
	for _, b := range ordinary {
		fmt.Fprintf(f, "%02x\n", b)
	}

	// The timing loop reads this independent 256-entry table; bit 15 marks a
	// documented byte, bits 11:8 carry the Motorola E-cycle count, and bits
	// 2:0 identify the addressing form used to seed operand bytes.
	csvFile, err := os.Open("manual-opcodes.csv")
	if err != nil {
		panic(err)
	}
	defer csvFile.Close()
	rows, err := csv.NewReader(csvFile).ReadAll()
	if err != nil {
		panic(err)
	}
	modes := map[string]int{"inherent": 0, "relative": 1, "immediate": 2, "direct": 3, "indexed": 4, "extended": 5}
	words := make([]uint16, 256)
	for _, row := range rows[1:] {
		op, _ := strconv.ParseUint(row[0], 16, 8)
		cycles, _ := strconv.ParseUint(row[3], 10, 4)
		words[op] = 0x8000 | uint16(cycles)<<8 | uint16(modes[row[2]])
	}
	mf, err := os.Create("manifest.hex")
	if err != nil {
		panic(err)
	}
	defer mf.Close()
	for _, word := range words {
		fmt.Fprintf(mf, "%04x\n", word)
	}
}
