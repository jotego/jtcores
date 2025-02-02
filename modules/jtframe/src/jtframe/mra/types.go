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

var Verbose bool

type Args struct {
    Core, Target                 string
    Toml_path, Xml_path          string
    outdir, altdir               string
    cheatdir, pocketdir          string
    Info                         []Info
    Buttons                      string
    Year                         string
    SkipMRA, SkipPocket          bool
    SkipROM, Md5                 bool // By skipping the ROM generation,
        // the md5 will be set to None, unless Md5 is true
    Show_platform                bool
    MainOnly,PrintNames          bool
    JTbin                        bool // copy to JTbin & disable debug features
    Nodbg                        bool // do not parse games in the debug section
    URL, Rom_path        string
    // private
    firmware_dir string
}

type Selectable struct {
    Machine, Setname string
    Machines, Setnames []string
}

type Matchable interface {
    Match( x *MachineXML ) int
}

// find if a selectable object is a match for a machine
// use bestMatch below for slices
func (this *Selectable) Match( x *MachineXML ) int {
    if this.Setname==x.Name || (this.Machine==x.Name && x.Cloneof=="") {
        return 3
    }
    for _,each := range this.Setnames {
        if each==x.Name {
            return 3
        }
    }
    if this.Machine == x.Cloneof && x.Cloneof!="" {
        return 2
    }
    for _,each := range this.Machines {
        if each==x.Cloneof {
            return 2
        }
        if each==x.Name && x.Cloneof=="" {
            return 3
        }
    }
    if this.Machine=="" && this.Setname=="" && len(this.Machines)==0 && len(this.Setnames)==0 {
        return 1
    }
    return 0
}

// returns the index of the best match for a machine in a selectable slice
func bestMatch( size int, match func(k int)int ) int {
    v := 0 // value
    i := -1 // index
    for k:=0; k<size; k++ {
        cur := match(k)
        if cur>v {
            v = cur
            i = k
        }
    }
    return i
}

func is_family(name string, machine *MachineXML) bool {
    return name != "" && (name == machine.Name || name == machine.Cloneof)
}

type RegCfg struct {
    Selectable
    Name, Rename,
    Start         string // Matches a macro in macros.def that should be an integer value
    start         int    // Private translation of the Start value
    Width, Len    int
    Rom_len       int
    Reverse, Skip bool
    Reverse_only  []int // specify ROM widths to which the reverse will be applied
    No_offset     bool // Using the default offset helps in some CPU configurations. If the file order is not changed,
    // keeping the original offset usually has no effect as the offset is just the file size
    // when reverse=true or a sort/sequence changes the file order, the offset may introduce
    // warning messages or fillers, so no_offset=true is needed
    Sort_even    bool // sort ROMs by pushing all even ones first, and then the odd ones
    Singleton    bool // Each file can only merge with itself to make interleave sections
    // The upper and lower halves of the same file are merged together
    Ext_sort   []string // sorts by matching the file extension
    Name_sort  []string // sorts by name
    Sequence   []int    // File sequence, where the first file is identified with a 0, the next with 1 and so on
    // ROM files can be repeated or omitted in the sequence
    Frac struct {
        Bytes, Parts int
    }
    Overrules []struct { // Overrules the region settings for specific files
        Names   []string
        Reverse bool
    }
    Custom struct { // If there is not dump available, jtframe will try to make one
        // the assembly source code must be in cores/corename/firmware/machine.s or setname.s
        // Machine, Setname string // Optional filters
        Dev string // Device name for assembler
    }
    Parts []struct {
        Name, Crc, Map  string
        Length, Offset int
    }
    Files []MameROM // This replaces the information in mame.xml completely if present
}

func (this *RegCfg) EffName() string {
    if this.Rename!="" {
        return this.Rename
    }
    return this.Name
}

type RawData struct {
    Data string
    Selectable
}

type HeaderData struct {
    RawData
    Offset  int
    Dev     string // required device name to apply these data, ignored if blank
    Pcb_id  bool
}

type HeaderOffset struct {
    Bits    int
    Reverse bool
    Start   int // Start location for the offset table
    Regions []string
}

type HeaderCfg struct {
    Info    string
    Fill    int
    Data   []HeaderData
    PCBs   []Selectable
    // Offset in the ROM stream of each ROM region
    Offset HeaderOffset
    Frames []FrameCfg // indicates that the game draws a black frame around the active video
    // Filled automatically
    len int
}

type Info struct {
    Tag, Value string
}

type Overrule_t struct {
    Selectable
    Rotate           int
}

type DIPOffset struct {
    Selectable
    Name string
    Value int
}

type FrameCfg struct {
    Selectable
    Width int
}

type Mame2MRA struct {
    Global struct {
        Info      []Info
        Author []string
        Webpage, Twitter   string
        Platform  string // Used by the Pocket target
        Zip       struct {
            Alt string
        }
        Orientation struct {
            Fixed bool
        }
        Overrule []Overrule_t  // overrules values in MAME XML
    }

    Pocket struct {
        Display_modes []int
    }

    Cheat struct {
        Disable bool
        Files   []struct {
            Selectable
            AsmFile string
            Skip                      bool
        }
    }

    Parse ParseCfg

    Buttons struct {
        Core  int
        Dial []struct {
            Selectable
            Raw, Reverse bool
        }
        Names []struct {
            Selectable
            Names            string
        }
    }

    Dipsw DipswCfg
    rbf string
    // Rbf struct {
    //  Name string
    //  Dev  []struct {
    //      Dev, Rbf string
    //  }
    //  Machines []struct {
    //      Machine, Setname, Rbf string
    //  }
    // }

    Header HeaderCfg
    Audio struct {
        Volume []struct {
            Selectable
            Value int
        }
    }
    ROM struct {
        Firmware string     // Used for consoles by the Pocket target
        Regions  []RegCfg
        Order    []string
        Carts    []string
        Remove   []string // Remove specific files from the dump
        // Splits break a file into chunks using the offset and length MRA attributes
        // Offset sets the break point, and Min_len the minimum length for each chunk
        // This can be used to group several files in a different order (see Golden Axe)
        // or to make a file look bigger than it is (see Bad Dudes)
        Splits []struct {
            Selectable
            Region           string
            Offset, Min_len  int
        }
        Blanks []struct {
            Selectable
            Region      string
            Offset, Len int
        }
        Patches []struct {
            Selectable
            Offset           int
            Data             string
        }
        Nvram struct {
            Selectable
            length   int       // set internally
            Defaults []RawData // Initial value for NVRAM
        }
    }
}

type DipswCfg struct {
    Delete []DIPswDelete
    Offset []DIPOffset
    base   int // Define it macros.def as JTFRAME_DIPBASE
    Bitcnt int // Total bit count (including all switches)
    Defaults [] struct {
        Selectable
        Value            string // used big-endian order, comma separated
    }
    Extra []struct {
        Selectable
        Name, Options, Bits string
    }
    Rename []DipswCfgRename
}

type DIPswDelete struct{
    Selectable
    Names []string
}

type DipswCfgRename struct {
    Name, To string   // Will make Name <- To
    Values   []string // Will rename the values if present
}

type ParsedMachine struct {
    machine   *MachineXML
    mra_xml   *XMLNode
    cloneof   bool
    def_dipsw string
    coremod   int
}

// Configure whether to parse or not a machine
type ParseCfg struct {
    All        bool // parse all games
    Sourcefile []string
    Machine    MachineXML // Explicit Machine
    Main_setnames []string // setname to be used as the main ones to copy in mister/releases
    Rename     []struct {
        Setname string
        Name    string
    }
    Older   int // minimum year allow to parse
    Skip struct {
        Selectable
        Descriptions []string
        Bootlegs     bool
    }
    Debug struct { // the games here will not be parsed if JTFRAME_RELEASE is set
        Selectable
    }
    Mustbe struct { // If any of these conditions are met, the game will be parsed
        // empty arrays or strings are not used for comparison
        // Descriptions []string
        // Setnames     []string
        Machines []string
        Devices  []string // list of devices the game must contain to be parsed
    }
    Parents []struct {
        Name, Description string
    }
}