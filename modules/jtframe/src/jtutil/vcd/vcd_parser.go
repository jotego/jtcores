package vcd

import(
	"fmt"
	"regexp"
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

func formatTime( t uint64 ) string {
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