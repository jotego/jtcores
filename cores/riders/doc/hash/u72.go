package main

import (
	"bufio"
	"encoding/binary"
	"encoding/hex"
	"fmt"
	"log"
	"os"
)

type Uint72 struct {
	lo uint64
	hi uint8
}

func (it Uint72) BitAt(p int) int {
	if p < 64 {
		return int((it.lo >> uint(p)) & 1)
	}
	return int((it.hi >> uint(p-64)) & 1)
}

func (it *Uint72) SetBit(pos int) {
	if pos < 64 {
		it.lo |= 1 << uint(pos)
	} else {
		it.hi |= 1 << uint(pos-64)
	}
}

func (it *Uint72) ResetBit(pos int) {
	if pos < 64 {
		it.lo &^= 1 << uint(pos)
	} else {
		it.hi &^= 1 << uint(pos-64)
	}
}

func (it *Uint72) Set() {
	it.lo = 0xFFFFFFFFFFFFFFFF
	it.hi = 0xFF
}

func (it *Uint72) Reset() {
	it.lo = 0
	it.hi = 0
}

func (it *Uint72) SetValue(b []byte) {
	if len(b) != 9 {
		panic(fmt.Sprintf("setValue: expected 9 bytes, got %d", len(b)))
	}

	it.lo = binary.LittleEndian.Uint64(b[:8])
	it.hi = b[8]
}

func (lhs Uint72) And(rhs Uint72) Uint72 {
	return Uint72{
		lo: lhs.lo & rhs.lo,
		hi: lhs.hi & rhs.hi,
	}
}

func (lhs Uint72) Or(rhs Uint72) Uint72 {
	return Uint72{
		lo: lhs.lo | rhs.lo,
		hi: lhs.hi | rhs.hi,
	}
}

func readItems(f *os.File) []Uint72 {
	sc := bufio.NewScanner(f)
	sc.Buffer(make([]byte, 0, 1024), 1024*1024)
	var items []Uint72
	for sc.Scan() {
		line := sc.Text()
		if line == "" {
			continue
		}
		if len(line) >= 2 && (line[:2] == "0x" || line[:2] == "0X") {
			line = line[2:]
		}
		b, err := hex.DecodeString(line)
		if err != nil || len(b) != 9 {
			log.Fatalf("invalid line (expected 9 hex): %q", line)
		}
		var it Uint72
		it.SetValue(b)
		items = append(items, it)
	}
	if err := sc.Err(); err != nil {
		log.Fatal(err)
	}
	return items
}

func hasDuplicates(items []Uint72) bool {
	seen := make(map[Uint72]struct{}, len(items))
	for _, it := range items {
		if _, ok := seen[it]; ok {
			return true
		}
		seen[it] = struct{}{}
	}
	return false
}
