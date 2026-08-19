// Copyright © 2026 Jose Tejada Gomez. All rights reserved.
//
// This source code is provided for viewing and evaluation only.
// No permission is granted to copy, modify, distribute, sublicense, use in
// another project, or create derivative works without prior written permission.

package extract

type Extractor struct {
	Keep bool
}

type AsmTest struct{
	Name string
	Mem  []MemCfg  `yaml:"mem"`
	Test []AsmLine `yaml:"test"`
	// private
	asm_file, hex_file string
	mem [65536]byte
	all_vectors []test_vector
	asm_lines int
}

type MemCfg struct {
	From    int    `yaml:"from"`
	HexData string `yaml:"data"`
}

type AsmLine struct {
	Asm   string `yaml:"asm"`
	Check string `yaml:"check"`
}

type test_vector struct {
	A,X,Y,S,v,n,z,c,d,i int
}
