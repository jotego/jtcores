package vcd

import(
    "fmt"
    "log"
    "strings"
    "strconv"
)

// keep making this class bigger as refactoring progress
type Comparator struct{
    alu_busy, str_busy, stack_busy *VCDSignal
    kmax int
    retry_step bool
    vcd, trace *LnFile
}

func NewComparator(ss VCDData, vcd, trace *LnFile) Comparator {
    var cmp Comparator
    cmp.alu_busy   = ss.Get(find_similar( "alu_busy", ss ))
    cmp.str_busy   = ss.Get(find_similar( "str_busy", ss ))
    cmp.stack_busy = ss.Get(find_similar( "stack_busy", ss ))
    cmp.kmax = 4
    cmp.vcd  = vcd
    cmp.trace= trace
    return cmp
}

func (cmp *Comparator)show_options() {
    fmt.Println("retry\t",cmp.retry_step)
    fmt.Println("kmax\t",cmp.kmax)
}

func (cmp *Comparator)set_option(name_value string) error {
    tokens := strings.Split(name_value,"=")
    name := tokens[0]
    value := true
    if len(tokens)>2 {
        return fmt.Errorf("Cannot parse assignment %s",name_value)
    }
    if len(tokens)==2 {
        switch(strings.ToLower(tokens[1])) {
            case "false","0": value=false
            case "true", "1": value=true
            default:
                return fmt.Errorf("Cannot parse assignment %s",name_value)
        }
    }
    switch(strings.ToLower(name)) {
        case "retry": cmp.retry_step = value
        default:
                return fmt.Errorf("Unknown option %s",name)
    }
    return nil
}

func (cmp *Comparator)nxVCDChange( sim_st *SimState, mame_alias mameAlias ) (int,bool) {
    l0 := cmp.vcd.line
    changed := false
    irq_bsy := sim_st.data.Get("TOP.game_test.u_game.u_game.u_main.u_cpu.u_ctrl.u_ucode.irq_bsy")
    was_irq := irq_bsy!=nil && irq_bsy.Value!=0
    was_stack := cmp.stack_busy!=nil && cmp.stack_busy.Value!=0
    was_alu   := cmp.alu_busy!=nil   && cmp.alu_busy.Value!=0
    was_str   := cmp.str_busy!=nil   && cmp.str_busy.Value!=0
    for cmp.vcd.Scan() {
        txt := cmp.vcd.Text()
        if txt[0]=='#' {
            cmp.vcd.time, _ = strconv.ParseUint( txt[1:],10,64 )
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
        if cmp.alu_busy!=nil && cmp.alu_busy.Value==1 {
            was_alu = true
            continue
        } else if was_alu {
            changed = true
            break
        }
        if cmp.str_busy!=nil && cmp.str_busy.Value==1 {
            was_str = true
            continue
        } else if was_str {
            changed = true
            break
        }
        if cmp.stack_busy!=nil && cmp.stack_busy.Value==1 {
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
    return cmp.vcd.line-l0, changed
}

func (cmp *Comparator)searchDiff(sim_st *SimState, mame_st *MAMEState,
        ignore *boolSet ) {
    if mame_st.data==nil || len(mame_st.data)==0 {
        cmp.trace.Scan()
        mame_st.data = parseTrace(cmp.trace.Text())
    }

    var good, retried bool
    tvcd := cmp.vcd.time
    var div_time uint64
    main_loop:
    for {
        mame_st.data, good = cmp.nxTraceChange( mame_st )
        if !good { break }
        div_time = cmp.vcd.time
        for k:=0;k<cmp.kmax;k++ {
            if diff( mame_st, "", false, ignore )==0 { continue main_loop }
            _, vcdok := cmp.nxVCDChange( sim_st, mame_st.alias )
            if !vcdok { break }
        }
        if diff( mame_st, "", false, ignore )!=0 {
            if cmp.retry_step && !retried {
                retried = true
                var traceok bool
                mame_st.data, traceok = cmp.nxTraceChange(mame_st)
                if !traceok { break }
                if diff( mame_st, "", false, ignore )==0 {
                    fmt.Println("retried")
                    continue
                }
            }
            good = false
            break
        }
    }
    fmt.Printf("+%s\n", formatTime(cmp.vcd.time-tvcd))
    // display the difference
    diff( mame_st, fmt.Sprintf("trace at %d - vcd time %s (diverged at %s)",
        cmp.trace.line,formatTime(cmp.vcd.time), formatTime(div_time)), true, ignore )
}

func (cmp *Comparator)matchTrace( sim_st *SimState,
         mame_st *MAMEState, mame_alias mameAlias, ignore *boolSet ) bool {
    var good, matched bool
    total_lines := 0
    time0 := cmp.trace.time
    for {
        lines := 0
        lines, good = cmp.nxVCDChange( sim_st, mame_alias )
        total_lines += lines
        matched = diff( mame_st, "", false, ignore )==0
        if !good || matched { break }
    }
    // display the difference
    if !matched {
        fmt.Printf("Impossible to match VCD to MAME")
        diff( mame_st, fmt.Sprintf("sim at time %d",cmp.trace.time), true, ignore )
    } else {
        time1 := cmp.trace.time
        delta := time1-time0
        fmt.Printf("MAME trace matched by advancing the VCD by %d lines (%s)\n",
            total_lines, formatTime(delta))
    }
    return matched
}

func (cmp *Comparator)nxTraceChange( mame_st *MAMEState ) (NameValue,bool) {
    for cmp.trace.Scan() {
        old := mame_st.data
        mame_st.data = parseTrace(cmp.trace.Text())
        for name, _ := range mame_st.alias {
            if mame_st.data[name] != old[name] {
                return mame_st.data,true
            }
        }
    }
    fmt.Printf("Trace EOF\n")
    return mame_st.data,false
}

func (cmp *Comparator)matchVCD( sim_st *SimState, mame_st *MAMEState, ignore *boolSet ) bool {
    if mame_st.data==nil || len(mame_st.data)==0 {
        cmp.trace.Scan()
        mame_st.data = parseTrace(cmp.trace.Text())
    }
    line0 := cmp.trace.line
    var good, matched bool
    for {
        mame_st.data, good = cmp.nxTraceChange(mame_st)
        matched = diff( mame_st, "", false, ignore )==0
        if !good || matched { break }
    }
    // display the difference
    if !matched {
        fmt.Printf("Impossible to match MAME to VCD")
        diff( mame_st, fmt.Sprintf("trace at %d",cmp.trace.line), true, ignore )
    } else {
        fmt.Printf("VCD matched by advancing MAME trace(+ %d lines)\n",cmp.trace.line-line0)
    }
    return matched
}