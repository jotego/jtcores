/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Date: 4-1-2025 */

package betas

import (
	"crypto/rand"
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

var all BetaCores
var Md5sum, Crcsum string
var Betakey uint32
var verbose bool

func (this BetaCores) isBeta(core string) bool {
    _, f := this[core]
    return f
}

func (this BetaCores) isBetaFor(core, target string) bool {
    vv, f := this[core]
    if !f { return false }
    return slices.Contains(vv,target)
}

func IsBeta(core string) bool {
    return all.isBeta(core)
}

func IsBetaFor(core, target string) bool {
    return all.isBetaFor(core,target)
}

func ListBetas() BetaCores {
	fp := filepath.Join(os.Getenv("JTROOT"),".beta.yaml")
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
	betapath := get_betakey_path()
	buf, e := os.ReadFile(betapath)
	if e != nil {
		buf = make_random_key()
	}
	crcsum = make_crc32_string(buf)
	md5sum = make_md5_string(buf)
	betakey = binary.LittleEndian.Uint32(buf)
	return md5sum, crcsum, betakey
}

func get_betakey_path() string {
	return filepath.Join(os.Getenv("JTUTIL"),"beta.bin")
}

func make_random_key() (buf []byte) {
	buf = make([]byte,4)
	rand.Read(buf)
	return buf
}

func make_crc32_string(buf []byte) string {
	return fmt.Sprintf("%x", crc32.ChecksumIEEE(buf) )
}

func make_md5_string(buf []byte) string {
	return fmt.Sprintf("%x", md5.Sum(buf) )
}

func Init() {
	verbose = false
	all = ListBetas()
	Md5sum, Crcsum, Betakey = CalcBetaSums()
}