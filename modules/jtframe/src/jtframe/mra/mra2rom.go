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

package mra

import (
	"archive/zip"
	"bytes"
	"crypto/md5"
	"errors"
	"fmt"
	"io"
	"log"
	"os"
	"path"
	"path/filepath"
	"strconv"
	"strings"
)

// save2disk = false is uselful to update the md5 calculation only
func mra2rom(root *XMLNode, save2disk bool, zippath string) {
	e := save_rom(root, save2disk, zippath )
	if e!=nil { fmt.Println(e) }
	if save2disk {
		save_coremod(root)
	}
}

func save_coremod(root *XMLNode) {
	setname := root.GetNode("setname")
	xml_rom := root.FindMatch(func(n *XMLNode) bool { return n.name == "rom" && n.GetAttr("index") == "1" })
	if xml_rom == nil || setname == nil {
		log.Println("Warning: no ROM files associated with machine")
		return
	}
	// main ROM file
	rombytes := make([]byte, 0)
	parts2rom(nil, xml_rom, &rombytes)
	rom_file(setname.text, ".mod", rombytes)
}

func save_nvram(root *XMLNode) {
	setname := root.GetNode("setname")
	// optional default NVRAM
	xml_nvram := root.FindMatch(func(n *XMLNode) bool { return n.name == "rom" && n.GetAttr("index") == "2" })
	if xml_nvram == nil { return }
	xml_nvram = xml_nvram.GetNode("part")
	if xml_nvram == nil || xml_nvram.text=="" { return }
	rom_file( strings.ToUpper(setname.text),".RAM",rawdata2bytes(xml_nvram.text))
}

func save_rom(root *XMLNode, save2disk bool, zippath string) error {
	setname := root.GetNode("setname")
	xml_rom := root.FindMatch(func(n *XMLNode) bool { return n.name == "rom" && n.GetAttr("index") == "0" })
	if xml_rom == nil || setname == nil {
		log.Println("Warning: no ROM files associated with machine")
		return nil
	}
	rombytes := make([]byte, 0)
	var zf []*zip.ReadCloser
	var zipe error
	for _, each := range strings.Split(xml_rom.GetAttr("zip"), "|") {
		aux, e := get_zipfile(each, zippath )
		if aux != nil { zf = append(zf, aux) }
		if e   != nil {
			if zipe != nil {
				zipe = fmt.Errorf("%s, %s", each, zipe.Error())
			} else {
				zipe = fmt.Errorf("%s", each)
			}
		}
	}
	if len(zf)==0 { return fmt.Errorf("%-10s cannot find %s",setname.text, zipe.Error()) }
	if Verbose {
		fmt.Println("**** Creating .rom file for", setname.text)
	}
	e := parts2rom(zf, xml_rom, &rombytes)
	if e != nil { fmt.Println(setname.text,"\n",e)}
	if rombytes == nil {
		return fmt.Errorf("No .rom created for %s\n\n", setname.text)
	}
	update_md5(xml_rom, rombytes)
	if len(rombytes)%4 != 0 {
		log.Printf("Warning (%-12s): ROM length is not multiple of four. Analogue Pocket will not load it well\n", setname.text)
	}
	if save2disk {
		var e error
		if e = patchrom(xml_rom, &rombytes); e!=nil {
			e = fmt.Errorf("%s: %w\n", setname.text, e)
		}
		return comb_errors( e, rom_file(setname.text, ".rom", rombytes))
	}
	return nil
}

func rom_file(setname string, ext string, rombytes []byte) error {
	os.MkdirAll( filepath.Join(os.Getenv("JTROOT"), "rom"), 0775 )
	fout_name := filepath.Join(os.Getenv("JTROOT"), "rom", setname+ext)
	fout, err := os.Create(fout_name)
	if err != nil {
		return err
	}
	fout.Write(rombytes)
	fout.Close()
	return nil
}

func update_md5(n *XMLNode, rb []byte) {
	if rb == nil {
		return
	}
	md5sum := md5.Sum(rb)
	n.AddAttr("asm_md5", fmt.Sprintf("%x", md5sum))
}

func patchrom(n *XMLNode, rb *[]byte) error {
	for _, each := range n.children {
		if each.name != "patch" {
			continue
		}
		data := rawdata2bytes(each.text)
		k, err := strconv.ParseInt(each.GetAttr("offset"), 0, 32)
		if err != nil {
			fmt.Println(err)
		}
		if int(k)>len(*rb) {
			return errors.New ("Cannot apply patch as it falls outside the .rom file length")
		}
		for _, each := range data {
			(*rb)[k] = each
			k++
		}
	}
	return nil
}

func parts2rom(zf []*zip.ReadCloser, n *XMLNode, rb *[]byte) (fail error) {
	for _, each := range n.children {
		switch each.name {
		case "part":
			fname := each.GetAttr("name")
			if fname == "" {
				// Convert internal text to bytes
				rep, _ := strconv.ParseInt(each.GetAttr("repeat"), 0, 32)
				if rep == 0 {
					rep = 1
				}
				data := rawdata2bytes(each.text)
				// fmt.Printf("Adding rep x len(data) = $%x x $%x\n",rep,len(data))
				for ; rep > 0; rep-- {
					*rb = append(*rb, data...)
				}
			} else {
				data, e := readrom(zf, each)
				fail = comb_errors(fail,e)
				*rb = append(*rb, data...)
			}
		case "interleave":
			if Verbose {
				fmt.Printf("\tinterleave found\n")
			}
			data, e := interleave2rom(zf, each)
			fail = comb_errors(fail,e)
			if data == nil {
				*rb = nil
				// fmt.Printf("\t.rom processing stopped\n")
				return // abort
			}
			*rb = append(*rb, data...)
		}
	}
	return fail
}

func readrom(allzips []*zip.ReadCloser, n *XMLNode) (rdin []byte, fail error) {
	crc, err := strconv.ParseUint(strings.ToLower(n.GetAttr("crc")), 16, 32)
	if err != nil {
		fmt.Println(err)
	}
	crc = crc & 0xffffffff
	var f *zip.File
lookup:
	// try to find the file using CRC
	for _, each := range allzips {
		for _, file := range each.File {
			if file.CRC32 == uint32(crc) {
				f = file
				break lookup
			}
		}
	}
	if f == nil {
		// try again just by file name
		fname := n.GetAttr("name")
		if(Verbose) { fmt.Printf("\tcannot find file %s (%s) in zip by CRC\n", n.GetAttr("name"), n.GetAttr("crc")) }
lookup_name:
		for _, each := range allzips {
			for _, file := range each.File {
				// only checking the file name, but it may be better to compare
				// the subfolder where the file is, in order to match the setname
				if path.Base(file.Name) == fname {
					f = file
					break lookup_name
				}
			}
		}
		if f == nil {
			fail = fmt.Errorf("\tcannot find file either %s by name or CRC (%s)", fname, n.GetAttr("crc"))
			return nil, fail
		}
	}
	offset, _ := strconv.ParseInt(n.GetAttr("offset"), 0, 32)
	lenght, _ := strconv.ParseInt(n.GetAttr("length"), 0, 32)
	zpart, _ := f.Open()
	var buf bytes.Buffer
	rdcnt, err := io.CopyN(&buf, zpart, int64(f.UncompressedSize64)) // CopyN is needed because using zpart.Read does not return all the data at once
	if err != nil {
		fmt.Println(err)
	}
	if rdcnt != int64(f.UncompressedSize64) {
		fmt.Println("\tzipped data partially read")
	}
	if lenght > int64(f.UncompressedSize64) {
		lenght = int64(f.UncompressedSize64)
	} else if lenght == 0 {
		lenght = int64(f.UncompressedSize64) - offset
	} else {
		lenght += offset
	}
	alldata := buf.Bytes()
	rdin = alldata[offset:lenght]
	if Verbose {
		fmt.Printf("\tread %x bytes from %s (%x) read from %x up to %x\n", len(rdin), n.GetAttr("name"), crc, offset, lenght)
	}
	defer zpart.Close()
	return rdin,nil
}

func interleave2rom(allzips []*zip.ReadCloser, n *XMLNode) (data []byte, fail error) {
	width, _ := strconv.ParseInt(n.GetAttr("output"), 0, 32)
	width = width >> 3
	type finger struct {
		data      []byte
		mapstr    string
		step, pos int
	}
	fingers := make([]finger, 0)
	for _, each := range n.children {
		if each.name != "part" {
			continue
		}
		var f finger
		var e error
		f.data, e = readrom(allzips, each)
		if e!=nil {
			if fail==nil {
				fail = e
			} else {
				fail = errors.Join(fail,e)
			}
		}
		f.mapstr = each.GetAttr("map")
		if len(f.data) == 0 {
			return nil, errors.Join(fail,fmt.Errorf("Skipping ROM generation. Missing files for interleave\n"))
		}
		for _, k := range f.mapstr {
			kint := int(k - '0')
			if kint > f.step {
				f.step = kint
			}
		}
		if Verbose {
			fmt.Printf("\tfinger %s len = %X\n", f.mapstr, len(f.data))
		}
		fingers = append(fingers, f)
	}
	if len(fingers) == 0 {
		return nil, errors.Join(fail,fmt.Errorf("Unexpected empty interleave"))
	}
	// map each output byte to the input file that has it
	sel := make([]int, width)
	if Verbose {
		for k, each := range fingers {
			fmt.Println("finger ", k, " mapstr = ", each.mapstr)
		}
	}
fingersel_loop:
	for j := 0; j < int(width); j++ {
		for k := 0; k < len(fingers); k++ {
			// fmt.Printf("fingers[%d].mapstr[%d]=%c\n",k,j,fingers[k].mapstr[j])
			if fingers[k].mapstr[j] != '0' {
				sel[j] = k
				continue fingersel_loop
			}
		}
	}
	if Verbose {
		fmt.Println("Mapping as ", sel)
	}
	data = make([]byte, 0, len(fingers[0].data))
	jmax := int(width) - 1
interleave_loop:
	for {
		for j := jmax; j >= 0; j-- {
			offs := int(fingers[sel[j]].mapstr[j]-'1') & 0xff
			data = append(data, fingers[sel[j]].data[fingers[sel[j]].pos+offs])
		}
		for j, _ := range fingers {
			fingers[j].pos += fingers[j].step
			if fingers[j].pos >= len(fingers[j].data) {
				break interleave_loop
			}
		}
	}
	// fmt.Printf("Interleaved length %X\n",len(data))
	return data, fail
}
