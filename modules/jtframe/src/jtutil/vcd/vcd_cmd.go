/*  This file is part of JTCORES.
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

package vcd

import(
    "bufio"
    "fmt"
    "log"
    "os"
    "sort"
    "strings"
    "strconv"
    "github.com/PaesslerAG/gval"
)

func Prompt( vcd, trace *LnFile, ss vcdData, mame_alias mameAlias ) {
    fses, e := os.Create("trace.ses") // echo all session commands to a file
    defer fses.Close()
    must(e)
    // Read from stdin initially
    nested := make([]*bufio.Scanner,1)
    nested[0] = bufio.NewScanner(os.Stdin)
    scn := nested[0]
    pc_name := find_similar( "pc", ss)
    alu_busy := ss.Get(find_similar( "alu_busy", ss ))
    str_busy := ss.Get(find_similar( "str_busy", ss ))
    stack_busy := ss.Get(find_similar( "stack_busy", ss ))

    scope := findCommonScope(ss)
    fmt.Printf("At scope %s\n",scope)
    hier := GenerateHierarchy(ss)
    mame_st := &MAMEState{ alias: mame_alias, mask: make(NameValue) }
    sim_st := &SimState{ data: ss }
    ignore := make(boolSet)
    kmax := 4

    cmd_diff := func() {
        if diff( mame_st, fmt.Sprintf("trace at %d - vcd time %s",trace.line,formatTime(vcd.time)), true, ignore )==0 {
            fmt.Printf("No differences\n")
        } else {
            extra := func( m, s,f string ) {
                mame_pc,_ := mame_st.data[m]
                p := ss.Get(s)
                var vcd_pc uint64
                if p!=nil { vcd_pc=p.Value }
                if mame_pc!=0 || vcd_pc!=0 {
                    fmt.Printf("\t%s="+f+" <-> "+f+"\n",m,mame_pc,vcd_pc)
                }
            }
            extra("PC",pc_name,"%X")
            extra("frame_cnt","TOP.game_test.frame_cnt","'d%d")
        }
    }

    prompt_loop:
    for {
        if( nested[0]==scn ) { fmt.Printf("> ") }
        if !scn.Scan() || scn.Err()!=nil {
            if len(nested)>1 {
                scn = nested[ len(nested)-2 ]
                nested = nested[0:len(nested)-1]
                continue
            }
            break
        }
        lt := scn.Text()
        fmt.Fprintln(fses,lt)
        if k:=strings.Index(lt,"#"); k!=-1 { lt=lt[0:k] }
        tokens := strings.Fields(lt)
        if len(tokens)==0 { continue }
        if( nested[0]!=scn ) { fmt.Println(">",lt) } // echo if we are parsing a file
        switch tokens[0] {
        case "g","go": searchDiff( vcd, trace, sim_st, mame_st, ignore, alu_busy, stack_busy, str_busy, kmax )
        case "ds","display": {
            var t []string
            if len(tokens)>1 { t = tokens[1:]}
            display( t, vcd, trace, sim_st.data, scope )
        }
        case "d","diff": cmd_diff()
        case "dt","display-trace": {
            names := make([]string,len(mame_st.data))
            k := 0
            for n,_ := range mame_st.data {
                names[k]=n
                k++
            }
            sort.Slice(names,func(i,j int) bool { return strings.Compare(names[i],names[j])<0})
            fmt.Printf("At line %d",trace.line)
            ltxt := trace.Text()
            if k:=strings.Index(ltxt,"*"); k!=-1 { fmt.Printf(ltxt[k+1:])}
            fmt.Println()
            for _,each := range names {
                if each=="frame_cnt" {
                    fmt.Printf("%s=%d\n", each, mame_st.data[each] )
                } else {
                    fmt.Printf("%s=0x%X\n", each, mame_st.data[each] )
                }
            }
        }
        case "a","alias": {
            if len(tokens)==1 {
                for k, each := range mame_st.alias {
                    fmt.Printf("%s -> %s.%s\n",k,each.Scope, each.Name)
                }
                fmt.Printf("\nUse alias clear to delete all aliases\n")
                fmt.Printf("Use alias mame-name=vcd-name to declare a new alias")
                fmt.Printf("Use alias -name to delete one alias\n")
            } else {
                if tokens[1]=="clear" {
                    mame_st.alias = make(mameAlias)
                } else {
                    parseAlias( tokens[1:], sim_st.data, mame_st.alias )
                }
            }
        }
        case "c","concat": {
            if len(tokens)!=3 {
                fmt.Println("Wrong arguments. Use cat main-signal appended-signal")
                break
            }

            p1 := ss.Get(tokens[1])
            p2 := ss.Get(tokens[2])
            if p1==nil {
                fmt.Printf("Cannot find %s\n",tokens[1])
                break
            }
            if p2==nil {
                fmt.Printf("Cannot find %s\n",tokens[2])
                break
            }
            p1.Concat.p = p2
            p1.Concat.at = p1.MSB+1
        }
        case "f", "frame": {
            if len(tokens)!=2 {
                fmt.Println("Wrong arguments. Use frame <number>")
                break
            }
            limit,_ := strconv.ParseUint(tokens[1],0,64)
            mvFrame(vcd,sim_st, uint64(limit) )
        }
        case "h","hierarchy": {
            fmt.Printf("VCD at line %d (time %d ns)\n", vcd.line, vcd.time/1000)
            hier.Dump("")
        }
        case "i","ignore": { // ignore mame-signals, use -name to take it out of the ignore list
            if mame_st.data==nil || len(mame_st.data)==0 {
                fmt.Printf("Start running a trace first\n")
                break
            }
            for k:=1; k<len(tokens);k++ {
                name := tokens[k]
                turnon:= true
                if name[0]=='-' {
                    turnon = false
                    name=name[1:]
                }
                _, f := mame_st.data[name]
                if !f {
                    fmt.Printf("Couldn't find %s\n", name)
                    continue
                }
                ignore[name]=turnon
            }
        }
        case "il", "ignore-list": {
            for k, each := range ignore {
                if each { fmt.Printf("%s\n",k) }
            }
        }
        case "kmax": {
            if len(tokens)==1 {
                fmt.Printf("KMAX=%d\n",kmax)
                break
            }
            if len(tokens)!=2 {
                fmt.Println("Wrong arguments. Use kmax <number>")
                break
            }
            aux,_ := strconv.ParseUint(tokens[1],0,64)
            kmax = int(aux)
            if kmax < 2 {
                fmt.Printf("Setting KMAX to minimum (2)")
                kmax=2
            }
        }
        case "mask": {
            if len(tokens)==1 {
                if len(mame_st.mask)==0 {
                    fmt.Println("No masks defined")
                } else {
                    for k,v := range mame_st.mask {
                        fmt.Printf("%-10s %02X\n",k,v)
                    }
                }
                break
            }
            if len(tokens)!=3 {
                fmt.Println("Wrong arguments. Use mask <signal name> <hex mask>")
                fmt.Println("Use mask without arguments to show the current mask set")
                break
            }
            mask,e := strconv.ParseUint(tokens[2],16,64)
            if e!=nil {
                fmt.Println(e)
                break
            }
            name := tokens[1]
            _, found := mame_st.data[name]
            if !found {
                fmt.Printf("Signal %s not found in MAME trace\n", name)
                break
            }
            mame_st.mask[name]=mask
        }
        case "q","quit": break prompt_loop
        case "scope": {
            switch len(tokens) {
                case 1: fmt.Println(scope)
                case 2: {
                    scope=tokens[1]
                    fmt.Println(scope)
                }
                default: fmt.Println("Wrong number of arguments")
            }
        }
        case "p","print": {
            valueMap := HierValues( hier )
            expr := replaceHex(strings.Join(tokens[1:],""))
            v, e := gval.Evaluate( expr, valueMap )
            if e != nil {
                fmt.Println(e)
                break
            }
            fmt.Printf("%s=%X\n",expr,v)
        }
        case "set": {
            if len(tokens)==1 {
                fmt.Println("Use set vcd-name=value ...")
                break
            }
            for k:=1; k<len(tokens); k++ {
                setSignal( tokens[k], hier )
            }
        }
        case ".","source": {
            if len(tokens)==1 {
                fmt.Println("Use `source filename`")
                break
            }
            f,e := os.Open(tokens[1])
            defer f.Close()
            if e!=nil {
                fmt.Println(e)
                break
            }
            scn = bufio.NewScanner(f)
            nested = append( nested, scn )
            break
        }
        case "s","step": {
            nxVCDChange( vcd, sim_st, mame_st.alias, alu_busy, stack_busy, str_busy )
            cmd_diff()
        }
        case "st","step-trace": {
            old_data := mame_st.data
            var good bool
            mame_st.data, good = nxTraceChange( trace, mame_st )
            if good {
                mame_st.data.showDiff(old_data)
            }
        }
        case "mv","mv-vcd": {
            if len(tokens)==1 {
                fmt.Printf("Use mvvcd signal=value")
                break
            }
            expr := replaceHex(strings.Join(tokens[1:],""))
            fmt.Println(expr)
            mvVCD( vcd, sim_st, hier, expr, scope)
        }
        case "mt","mv-trace": {
            if len(tokens)==1 {
                fmt.Printf("Use mvtrace signal=value")
                break
            }
            expr := replaceHex(strings.Join(tokens[1:],""))
            fmt.Println(expr)
            if !mvTrace( trace, mame_st, expr ) { break } // EOF
        }
        case "match-trace": { // moves the trace until it matches the VCD data
            matchTrace( trace, sim_st, mame_st, ignore )
        }
        case "match-vcd": { // moves the VCD until it matches MAME data
            matchVCD( vcd, sim_st, mame_alias, alu_busy, stack_busy, str_busy, mame_st, ignore )
        }
        case "?","help": {
            fmt.Println(`
a,alias             links a MAME variable name with a signal name in the VCD
                    alias mame-name=vcd-name        declares an alias
                    alias clear                     deletes all aliases
                    alias -foo                      deletes the alias "foo"
d,diff              show differences between MAME and simulation at current time
ds,display          display simulation signals at current time
dt,display-trace    display MAME trace values at current time
f,frame #number     advances the simulation upto the given frame
g,go                compare MAME and simulation until a discrepancy cannot be resolved
?,help              produces this help screen
h,hierarchy         shows the signal hierarchy in the simulation
i,ignore foo boo    ignores the given MAME variables in comparison
il,ignore-list      shows the list of ignored variables
mask                sets bit masks for signals. Bits set at 1 will be ignored.
match-trace         moves MAME forward until it matches simulation
match-vcd           moves the simulation forward until it matches MAME data
mt,mt-trace foo     moves MAME forward until the given condition is met
                    start hex numbers with $ for comparison
mv,mv-vcd foo       moves simulation forward until the given condition is met
p,print             evaluates an expression. Use to test conditions
q,quit              quits the program
.,source foo        executes the commands in the given file
s,step              forwards simulation by one relevant change
set vcd-name=value  alters the value of a simulation signal
st,step-trace       forwards MAME trace by one relevant change`)
        }
        default: fmt.Println("Unknown command ",tokens[0])
        }
    }
    fmt.Println()
}

func mvTrace( trace *LnFile, mame_st *MAMEState, expr string ) bool {
    l0 := trace.line
    old_data := mame_st.data
    if mame_st.data==nil || len(mame_st.data)==0 {
        mame_st.data = parseTrace(trace.Text())
    }
    for {
        mame_st.data["line"]=uint64(trace.line)
        v, e := gval.Evaluate( expr, mame_st.data )
        if e != nil {
            fmt.Println(e)
            break
        }
        f, fe := v.(bool)
        if fe {
            if f {
                fmt.Printf("Moved by %d lines\n",trace.line-l0)
                mame_st.data.showDiff(old_data)
                break
            }
        } else {
            fmt.Printf("Not a boolean expression\n")
            break
        }
        if !trace.Scan() {
            fmt.Println("Trace EOF")
            return false
        }
        mame_st.data = parseTrace(trace.Text())
    }
    delete(mame_st.data,"line")
    return true
}

func mvFrame( vcd *LnFile, sim_st *SimState, limit uint64 ) {
    var frame *VCDSignal
    for _,each := range sim_st.data {
        if each.Name=="frame_cnt" {
            frame = each
            break
        }
    }
    if sim_st.data==nil {
        fmt.Printf("frame_cnt signal not found in VCD\n")
        return
    }
    for frame.Value<limit && vcd.NextVCD(sim_st.data) { }
}

func mvVCD( vcd *LnFile, sim_st *SimState, hier *Hierarchy, expr string, scope string ) bool {
    t0 := vcd.time
    newline:=false
    for {
        valueMap := HierValues( hier )
        valueMap["line"]=uint64(vcd.line)
        valueMap["time"]=vcd.time
        // add signals in scope
        if scope!="" {
            for _,each := range sim_st.data {
                if each.Scope == scope {
                    valueMap[each.Name]=each.Value
                }
            }
        }
        v, e := gval.Evaluate( expr, valueMap )
        if e != nil {
            fmt.Println(e)
            break
        }
        f, fe := v.(bool)
        if fe {
            if f {
                if newline { fmt.Println() }
                fmt.Printf("+ %s\n",formatTime(vcd.time-t0))
                return true
            }
        } else {
            fmt.Printf("Not a boolean expression")
            return false
        }
        if !vcd.NextVCD(sim_st.data) { break }
        if vcd.time-t0>1000000000 { // 1ms
            fmt.Print(".")
            t0=vcd.time
            newline=true
        }
    }
    if newline { fmt.Println() }
    fmt.Println("condition not found")
    return false
}

func find_similar( name string, ss vcdData ) string {
    pc := ""
    for _, each := range ss {
        if strings.ToLower(each.Name)==name {
            pc = each.FullName()
            break
        }
    }
    if pc=="" {
        // Try a partial match at the beginning of the name
        for _, each := range ss {
            if strings.Index( strings.ToLower(each.Name), name )==0 {
                pc = each.FullName()
                break
            }
        }
    }
    if pc=="" {
        fmt.Printf("Could not find a suitable signal as '%s' in the VCD\n",name)
    } else {
        fmt.Printf("Using %s as '%s'\n",name,pc)
    }
    return pc
}

func findCommonScope( ss vcdData ) string {
    scope := ""
    var tokens []string
    first := true
    for _, each := range ss {
        if first {
            scope = each.Scope
            if scope=="" { return "" }
            tokens = strings.Split(scope,".")
            first = false
            continue
        }
        matched := false
        for k:=len(tokens);k!=0;k-- {
            check := strings.Join(tokens[0:k],".")
            check_len := len(check)
            if strings.HasPrefix( each.Scope, check) &&
                ( len(each.Scope)==check_len ||
                 (len(each.Scope)>check_len && each.Scope[check_len]=='.' )) {
                scope = check
                tokens = strings.Split(scope,".")
                matched = true
                break
            }
        }
        if !matched { return "" }
    }
    return scope
}

// t must be MAME-name=VCD-name
func parseAlias( t []string, ss vcdData, mame_alias mameAlias ) {
    main_loop:
    for _,each := range t {
        if each[0]=='-' {
            // remove the alias
            delete(mame_alias, each[1:])
            continue
        }
        tokens := strings.Split(each,"=")
        if len(tokens)==0 { continue }
        vcd_name := tokens[0]
        if len(tokens)==2 {
            vcd_name = tokens[1]
        }
        for _,s := range ss {
            if s.Scope+"."+s.Name==vcd_name {
                mame_alias[tokens[0]]=s
                continue main_loop
            }
            if s.Name==vcd_name {
                mame_alias[tokens[0]]=s
            }
        }
        fmt.Printf("Cannot find VCD signal for %s\n",tokens[0])
    }
}

// display all signals, or only the ones with partial string matches in the t []string
func display( t []string, vcd, trace *LnFile, ss vcdData, scope string ) {
    fmt.Printf("Trace at line %d - VCD at line %d (time %s)\n",
        trace.line, vcd.line, formatTime(vcd.time))
    sorted := make([]struct{
        full string
        p *VCDSignal },len(ss))
    k := 0
    for _, each := range ss {
        sorted[k].p = each
        sorted[k].full = each.FullName()
        k++
    }
    sort.Slice(sorted,func(i,j int)bool {return strings.Compare(sorted[i].full,sorted[j].full)<0})
    for _, each := range sorted {
        print := t==nil
        if !print {
            for _,k := range t {
                if strings.Index(each.full,k)!=-1 {
                    print=true
                    break
                }
            }
        }
        if print { each.p.Dump() }
    }
}

func parseTrace( s string ) NameValue {
    nv := make(NameValue)

    if k := strings.Index(s,"*"); k!=-1 {
        rest := s[k:]
        s = s[0:k]
        if k:=strings.Index(rest,"RTI");k!=-1 {
            nv["RTI"]++
            fmt.Printf("MAME RTI\n")
        }
        if k:=strings.Index(rest,"868D");k!=-1 {
            fmt.Printf("MAME enters IRQ\n")
        }
    }
    for _, token := range strings.Split(s,",") {
        k := strings.Index(token,"=")
        if k==-1 || k+1>len(token) { continue }
        v,_ := strconv.ParseInt(token[k+1:],16,64)
        n := token[0:k]
        nv[n] = uint64(v)
    }
    return nv
}

func diff( st *MAMEState, context string, verbose bool, ignore boolSet ) int {
    d := 0
    var diffs sort.StringSlice
    for name, value := range st.data {
        if name=="PC" { continue }
        p, _ := st.alias[name]
        if p == nil { continue }
        toignore, _ := ignore[name]
        mask, _ := st.mask[name]
        equal := (p.FullValue() | mask) == (value | mask)
        if equal && toignore { // use full value to concatenate data
            ignore[name]=false  // stops ignoring it
            fmt.Printf("%s taken out of the ignore list\n",name)
        }
        if !equal && !toignore {
            if verbose {
                if diffs==nil { diffs = make([]string,0,1) }
                diffs = append(diffs, name)
            }
            d++
        }
        if p.Name=="irq_bsy" && p.Value==1 { // do not compare the interrupt interval
            return 0
        }
    }
    if verbose && diffs!=nil {
        if context!="" { fmt.Println(context) }
        fmt.Println("\t     MAME  -   SIM")
        diffs.Sort()
        for _,name := range diffs {
            p,_ := st.alias[name]
            if p==nil { continue }
            fmt.Printf("\t%-4s %4X <-> %4X (%s.%s)\n", name, st.data[name], p.FullValue(), p.Scope, p.Name )
        }
    }
    return d
}

func nxVCDChange( file *LnFile, sim_st *SimState, mame_alias mameAlias,
        alu_busy, stack_busy, str_busy *VCDSignal ) (int,bool) {
    l0 := file.line
    changed := false
    irq_bsy := sim_st.data.Get("TOP.game_test.u_game.u_game.u_main.u_cpu.u_ctrl.u_ucode.irq_bsy")
    was_irq := irq_bsy!=nil && irq_bsy.Value!=0
    was_stack := stack_busy!=nil && stack_busy.Value!=0
    was_alu := alu_busy!=nil && alu_busy.Value!=0
    was_str := str_busy!=nil && str_busy.Value!=0
    for file.Scan() {
        txt := file.Text()
        if txt[0]=='#' {
            file.time, _ = strconv.ParseUint( txt[1:],10,64 )
            if changed {
                break
            } else {
                continue
            }
        }
        a, v := parseValue(txt)
        assign( a, v, sim_st.data )
        p,_ := sim_st.data[a]
        if p==nil {
            log.Fatal("Error: bad pointer to VCDSignal\n")
        }
        // Skip busy sections
        if alu_busy!=nil && alu_busy.Value==1 {
            was_alu = true
            continue
        } else if was_alu {
            changed = true
            break
        }
        if str_busy!=nil && str_busy.Value==1 {
            was_str = true
            continue
        } else if was_str {
            changed = true
            break
        }
        if stack_busy!=nil && stack_busy.Value==1 {
            was_stack = true
            continue
        } else if was_stack {
            changed = true
            break
        }
        if irq_bsy!=nil && irq_bsy.Value==1 {
            if !was_irq {
                was_irq=true
                fmt.Println("VCD enters IRQ")
            }
            continue  // fly over the interrupt
        } else if was_irq {
            changed = true
            break
        }
        for _,v := range mame_alias {
            if p==v {
                changed = true
                // fmt.Printf("%s=%X\n",p.FullName(),p.Value)
                break
            }
        }
    }
    if !changed {
        fmt.Printf("Reached EOF of VCD file after ")
    }
    return file.line-l0, changed
}

func nxTraceChange( trace *LnFile, mame_st *MAMEState ) (NameValue,bool) {
    // l0 := trace.line
    for trace.Scan() {
        old := mame_st.data
        mame_st.data = parseTrace(trace.Text())
        for name, _ := range mame_st.alias {
            if mame_st.data[name] != old[name] {
                // fmt.Printf(">%s changed\n",name)
                // fmt.Printf("trace +%d lines\n",trace.line-l0)
                return mame_st.data,true
            }
        }
    }
    fmt.Printf("Trace EOF\n")
    return mame_st.data,false
}

func searchDiff( vcd,trace *LnFile, sim_st *SimState, mame_st *MAMEState,
        ignore boolSet, alu_busy, stack_busy, str_busy *VCDSignal, KMAX int ) {
    if mame_st.data==nil || len(mame_st.data)==0 {
        trace.Scan()
        mame_st.data = parseTrace(trace.Text())
    }

    var good bool
    tvcd := vcd.time
    var div_time uint64
    main_loop:
    for {
        mame_st.data, good = nxTraceChange( trace, mame_st )
        if !good { break }
        div_time = vcd.time
        for k:=0;k<KMAX;k++ {
            if diff( mame_st, "", false, ignore )==0 { continue main_loop }
            _, good := nxVCDChange( vcd, sim_st, mame_st.alias, alu_busy, stack_busy, str_busy )
            if !good { break }
            // fmt.Printf("+%d VCD lines\n",lines)
        }
        if diff( mame_st, "", false, ignore )!=0 {
            break
        }
    }
    fmt.Printf("+%s\n", formatTime(vcd.time-tvcd))
    // display the difference
    diff( mame_st, fmt.Sprintf("trace at %d - vcd time %s (diverged at %s)",
        trace.line,formatTime(vcd.time), formatTime(div_time)), true, ignore )
}

func matchTrace( trace *LnFile, sim_st *SimState, mame_st *MAMEState, ignore boolSet ) bool {
    if mame_st.data==nil || len(mame_st.data)==0 {
        trace.Scan()
        mame_st.data = parseTrace(trace.Text())
    }
    line0 := trace.line
    var good, matched bool
    for {
        mame_st.data, good = nxTraceChange( trace, mame_st )
        matched = diff( mame_st, "", false, ignore )==0
        if !good || matched { break }
    }
    // display the difference
    if !matched {
        fmt.Printf("Impossible to match MAME to VCD")
        diff( mame_st, fmt.Sprintf("trace at %d",trace.line), true, ignore )
    } else {
        fmt.Printf("Matched (+ %d lines)\n",trace.line-line0)
    }
    return matched
}

func matchVCD( file *LnFile, sim_st *SimState, mame_alias mameAlias,
        alu_busy, stack_busy, str_busy *VCDSignal, mame_st *MAMEState, ignore boolSet ) bool {
    var good, matched bool
    for {
        mv := 0
        mv, good = nxVCDChange( file, sim_st, mame_alias, alu_busy, stack_busy, str_busy )
        fmt.Printf("Moved by %d lines\n",mv)
        matched = diff( mame_st, "", false, ignore )==0
        if !good || matched { break }
    }
    // display the difference
    if !matched {
        fmt.Printf("Impossible to match VCD to MAME")
        diff( mame_st, fmt.Sprintf("sim at time %d",file.time), true, ignore )
    }
    return matched
}


func MakeAlias( trace string, ss vcdData ) mameAlias {
    mame_alias := make(mameAlias)
    tokens := strings.Split(trace,",")
    if len(tokens)==0 { return mame_alias }

    for _,each := range tokens {
        if len(each)==0 || each[0]=='*' { break }
        k := strings.Index(each,"=")
        if k==-1 { continue }
        name := strings.ToLower(each[0:k])
        if name=="pc" || name=="frame_cnt" { continue } // these are normally hard to match
        var p *VCDSignal
        for _, v := range ss {
            if strings.ToLower(v.Name)==name {
                p = v
                break
            }
        }
        if p==nil {
            fmt.Printf("Cannot alias signal %s\n",name)
            continue
        }
        mame_alias[each[0:k]]=p
    }
    return mame_alias
}

