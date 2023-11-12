package betas

import (
	"encoding/binary"
	"fmt"
	"os"
	"path/filepath"
	"slices"

	"hash/crc32"
	"crypto/md5"

	"gopkg.in/yaml.v2"
)

type BetaCores map[string][]string

var All BetaCores
var Md5sum, Crcsum string
var Betakey uint32

func (this BetaCores) IsBeta(core string) bool {
    _, f := this[core]
    return f
}

func (this BetaCores) IsBetaFor(core, target string) bool {
    vv, f := this[core]
    if !f { return false }
    return slices.Contains(vv,target)
}

func IsBeta(core string) bool {
    return All.IsBeta(core)
}

func IsBetaFor(core, target string) bool {
    return All.IsBetaFor(core,target)
}

func ListBetas(verbose bool) BetaCores{
	fp := filepath.Join(os.Getenv("JTROOT"),"beta.yaml")
	buf, e := os.ReadFile(fp)
	betas := make(BetaCores)
	if e != nil {
		if verbose { fmt.Println(e) }
	} else {
		yaml.Unmarshal(buf, betas)
	}
	return betas
}

func CalcBetaSums() (md5sum string, crcsum string, betakey uint32) {
	betapath := filepath.Join(os.Getenv("JTUTIL"),"beta.bin")
	buf, e := os.ReadFile(betapath)
	if e != nil { return "","",0 }
	crcsum = fmt.Sprintf("%x", crc32.ChecksumIEEE(buf) )
	md5sum = fmt.Sprintf("%x", md5.Sum(buf) )
	betakey = binary.LittleEndian.Uint32(buf)
	return md5sum, crcsum, betakey
}

func Init() {
	All = ListBetas(false)
	Md5sum, Crcsum, Betakey = CalcBetaSums()
}