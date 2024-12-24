package vcd

import(
	"fmt"
	"os"
	"regexp"
	"slices"
	"strings"
	"strconv"
	"sort"
)

type VCDSignal struct{
	Scope, Name string
	alias string
	MSB,LSB int // MSB-LSB<=64, so it can fit in Value
	Value, copy uint64
	Concat struct{
		p *VCDSignal	// signal to concatenate
		at int			// bit position at which concatenation starts
	}
}

type vcdData map[string]*VCDSignal
type boolSet map[string]bool
type mameAlias map[string]*VCDSignal
type NameValue map[string]uint64

type Hierarchy struct{
	Nested map[string]*Hierarchy
	Signals map[string]*VCDSignal
}

func (this *VCDSignal) Dump() {
	if this.Scope != "" { fmt.Printf("%s.", this.Scope ) }
	fmt.Printf( "%s",this.Name)
	if this.MSB!=0 {
		fmt.Printf("[%d:%d]",this.MSB, this.LSB)
	}
	fmt.Printf("\t = %X", this.Value )
	if this.Concat.p != nil {
		fmt.Printf(" -> %X", this.FullValue())
	}
	// the frame count is shown in decimal too
	if( this.Name == "frame_cnt") {
		fmt.Printf(" ('d%d)",this.Value)
	}
	fmt.Println()
}

func (this *VCDSignal)FullValue() uint64 {
	v := this.Value
	cat := this.Concat
	for cat.p!=nil {
		v = v | (cat.p.Value<<cat.at) // no masking for now
		cat = cat.p.Concat
	}
	return v
}

func (this *VCDSignal)Save() {
	this.copy = this.Value
}

func (this *VCDSignal)Restore() {
	this.Value = this.copy
}

func (this *VCDSignal)FullName() string {
	if this.Scope=="" {
		return this.Name
	} else {
		return this.Scope+"."+this.Name
	}
}

func (this vcdData)Get(name string) *VCDSignal {
	if name=="" { return nil }
	for _,each := range this {
		if each.FullName()==name { return each }
	}
	return nil
}

// gets the scope part of a hierarchinal signal name
func GetScope( name string ) (string, string) {
	tokens := strings.Split(name,".")
	if len(tokens)==1 {
		return "",name
	}
	return strings.Join(tokens[0:len(tokens)-1],"."), tokens[len(tokens)-1]
}

func (this vcdData)GetAll(name string, matchScope bool) []*VCDSignal {
	if name=="" { return nil }
	r := make([]*VCDSignal,0,1)
	scope,name := GetScope(name)
	for _,each := range this {
		if each.Name==name && (!matchScope || scope==each.Scope) {
			r=append(r,each)
		}
	}
	if len(r) == 0 {
		return nil
	} else {
		return r
	}
}

func RenameRegs( ss vcdData ) {
	// Rename signals for some CPUs
	// fx68k
	for _,each := range ss {
		switch each.Name {
		case "regs68L[0]": each.Name="D0"
		case "regs68L[1]": each.Name="D1"
		case "regs68L[2]": each.Name="D2"
		case "regs68L[3]": each.Name="D3"
		case "regs68L[4]": each.Name="D4"
		case "regs68L[5]": each.Name="D5"
		case "regs68L[6]": each.Name="D6"
		case "regs68L[7]": each.Name="D7"

		case "regs68H[0]": each.Name="D0H"
		case "regs68H[1]": each.Name="D1H"
		case "regs68H[2]": each.Name="D2H"
		case "regs68H[3]": each.Name="D3H"
		case "regs68H[4]": each.Name="D4H"
		case "regs68H[5]": each.Name="D5H"
		case "regs68H[6]": each.Name="D6H"
		case "regs68H[7]": each.Name="D7H"

		case "regs68L[8]": each.Name="A0"
		case "regs68L[9]": each.Name="A1"
		case "regs68L[10]": each.Name="A2"
		case "regs68L[11]": each.Name="A3"
		case "regs68L[12]": each.Name="A4"
		case "regs68L[13]": each.Name="A5"
		case "regs68L[14]": each.Name="A6"
		case "regs68L[16]": each.Name="A7"

		case "regs68H[8]": each.Name="A0H"
		case "regs68H[9]": each.Name="A1H"
		case "regs68H[10]": each.Name="A2H"
		case "regs68H[11]": each.Name="A3H"
		case "regs68H[12]": each.Name="A4H"
		case "regs68H[13]": each.Name="A5H"
		case "regs68H[14]": each.Name="A6H"
		case "regs68H[16]": each.Name="A7H"
		}
	}
	concatHL := func( H,L string ) {
		for _, each := range ss {
			if each.Name==L {
				for _, eachH := range ss {
					if eachH.Name==H && eachH.Scope == each.Scope {
						each.Concat.p = eachH
						each.Concat.at = 16
					}
				}
			}
		}
	}
	concatSeries := func( prefix string ) {
		for k:=0;k<8;k++ {
			L := fmt.Sprintf("%s%d",prefix,k)
			H := fmt.Sprintf("%s%dH",prefix,k)
			concatHL( H, L )
		}
	}

	concatSeries("D")
	concatSeries("A")
	concatHL("PcH","PcL")
}

func formatTime( t uint64 ) string {
	tpico := t
	t /= 1000 // ignore ps
	if t==0 { return "0 s" }
	o := 0
	units := []string{"ns","us","ms","s"}
	parts := []uint64{0,0,0,0}
	for t>0 && o<4 {
		parts[o] = t%1000
		t/= 1000
		o++
	}
	var s string
	for k:=0;k<o; k++ {
		if s!="" { s=","+s}
		s = fmt.Sprintf("%d%s%s",parts[k],units[k],s)
	}
	s = fmt.Sprintf("%s= %d",s,tpico)
	return s
}

func GenerateHierarchy( ss vcdData ) *Hierarchy {
	// Convert ss to a slice
	signals := make([]*VCDSignal,len(ss))
	k := 0
	for _,each := range ss {
		signals[k] = each
		k++
	}
	// Sort by scope length, then signal name
	sort.Slice(signals,func( i, j int ) bool {
		s := strings.Compare(signals[i].Scope,signals[j].Scope)
		if s==0 {
			return strings.Compare(signals[i].Name,signals[j].Name)<0
		}
		return s<0
	})
	// Create the hierarchy following the sorted list
	return fillHierarchy( signals, "")
}

func fillHierarchy( signals []*VCDSignal, scope string ) *Hierarchy {
	h := &Hierarchy{}
	last := ""
	for k, _ := range signals {
		if signals[k].Scope==scope {
			if h.Signals==nil { h.Signals = make(map[string]*VCDSignal) }
			h.Signals[signals[k].Name]=signals[k]
			continue
		}
		if strings.HasPrefix(signals[k].Scope,scope+".") || scope=="" {
			var nx_scope, nx_full string
			var rest []string
			if scope == "" {
				rest = strings.Split( signals[k].Scope, "." )
				nx_scope = rest[0]
				nx_full = nx_scope
			} else {
				rest = strings.Split( signals[k].Scope[len(scope)+1:], "." )
				nx_scope = rest[0]
				nx_full = scope+"."+nx_scope
			}
			if last != nx_scope {
				nested := fillHierarchy( signals[k:], nx_full )
				if h.Nested == nil { h.Nested = make(map[string]*Hierarchy) }
				h.Nested[nx_scope] = nested
				last = nx_scope
			}
			continue
		}
		break
	}
	return h
}

func (this *Hierarchy) Dump(indent string) {
	i2 := indent+"  "
	if len(this.Signals)>0 {
		signals := make([]*VCDSignal,len(this.Signals))
		cnt:=0
		for _,s := range this.Signals {
			signals[cnt] = s
			cnt++
		}
		sort.Slice(signals,func(i,j int) bool {
				return strings.Compare( signals[i].Name, signals[j].Name )<0
			})
		for _, each := range signals{
			fmt.Printf("%s%s (%X)\n",indent,each.Name, each.Value)
		}
	}
	for name,each := range this.Nested {
		fmt.Println(indent+">"+name)
		each.Dump(i2)
	}
}

func HierValues( h *Hierarchy ) map[string]interface{} {
	r := make(map[string]interface{})
	for name,each := range h.Signals {
		r[name] = each.Value
	}
	for name,each := range h.Nested {
		r[name] = HierValues(each)
	}
	return r
}

func replaceHex( s string ) string {
	re := regexp.MustCompile("\\$[a-fA-F0-9]+")
	matches := re.FindAllString( s, -1 )
	for _, each := range matches {
		v, _ := strconv.ParseUint( each[1:], 16, 64 )
		s = strings.ReplaceAll( s, each, fmt.Sprintf("%d",v) )
	}
	return s
}

func setSignal( s string, hier *Hierarchy ) {
	tokens := strings.Split(s,"=")
	if len(tokens)!=2 {
		fmt.Println("Wrong expression ", s)
		return
	}
	p := findSignal(tokens[0], hier )
	if p==nil {
		fmt.Println(s, " not found")
		return
	}
	if tokens[1]!="" && tokens[1][0]=='$' { // ignore a $ before the number
		tokens[1]=tokens[1][1:]
	}
	p.Value, _ = strconv.ParseUint( tokens[1],16, 64)
}

func findSignal( s string, h *Hierarchy ) *VCDSignal {
	t := strings.Split(s,".")
	k:=0
	for ; k<len(t)-1;k++ {
		nx, f := h.Nested[t[k]]
		if !f {
			return nil
		}
		h = nx
	}
	signal, f := h.Signals[t[k]]
	if !f {
		return nil
	}
	return signal
}

func ( this *NameValue ) showDiff( o NameValue ) bool {
	if o==nil || len(o)==0 || len(*this)==0 { return true }
	cnt:=0
	diff := false
	for k,v := range *this {
		v2, f := o[k]
		if f && v!=v2 {
			if k=="frame_cnt" {
				fmt.Printf("%s='d%d\t",k,v)
			} else {
				fmt.Printf("%s=%x\t",k,v)
			}
			cnt++
			if cnt==8 {
				cnt=0
				fmt.Print("\n")
			}
			diff = true
		}
	}
	if cnt!=0 { fmt.Printf("\n") }
	return diff
}

func (file *LnFile) NextVCD( ss vcdData ) bool {
	// fmt.Printf("%s (#%d @%d):\n",file.fname,file.time, file.line)
    for file.Scan() {
        txt := file.Text()
        if txt[0]=='#' {
            file.time, _ = strconv.ParseUint( txt[1:],10,64 )
            return true
        }
        // fmt.Printf("\t%s\n",txt)
        a, v := parseValue(txt)
        assign( a, v, ss )
    }
    return false // EOF
}

// advance the VCD scan upto the next change in any of the provided signals
func (file *LnFile) NextChangeIn( ss vcdData, names []string ) bool {
	// fmt.Printf("%s (#%d @%d):\n",file.fname,file.time, file.line)
	found := false
    for file.Scan() {
        txt := file.Text()
        if txt[0]=='#' {
            file.time, _ = strconv.ParseUint( txt[1:],10,64 )
            if found {
            	return true
            } else {
            	continue
            }
        }
        // fmt.Printf("\t%s\n",txt)
        a, v := parseValue(txt)
        if slices.Contains( names, a ) { found = true }
        assign( a, v, ss )
    }
    return false // EOF
}

// advance until given time
func (file *LnFile) MoveTo( ss vcdData, t0 uint64 ) bool {
	good := true
	for file.time<t0 && good { good = file.NextVCD(ss) }
	return good
}

func GetSignals( file *LnFile ) vcdData {
    ss := make(vcdData)
    scope := ""
    type Mode int
    const(
        SCAN Mode = iota
        PASS
        INIT
    )
    mode := SCAN
    scan_through:
    for ; file.scn.Scan(); file.line++ {
        txt := file.scn.Text()
        switch(mode) {
            case SCAN: {
                tokens := strings.Fields(txt)
                switch(tokens[0]) {
                    case "$date","$version","$timescale": mode=PASS
                    case "$scope": {
                        if tokens[1]!="module" {
                            fmt.Printf("Unknown syntax at line %d: %s\n",file.line, txt)
                        }
                        if scope!="" { scope += "." }
                        scope += tokens[2]
                    }
                    case "$upscope": {
                        if i := strings.LastIndex(scope,"."); i!=-1 {
                            scope = scope[0:i]
                        }
                    }
                    case "$var": {
                        if tokens[1]!="wire" {
                            fmt.Printf("Unknown syntax at line %d: %s\n",file.line, txt)
                            break
                        }
                        s := &VCDSignal{
                            Scope: scope,
                            alias: tokens[3],
                        }
                        bracket_str := tokens[4]
                        bracket := 0
                        if tokens[5][0]=='[' { // bus expression is separated
                            bracket_str = tokens[5]
                            s.Name = tokens[4]
                        } else {
                            bracket = strings.Index(tokens[4],"[")
                            if bracket == -1 {
                                s.Name = tokens[4]
                                bracket_str = ""
                            } else {
                                s.Name = tokens[4][0:bracket]
                                bracket_str = tokens[4]
                                bracket++
                            }
                        }
                        if bracket_str!="" {
                            bend := strings.Index(bracket_str,"]")
                            parts := strings.Split(bracket_str[bracket:bend-1],":")
                            s.MSB,_ = strconv.Atoi(parts[0])
                            if len(parts)==2 {
                                s.LSB,_ = strconv.Atoi(parts[1])
                            }
                        }
                        ss[s.alias] = s
                    }
                    case "$dumpvars": mode = INIT
                }
            }
            case INIT: {
                if txt=="$end" {
                    file.line++
                    break scan_through
                }
                a, v := parseValue( txt )
                assign( a, v, ss )
            }
            case PASS : {
                if txt=="$end" {
                    mode = SCAN
                }
            }
        }
    }
    return ss
}


func assign( alias string, v uint64, ss vcdData) {
    p, _ := ss[alias]
    if p==nil {
    	if alias=="" || alias==" " {
    		fmt.Println("vcd_parser: called assign with no signal alias")
        	os.Exit(1)
    	}
        fmt.Printf("Warning: signal vcdData aliased as -> %s <- not found\n",alias)
        return
    }
    p.Value = v
}

func parseValue( txt string ) ( string, uint64 ) {
    if txt[0]!='0' && txt[0]!='1' && txt[0]!='b' {
        fmt.Printf("Warning: unexpected value definition %s\n",txt)
        return "",0
    }
    var v uint64
    if txt[0] == 'b' {
        var s int
        for s=1; s<len(txt) && txt[s]!=' '; s++ {
            v <<= 1
            if txt[s]=='1' {
                v |= 1
            }
        }
        s++
        return txt[s:], v
    } else {
        if txt[0]=='1' { v=1 }
        return txt[1:], v
    }
}
