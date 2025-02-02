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

import(
    "fmt"
    "log"
    "path/filepath"
    "regexp"
    "sort"
    "strconv"
    "strings"
)

func dipsw_tag(ds MachineDIP ) bool {
    return ds.Tag=="UNUSED" || ds.Tag=="SYSTEM"
}

// make_DIP
func make_switches(root *XMLNode, machine *MachineXML, cfg Mame2MRA, args Args) string {
    if len(machine.Dipswitch) == 0 {
        if len(cfg.Dipsw.Extra) > 0 {
            add_extra_dip(root, true, machine, cfg, args).AddAttr("default", "ff,ff")
        }
        return "ff,ff"
    }
    // Regular DIP parsing
    n := add_switches_parent(root, cfg) // XML node for switches
    last_tag := ""
    base := 0
    def_all := 0xffffffff // 32 bits
    game_bitcnt := cfg.Dipsw.Bitcnt
    for _, ds := range machine.Dipswitch {
        ignore := cfg.Dipsw.is_deleted( ds.Name, machine )
        if ds.Condition.Tag != "" && ds.Condition.Value == 0 {
            continue // This switch depends on others, skip it
        }
        cfg.Dipsw.rename( &ds )
        if Verbose {
            fmt.Printf("\tDIP %s (%s) %d:%d - default = %06X.\n",
                ds.Name, ds.Tag, ds.msb, ds.lsb, uint(def_all) )
        }
        if ds.Tag != last_tag {
            last_tag = ds.Tag
            m := n.AddNode(last_tag)
            m.comment = true
        }
        sort.Slice(ds.Dipvalue, func(p, q int) bool {
            return ds.Dipvalue[p].Value < ds.Dipvalue[q].Value
        })
        options, opt_dev := dip_option_string( ds.Mask, ds.Dipvalue )
        if !ignore {
            dip_add_node( machine.Name, ds.Name, options, n, ds.lsb, ds.msb, &game_bitcnt )
        }
        // apply the default value
        def_all &= ^ds.full_mask
        def_all |= opt_dev<<ds.offset
        if Verbose {
            fmt.Printf("\t\tMask %X (MAME %X) this one %x -> all =%X (base=%d)\n",
                uint(ds.full_mask), ds.Mask, uint(opt_dev<<ds.offset), uint(def_all&0xffffff), base)
        }
    }
    def_str := dip_int2str( def_all, game_bitcnt )
    if Verbose {
        fmt.Printf("Default string before applying TOML overrides: %s (bit count=%d)\n",
            def_str, game_bitcnt)
    }
    // Override the defaults if set so in the TOML
    for _,each := range cfg.Dipsw.Defaults {
        if each.Match(machine)>0 {
            def_str = each.Value
            if Verbose { fmt.Printf("DIP sw default overriden to %s\n", def_str)}
        }
    }
    if def_str=="" { // do not leave them as 00,00!
        def_str="ff,ff"
    }
    n.AddAttr("default", def_str)
    add_extra_dip(n, false, machine, cfg, args)
    return def_str
}

func Max(x, y int) int {
    if x > y {
        return x
    }
    return y
}

func dip_int2str( def, maxbit int ) string {
    s := ""
    for k:=maxbit; k>0; k-=8 {
        if s!="" { s += "," }
        s = fmt.Sprintf("%s%02x",s,def&0xff )
        def >>= 8
    }
    return s
}

func dip_option_string( mask int, all MAMEDIPValues ) (string, int) {
    total := mask
    offset := 0
    def := 0
    for (total&1)==0 {
        total>>=1
        offset++
    }
    total++
    options := make([]string,total)
    for k, _ := range options { options[k]="-" }
    for _, each:= range all {
        v := each.Value>>offset
        options[v] = strings.ReplaceAll(each.Name, ",", " ")
        if each.Default == "yes" {
            def = each.Value
            if Verbose {
                fmt.Printf("\t\tDefault = %s. %X -> %X \n", each.Name, each.Value, uint(def) )
            }
        }
    }

    return strings.Join(options,","), def
}

func dip_clean( options string ) string {
    options = strings.Replace(options, " Coins", "", -1)
    options = strings.Replace(options, " Coin", "", -1)
    options = strings.Replace(options, " Credits", "", -1)
    options = strings.Replace(options, " Credit", "", -1)
    options = strings.Replace(options, " and every ", " & *", -1)
    options = strings.Replace(options, "00000", "00k", -1)
    options = strings.Replace(options, "0000", "0k", -1)
    // remove comments
    options = regexp.MustCompile(`\([^)]*\)`).ReplaceAllString(options, "")
    // remove double spaces
    options = regexp.MustCompile(" +").ReplaceAllString(options, " ")
    // remove spaces around the comma
    options = regexp.MustCompile(" ,").ReplaceAllString(options, ",")
    options = regexp.MustCompile(", ").ReplaceAllString(options, ",")
    return options
}

func dip_add_node( machineName, dsName, options string, n *XMLNode, lsb, msb int, game_bitcnt *int ) {
    options = dip_clean( options )
    m := n.AddNode("dip")
    m.AddAttr("name", dsName)
    bitstr := strconv.Itoa(lsb)
    if lsb != msb {
        bitstr += fmt.Sprintf(",%d", msb)
    }
    *game_bitcnt = Max(*game_bitcnt, msb)
    // Check that the DIP name plus each option length isn't longer than 28 characters
    // which is MiSTer's OSD length
    name_len := len(dsName)
    chunks := strings.Split(options,",")
    re := regexp.MustCompile("(k|K)( |$)")
    for k, each := range chunks {
        if tl := name_len + len(each) - 26; tl > 0 {
            if re.FindString(chunks[k])!="" { // A common case is 50k 100k etc.
                // Delete the k to save space
                chunks[k]=re.ReplaceAllString(chunks[k],"$2")
                tl = name_len + len(chunks[k])-26
            }
            if tl>0 {
                log.Printf("\tWarning DIP option too long for MiSTer (%d extra): (%s)\n\t%s:%s\n",
                    tl, machineName, dsName, chunks[k])
            }
        }
    }
    options = strings.Join(chunks,",") // re-build the options in case there was a change
    m.AddAttr("bits", bitstr)
    m.AddAttr("ids", strings.TrimSpace(options))
}

func (cfg *DipswCfg)is_deleted( dip_name string, machine *MachineXML ) bool {
    for _, each := range cfg.Delete {
        if each.Match(machine)==0 { continue }
        if each.is_deleted(dip_name) {
            return true
        }
    }
    return false
}

func (del DIPswDelete)is_deleted(dip_name string) bool {
    for _, name := range del.Names {
        patternLwr := strings.ToLower(name)
        dipLwr := strings.ToLower(dip_name)
        baseMatch :=  patternLwr == dipLwr
        // GLOB match considers / a special character (separator) in linux
        // replace it for comparison
        globMatch, _ := filepath.Match(strings.ReplaceAll(patternLwr,"/","_"), strings.ReplaceAll(dipLwr,"/","_"))
        if baseMatch || globMatch {
            if Verbose { fmt.Printf("DIP switch '%s' skipped\n", dip_name) }
            return true
        }
    }
    return false
}

func (cfg *DipswCfg)rename( ds *MachineDIP ) {
    dip_name := strings.ToLower(ds.Name)
    for _, rename := range cfg.Rename {
        lwr_name := strings.ToLower(rename.Name)
        if lwr_name == dip_name {
            if rename.To != "" {
                ds.Name = rename.To
            }
            rename.overwrite_dipsw_values(ds.Dipvalue)
            break
        }
    }
}

func (rename *DipswCfgRename) overwrite_dipsw_values( mame MAMEDIPValues ) {
    for k, v := range rename.Values {
        if k >= len(mame) {
            break
        }
        if v != "" {
            mame[k].Name = v
        }
    }
}

func add_extra_dip(n *XMLNode, create_parent bool, machine *MachineXML, cfg Mame2MRA, args Args) *XMLNode {
    // Add DIP switches in the extra section, note that these
    // one will always have a default value of 1
    for _, each := range cfg.Dipsw.Extra {
        if Verbose {
            fmt.Printf("\tChecking extra DIPSW %s for %s/%s (current %s/%s)\n",
                each.Name, each.Machine, each.Setname, machine.Cloneof, machine.Name)
        }
        if each.Match(machine)>0 {
            if create_parent {
                n = add_switches_parent(n, cfg)
                create_parent = false
            }
            m := n.AddNode("dip")
            m.AddAttr("name", each.Name)
            m.AddAttr("ids", each.Options)
            m.AddAttr("bits", each.Bits)
        }
    }
    return n
}

func add_switches_parent(root *XMLNode, cfg Mame2MRA) *XMLNode {
    n := root.AddNode("switches")
    // Switch for MiST
    n.AddAttr("page_id", "1")
    n.AddAttr("page_name", "Switches")
    n.AddIntAttr("base", cfg.Dipsw.base)
    return n
}

func calc_DIP_bits( machine *MachineXML, cfg DipswCfg ) {
    if machine==nil { return }
    max := 0
    offset := 0
    tag := ""
    for k, _ := range machine.Dipswitch {
        each := &machine.Dipswitch[k]
        if k==0 { tag=each.Tag }
        if tag!=each.Tag {
            offset = max+1
            tag=each.Tag
        }
        // get bit limits for this option
        lsb := 0
        mtest := 1
        for (each.Mask & mtest) == 0 {
            mtest <<= 1
            lsb++
        }
        msb := lsb
        for (each.Mask & mtest)!=0 {
            mtest <<= 1
            msb++
        }
        msb--
        // apply offset
        // this way of parsing the cfg.Offset will select the bestMatch
        // regardles of the order in the TOML file. The code becomes a bit
        // convoluted, though
        if i := bestMatch( len(cfg.Offset), func(j int)int {
                if cfg.Offset[j].Name != each.Tag { return -1 }
                return cfg.Offset[j].Match(machine)
            }); i>-1 {
            offset = cfg.Offset[i].Value
        }
        each.msb = msb + offset
        each.lsb = lsb + offset
        each.full_mask = each.Mask << offset
        each.offset = offset
        max = each.msb
    }
}

// extract the bit mask for a string that contains a list of bit positions
// separated by commas
func dip_mask( bits string ) int {
    mask := 0xffffffff
    for _, each := range strings.Split(bits,",") {
        k,_ := strconv.ParseInt(each,10,64)
        mask &= ^(1<<k)
    }
    return mask
}