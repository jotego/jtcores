package mra

import(
    "fmt"
    "log"
    "os"
    "regexp"
    "sort"
    "strconv"
    "strings"
)

func dip_mask( ds MachineDIP ) (int, int) {
    bitmin := 0
    mtest := 1
    for (ds.Mask & mtest) == 0 {
        mtest <<= 1
        bitmin++
    }
    bitmax := bitmin
    for (ds.Mask & mtest)!=0 {
        mtest <<= 1
        bitmax++
    }
    return bitmin, bitmax-1
}

// return start bit, end bit and switch count
func dip_bit0( ds MachineDIP, cfg Mame2MRA ) (int, int, int) {
    locmin := 1000
    locmax := 0
    for _, each := range ds.Diplocation {
        if each.Number < locmin {
            locmin = each.Number
        }
        if each.Number > locmax {
            locmax = each.Number
        }
    }
    // Get the switch number
    loc := ds.Diplocation[0].Name[2:]
    re := regexp.MustCompile("[0-9]+")
    if re.FindStringIndex(loc)== nil {
        fmt.Printf("Error: ignoring DIP location '%s' for bit zero calculation\n", ds.Diplocation[0] )
        os.Exit(1)
    }
    swcnt, _ := strconv.Atoi(loc)
    swcnt = (swcnt-1)<<3
    // fmt.Printf("Found %d, %d at DS%s -> %d \n",locmin,locmax,loc,swcnt)
    return locmin-1+swcnt,locmax-1+swcnt, swcnt
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
diploop:
    for _, ds := range machine.Dipswitch {
        ignore := false
        for _, del := range cfg.Dipsw.Delete {
            if del == ds.Name {
                ignore = true
                break
            }
        }
        if ds.Condition.Tag != "" && ds.Condition.Value == 0 {
            continue diploop // This switch depends on others, skip it
        }
        dip_rename( &ds, cfg )
        bitmin, bitmax, _ := dip_bit0( ds, cfg )
        maskmin, maskmax := dip_mask( ds )
        if args.Verbose {
            fmt.Printf("\tDIP %s (%s) %d:%d - default = %06X. Mask %d:%d\n",
                ds.Name, ds.Tag, bitmax, bitmin, uint(def_all), maskmax, maskmin )
        }
        if ds.Tag != last_tag {
            last_tag = ds.Tag
            m := n.AddNode(last_tag)
            m.comment = true
        }
        sort.Slice(ds.Dipvalue, func(p, q int) bool {
            return ds.Dipvalue[p].Value < ds.Dipvalue[q].Value
        })
        mask := (1<<(bitmax+1))-1
        mask = mask & ^((1<<bitmin)-1)
        options, opt_dev := dip_option_string( mask, args.Verbose, ds.Dipvalue )
        if !ignore {
            dip_add_node( machine.Name, ds.Name, options, n, bitmin, bitmax, &game_bitcnt )
        }
        // apply the default value
        if bitmax+1-bitmin < 0 {
            fmt.Printf("bitmin = %d, bitmax=%d\n", bitmin, bitmax)
            log.Fatal("Don't know how to parse DIP ", ds.Name)
        }
        def_all &= ^mask
        for opt_dev != 0 && (opt_dev&mask)==0 { opt_dev = opt_dev<<4 }
        def_all |= opt_dev
        if args.Verbose {
            fmt.Printf("\t\tMask %X (MAME %X) this one %x -> all =%X (base=%d)\n",
                uint(mask), ds.Mask, uint(opt_dev), uint(def_all&0xffffff), base)
        }
    }
    def_str := dip_int2str( def_all, game_bitcnt )
    // Override the defaults is set so in the TOML
    for _,each := range cfg.Dipsw.Defaults {
        if each.Match(machine)>0 {
            def_str = each.Value
            if args.Verbose { fmt.Printf("DIP sw default overriden to %s\n", def_str)}
        }
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

func dip_option_string( mask int, verbose bool, all MAMEDIPValues ) (string, int) {
    options := ""
    def := 0
    var minv, maxv, bits int
    for _, each := range all {
        if minv > each.Value { minv = each.Value }
        if maxv < each.Value { maxv = each.Value }
    }
    for k:=mask; k!=0; k>>=1 {
        if (k&1)!=0 { bits++ }
    }
    if (1<<bits) < len(all) {
        fmt.Printf("Options for DIP switch do not fit in its mask %X\nOptions:\n",mask)
        fmt.Println(all)
        os.Exit(1)
    }
    if maxv==minv {
        fmt.Printf("DIP options do not have a valid value list:\n")
        fmt.Println(all)
        os.Exit(1)
    }
    step := (maxv-minv+1)/(1<<(bits-1))
    if step==0 {
        fmt.Printf("Cannot determine DIP option list value step\n")
        fmt.Printf("max=$%X, min=$%X, length=%d, step=$%X\n",maxv,minv,(1<<bits),step)
        os.Exit(1)
    }
    cur := all[0].Value
    for _, each := range all {
        if options !=""  { options += "," }
        for cur < each.Value {
            options += "-,"
            cur += step
        }
        options += strings.ReplaceAll(each.Name, ",", " ")
        cur += step
        if each.Default == "yes" {
            def = each.Value
            if verbose {
                fmt.Printf("\t\tDefault = %s. %X -> %X \n", each.Name, each.Value, uint(def) )
            }
        }
    }
    return options, def
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

func dip_add_node( machineName, dsName, options string, n *XMLNode, bitmin, bitmax int, game_bitcnt *int ) {
    options = dip_clean( options )
    m := n.AddNode("dip")
    m.AddAttr("name", dsName)
    bitstr := strconv.Itoa(bitmin)
    if bitmin != bitmax {
        bitstr += fmt.Sprintf(",%d", bitmax)
    }
    *game_bitcnt = Max(*game_bitcnt, bitmax)
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
                fmt.Printf("\tWarning DIP option too long for MiSTer (%d extra): (%s)\n\t%s:%s\n",
                    tl, machineName, dsName, chunks[k])
            }
        }
    }
    options = strings.Join(chunks,",") // re-build the options in case there was a change
    m.AddAttr("bits", bitstr)
    m.AddAttr("ids", strings.TrimSpace(options))
}

func dip_rename( ds *MachineDIP, cfg Mame2MRA ) {
    for _, each := range cfg.Dipsw.Rename {
        if each.Name == ds.Name {
            if each.To != "" {
                ds.Name = each.To
            }
            for k, v := range each.Values {
                if k > len(ds.Dipvalue) {
                    break
                }
                if v != "" {
                    ds.Dipvalue[k].Name = v
                }
            }
            break
        }
    }
}

func add_extra_dip(n *XMLNode, create_parent bool, machine *MachineXML, cfg Mame2MRA, args Args) *XMLNode {
    // Add DIP switches in the extra section, note that these
    // one will always have a default value of 1
    for _, each := range cfg.Dipsw.Extra {
        if args.Verbose {
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