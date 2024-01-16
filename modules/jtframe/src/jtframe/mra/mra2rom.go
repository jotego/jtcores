package mra

import (
	"archive/zip"
	"bytes"
	"crypto/md5"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

// save2disk = false is uselful to update the md5 calculation only
func mra2rom(root *XMLNode, verbose, save2disk bool) {
	save_rom(root, verbose, save2disk )
	if save2disk {
		save_coremod(root, verbose)
	}
}

func save_coremod(root *XMLNode, verbose bool) {
	setname := root.GetNode("setname")
	xml_rom := root.FindMatch(func(n *XMLNode) bool { return n.name == "rom" && n.GetAttr("index") == "1" })
	if xml_rom == nil || setname == nil {
		fmt.Printf("Warning: malformed MRA file")
		return
	}
	rombytes := make([]byte, 0)
	parts2rom(nil, xml_rom, &rombytes, verbose)
	rom_file(setname, ".mod", rombytes)
}

func save_rom(root *XMLNode, verbose, save2disk bool) {
	setname := root.GetNode("setname")
	xml_rom := root.FindMatch(func(n *XMLNode) bool { return n.name == "rom" && n.GetAttr("index") == "0" })
	if xml_rom == nil || setname == nil {
		fmt.Printf("Warning: malformed MRA file")
		return
	}
	rombytes := make([]byte, 0)
	var zf []*zip.ReadCloser
	for _, each := range strings.Split(xml_rom.GetAttr("zip"), "|") {
		aux := get_zipfile(each)
		if aux != nil {
			zf = append(zf, aux)
		}
	}
	if verbose {
		fmt.Println("**** Creating .rom file for", setname.text)
	}
	parts2rom(zf, xml_rom, &rombytes, verbose)
	if rombytes == nil {
		fmt.Printf("\tNo .rom created for %s\n", setname.text)
		return
	}
	update_md5(xml_rom, rombytes)
	if len(rombytes)%4 != 0 {
		fmt.Printf("Warning (%-12s): ROM length is not multiple of four. Analogue Pocket will not load it well\n", setname.text)
	}
	if save2disk {
		patchrom(xml_rom, &rombytes)
		rom_file(setname, ".rom", rombytes)
	}
}

func rom_file(setname *XMLNode, ext string, rombytes []byte) {
	os.MkdirAll( filepath.Join(os.Getenv("JTROOT"), "rom"), 0775 )
	fout_name := filepath.Join(os.Getenv("JTROOT"), "rom", setname.text+ext)
	fout, err := os.Create(fout_name)
	if err != nil {
		fmt.Println(err)
		return
	}
	fout.Write(rombytes)
	fout.Close()
}

func update_md5(n *XMLNode, rb []byte) {
	if rb == nil {
		return
	}
	md5sum := md5.Sum(rb)
	n.AddAttr("asm_md5", fmt.Sprintf("%x", md5sum))
}

func patchrom(n *XMLNode, rb *[]byte) {
	for _, each := range n.children {
		if each.name != "patch" {
			continue
		}
		data := text2data(each)
		k, err := strconv.ParseInt(each.GetAttr("offset"), 0, 32)
		if err != nil {
			fmt.Println(err)
		}
		for _, each := range data {
			(*rb)[k] = each
			k++
		}
	}
}

func parts2rom(zf []*zip.ReadCloser, n *XMLNode, rb *[]byte, verbose bool) {
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
				data := text2data(each)
				// fmt.Printf("Adding rep x len(data) = $%x x $%x\n",rep,len(data))
				for ; rep > 0; rep-- {
					*rb = append(*rb, data...)
				}
			} else {
				*rb = append(*rb, readrom(zf, each, verbose)...)
			}
		case "interleave":
			if verbose {
				fmt.Printf("\tinterleave found\n")
			}
			data := interleave2rom(zf, each, verbose)
			if data == nil {
				*rb = nil
				fmt.Printf("\t.rom processing stopped\n")
				return // abort
			}
			*rb = append(*rb, data...)
		}
	}
}

func text2data(n *XMLNode) (data []byte) {
	data = make([]byte, 0)
	re := regexp.MustCompile("[ \n\t]")
	for _, token := range re.Split(n.text, -1) {
		if token == "" {
			continue
		}
		token = strings.TrimSpace(strings.ToLower(token))
		v, err := strconv.ParseInt(token, 16, 16)
		if err != nil {
			fmt.Println(err)
		}
		data = append(data, byte(v&0xff))
	}
	return data
}

func readrom(allzips []*zip.ReadCloser, n *XMLNode, verbose bool) (rdin []byte) {
	crc, err := strconv.ParseUint(strings.ToLower(n.GetAttr("crc")), 16, 32)
	if err != nil {
		fmt.Println(err)
	}
	crc = crc & 0xffffffff
	var f *zip.File
lookup:
	for _, each := range allzips {
		for _, file := range each.File {
			if file.CRC32 == uint32(crc) {
				f = file
				break lookup
			}
		}
	}
	if f == nil {
		fmt.Printf("Warning: cannot find file %s (%s) in zip\n", n.GetAttr("name"), n.GetAttr("crc"))
		return nil
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
	if verbose {
		fmt.Printf("\tread %x bytes from %s (%x) read from %x up to %x\n", len(rdin), n.GetAttr("name"), crc, offset, lenght)
	}
	defer zpart.Close()
	return rdin
}

func interleave2rom(allzips []*zip.ReadCloser, n *XMLNode, verbose bool) (data []byte) {
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
		f.data = readrom(allzips, each, verbose)
		f.mapstr = each.GetAttr("map")
		if len(f.data) == 0 {
			fmt.Printf("Skipping ROM generation. Missing files for interleave\n")
			return nil
		}
		for _, k := range f.mapstr {
			kint := int(k - '0')
			if kint > f.step {
				f.step = kint
			}
		}
		if verbose {
			fmt.Printf("\tfinger %s len = %X\n", f.mapstr, len(f.data))
		}
		fingers = append(fingers, f)
	}
	if len(fingers) == 0 {
		fmt.Printf("Unexpected empty interleave")
		return nil
	}
	// map each output byte to the input file that has it
	sel := make([]int, width)
	if verbose {
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
	if verbose {
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
	return data
}
