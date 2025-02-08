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
	"encoding/xml"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"strconv"
)

type MachineXML struct {
	Name         string       `xml:"name,attr"`
	Cloneof      string       `xml:"cloneof,attr"`
	Sourcefile   string       `xml:"sourcefile,attr"`
	Description  string       `xml:"description"`
	Year         string       `xml:"year"`
	Manufacturer string       `xml:"manufacturer"`
	Rom          []MameROM    `xml:"rom"`
	Devices      []MameDevice `xml:"device_ref"`
	Chip         []struct {
		Type  string `xml:"type,attr"`
		Tag   string `xml:"tag,attr"`
		Name  string `xml:"name,attr"`
		Clock int    `xml:"clock,attr"`
	} `xml:"chip"`
	Display struct {
		Rotate int `xml:"rotate,attr"`
		Width  int `xml:"width,attr"`
		Height int `xml:"height,attr"`
	} `xml:"display"`
	Sound struct {
		Channels int `xml:"channels"`
	} `xml:"sound"`
	Input struct {
		Players int `xml:"players,attr"`
		Control []struct {
			Type    string `xml:"type,attr"`
			Buttons int    `xml:"buttons,attr"`
			Ways    string `xml:"ways,attr"`
		} `xml:"control"`
	} `xml:"input"`
	Dipswitch []MachineDIP `xml:"dipswitch"`
	// exclude pinballs
	Ismechanical bool `xml:"ismechanical,attr"`
}

type MameROM struct {
	Name       string `xml:"name,attr"`
	Crc        string `xml:"crc,attr"`
	Region     string `xml:"region,attr"`
	Size       int    `xml:"size,attr"`
	Offset_str string `xml:"offset,attr"`
	Status     string `xml:"status,attr"`
	Offset     int
	// filled by mame2mra.go
	group int // interleave group to which the ROM belongs
	wlen  int // word length in bytes
	clen  int // byte count to dump
	used  int // consumed bytes
	split_offset int
	show_len bool
	add_offset int
	mapstr string
}

type MameDevice struct {
	Name string `xml:"name,attr"`
}

type MachineDIP struct {
	Name      string   `xml:"name,attr"`
	Tag       string   `xml:"tag,attr"`
	Mask      int      `xml:"mask,attr"`
	Condition struct { // The meaning of some DIP switches may change upon other switches' value
		Tag      string `xml:"tag,attr"`
		Mask     int    `xml:"mask,attr"`
		Relation string `xml:"relation,attr"`
		Value    int    `xml:"value,attr"`
	} `xml:"condition"`
	Diplocation []Diplocation `xml:"diplocation"`
	Dipvalue MAMEDIPValues `xml:"dipvalue"`
	// calculated by JTFRAME after reading XML
	lsb, msb, full_mask, offset int
}

type MAMEDIPValues []MAMEDIPValue

type MAMEDIPValue struct {
	Name    string `xml:"name,attr"`
	Value   int    `xml:"value,attr"`
	Default string `xml:"default,attr"`
}

func (this MAMEDIPValues) Len() int {
	return len(this)
}

func (this MAMEDIPValues) Swap(i, j int) {
	aux := this[j]
	this[j] = this[i]
	this[i] = aux
}

func (this MAMEDIPValues) Less(i, j int) bool {
	return this[i].Value < this[j].Value
}

type Diplocation struct {
	Name   string `xml:"name,attr"`
	Number int    `xml:"number,attr"`
}

func (machine *MachineXML) Find(machine_options []Selectable) int {
    for k, option := range machine_options {
        if option.Match(machine)>0 {
            return k
        }
    }
    return -1
}

type MameXML struct {
	Machine []MachineXML
}

type Extractor struct {
	decoder *xml.Decoder
	file    *os.File
}

var mame_version string = "0.232"

func Mame_version() string {
	return "0" + mame_version[2:] // converts 0.232 to 0232
}

func (this *MachineXML)Dial() bool {
	for _, each := range this.Input.Control {
		switch strings.ToLower(each.Type) {
			case "dial","positional": return true
		}
	}
	return false
}

func FamilyName(machine *MachineXML) string {
	if machine.Cloneof != "" {
		return machine.Cloneof
	} else {
		return machine.Name
	}
}

// Extracts Machine structs from MAME XML dumps
// call it with the path to mame.xml
func NewExtractor(path string) *Extractor {
	var err error
	var ex Extractor
	ex.file, err = os.Open(path)
	if err != nil {
		fmt.Printf("ERROR: cannot open MAME XML file '%s'\n", path)
		os.Exit(1)
	}

	ex.decoder = xml.NewDecoder(ex.file)
	return &ex
}

func (ex *Extractor) Extract(cfg ParseCfg) *MachineXML {
	var machine MachineXML

	dump := false
loop_machines:
	for {
		token, _ := ex.decoder.Token()
		if token == nil {
			break
		}
		switch se := token.(type) {
		case xml.StartElement:
			switch se.Name.Local {
			case "mame":
				{
					for _, a := range se.Attr {
						if a.Name.Local == "build" {
							mame_version = a.Value[0:5]
						}
					}
				}
			case "machine":
				{
					if len(cfg.Sourcefile) != 0 {
						for _, v := range se.Attr {
							if v.Name.Local == "sourcefile" {
								for _, each := range cfg.Sourcefile {
									re := regexp.MustCompile(each)
									if re.MatchString(filepath.Base(v.Value)) {
										dump = true
									}
								}
							}
						}
					}
					// Exclude some machines:
					if cfg.All {
						dump = true
					}
					if dump {
						ex.decoder.DecodeElement(&machine, &se)
						device_ok := len(cfg.Mustbe.Devices) == 0
					device_check:
						for _, each := range cfg.Mustbe.Devices {
							re := regexp.MustCompile(each)
							for _, check := range machine.Devices {
								if re.MatchString(check.Name) {
									device_ok = true
									break device_check
								}
							}
						}
						year, e := strconv.Atoi( strings.ReplaceAll(machine.Year,"?","0"))
						if e!=nil { year=2100 }
						if device_ok && !machine.Ismechanical && year>=cfg.Older {
							tidyup(&machine)
							break loop_machines
						} else {
							machine = MachineXML{}
							dump = false
						}
					}
				}
			}
		}
	}
	if dump {
		return &machine
	} else {
		return nil
	}
}

func tidyup(machine *MachineXML) {
	if len(machine.Rom) > 0 {
		// Convert offset rom hex string to decimal
		for k := 0; k < len(machine.Rom); k++ {
			r := &machine.Rom[k]
			v, _ := strconv.ParseInt(r.Offset_str, 16, 32)
			r.Offset = int(v)
		}
		// Sort ROMs by region, and then by offset
		sort.Slice(machine.Rom, func(p, q int) bool {
			if machine.Rom[p].Region == machine.Rom[q].Region {
				return machine.Rom[p].Offset < machine.Rom[q].Offset
			} else {
				return machine.Rom[p].Region < machine.Rom[q].Region
			}
		})
	}
	// The DIP switch values may not be in order in the XML
	for k, _ := range machine.Dipswitch {
		sort.Sort(machine.Dipswitch[k].Dipvalue)
	}
	// Remove / from game descriptions
	machine.Description=strings.ReplaceAll(machine.Description,"/","-")
}
