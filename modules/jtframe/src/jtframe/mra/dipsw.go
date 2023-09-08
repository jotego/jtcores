package mra

import(
    "fmt"
    "log"
    "math"
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

func dip_bit0( ds MachineDIP, cfg Mame2MRA ) (int, int) {
    if cfg.Dipsw.UseLocation && len(ds.Diplocation)>0 &&
     len(ds.Diplocation[0].Name)>2 &&
     ds.Diplocation[0].Name[0:2]=="SW" {
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
        if re.FindStringIndex(loc)!= nil {
            swcnt, _ := strconv.Atoi(loc)
            swcnt = (swcnt-1)<<3
            // fmt.Printf("Found %d, %d at %s\n",locmin,locmax,loc)
            return locmin-1+swcnt,locmax-1+swcnt
        } else {
            fmt.Printf("Warning: ignoring DIP location '%s' for bit zero calculation\n", ds.Diplocation[0] )
        }
    }
    bitmin := 0
    for bitmin = 0; bitmin < (1 << 32); bitmin++ {
        if (ds.Mask & (1 << bitmin)) != 0 {
            break
        }
    }
    bitmax := bitmin + int(math.Ceil(math.Log2(float64(len(ds.Dipvalue))))) - 1
    return bitmin, bitmax
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
    def_str := ""
    n := add_switches_parent(root, cfg)
    last_tag := ""
    base := 0
    def_cur := 0xff
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
        // Rename the DIP
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
        bitmin, bitmax := dip_bit0( ds, cfg )
        maskmin, maskmax := dip_mask( ds )
        if args.Verbose {
            fmt.Printf("\tDIP %s (%s) %d:%d - def_str = '%s'. Mask %d:%d\n", ds.Name, ds.Tag, bitmax, bitmin, def_str, maskmax, maskmin )
        }
        if ds.Tag != last_tag {
            if last_tag!="" {
                // Record the default values
                if len(def_str) > 0 {
                    def_str += ","
                }
                def_str = def_str + fmt.Sprintf("%02x", def_cur)
                def_cur = 0xff
                if !cfg.Dipsw.UseLocation { base += 8 }
            }
            last_tag = ds.Tag
            m := n.AddNode(last_tag)
            m.comment = true
        }
        sort.Slice(ds.Dipvalue, func(p, q int) bool {
            return ds.Dipvalue[p].Value < ds.Dipvalue[q].Value
        })
        options := ""
        var opt_dev int
        opt_dev = -1
        next_val := 0
        for _, each := range ds.Dipvalue {
            if len(options) != 0 {
                options += ","
            }
            this_value := each.Value >> bitmin
            for next_val < this_value {
                options += "-,"
                next_val++
            }
            options += strings.ReplaceAll(each.Name, ",", " ")
            next_val++
            if each.Default == "yes" {
                opt_dev = each.Value
                if args.Verbose {
                    fmt.Printf("\t\tDefault = %s. %X -> %X \n", each.Name, each.Value, opt_dev )
                }
            }
        }
        if !ignore {
            options = strings.Replace(options, " Coins", "", -1)
            options = strings.Replace(options, " Coin", "", -1)
            options = strings.Replace(options, " Credits", "", -1)
            options = strings.Replace(options, " Credit", "", -1)
            options = strings.Replace(options, " and every ", " & *", -1)
            options = strings.Replace(options, "00000", "00k", -1)
            options = strings.Replace(options, "0000", "0k", -1)
            // remove comments
            re := regexp.MustCompile(`\([^)]*\)`)
            options = re.ReplaceAllString(options, "")
            // remove double spaces
            re = regexp.MustCompile(" +")
            options = re.ReplaceAllString(options, " ")
            // remove spaces around the comma
            re = regexp.MustCompile(" ,")
            options = re.ReplaceAllString(options, ",")
            re = regexp.MustCompile(", ")
            options = re.ReplaceAllString(options, ",")
            m := n.AddNode("dip")
            m.AddAttr("name", ds.Name)
            bitstr := strconv.Itoa(base + bitmin)
            if bitmin != bitmax {
                bitstr += fmt.Sprintf(",%d", base+bitmax)
            }
            game_bitcnt = Max(game_bitcnt, bitmax+base)
            // Check that the DIP name plus each option length isn't longer than 28 characters
            // which is MiSTer's OSD length
            name_len := len(ds.Name)
            chunks := strings.Split(options,",")
            for k, each := range chunks {
                if tl := name_len + len(each) - 26; tl > 0 {
                    re := regexp.MustCompile("(k|K)( |$)")
                    if re.FindString(chunks[k])!="" { // A common case is 50k 100k etc.
                        // Delete the k to save space
                        chunks[k]=re.ReplaceAllString(chunks[k],"$2")
                        tl = name_len + len(chunks[k])-26
                    }
                    if tl>0 {
                        fmt.Printf("\tWarning DIP option too long for MiSTer (%d extra): (%s)\n\t%s:%s\n",
                            tl, machine.Name, ds.Name, chunks[k])
                    }
                }
            }
            options = strings.Join(chunks,",") // re-build the options in case there was a change
            m.AddAttr("bits", bitstr)
            m.AddAttr("ids", strings.TrimSpace(options))
        }
        // apply the default value
        if bitmax+1-bitmin < 0 {
            fmt.Printf("bitmin = %d, bitmax=%d\n", bitmin, bitmax)
            log.Fatal("Don't know how to parse DIP ", ds.Name)
        }
        mask := 1 << (1 + Max(cfg.Dipsw.Bitcnt, maskmax) - maskmin)
        mask = (^((mask - 1) << maskmin)) & 0xffff
        def_cur &= mask
        opt_dev = opt_dev & ^mask
        def_cur |= opt_dev
        if args.Verbose {
            fmt.Printf("\t\tMask %X Default %x -> def_cur=%X (base=%d)\n", mask, opt_dev, def_cur, base)
        }
    }
    // Default values of switch parsed last
    if len(def_str) > 0 {
        def_str += ","
    }
    cur_str := fmt.Sprintf("%02x", def_cur)
    def_str += cur_str
    if args.Verbose {
        fmt.Printf("\tDefaults from MAME = %s\n", def_str )
    }
    base += 8
    if base < game_bitcnt && !cfg.Dipsw.UseLocation{
        cur_str := fmt.Sprintf("%02x", def_cur)
        def_str += cur_str
        base += len(cur_str) << 2
        // fmt.Printf("\t2. def_str=%s. base/game_bitcnt = %d/%d \n", def_str, base, game_bitcnt)
        for k := base; k < game_bitcnt; k += 8 {
            def_str += ",ff"
            // fmt.Printf("\tn. def_str=%s. base/game_bitcnt = %d/%d \n", def_str, base, game_bitcnt)
        }
    }
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