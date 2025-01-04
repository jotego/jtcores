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
	betapath := filepath.Join(os.Getenv("JTUTIL"),"beta.bin")
	buf, e := os.ReadFile(betapath)
	if e != nil {
		buf = make([]byte,4)
		rand.Read(buf)
	}
	crcsum = fmt.Sprintf("%x", crc32.ChecksumIEEE(buf) )
	md5sum = fmt.Sprintf("%x", md5.Sum(buf) )
	betakey = binary.LittleEndian.Uint32(buf)
	return md5sum, crcsum, betakey
}

func Init() {
	All = ListBetas(false)
	Md5sum, Crcsum, Betakey = CalcBetaSums()
}