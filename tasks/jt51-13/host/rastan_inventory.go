// Validate replacement Rastan public-bus traces and retain complete prefix indices.
// This analyzes newly recorded input; it never identifies it as the lost original.
package main

import (
    "crypto/sha256"
    "encoding/csv"
    "encoding/hex"
    "encoding/json"
    "errors"
    "flag"
    "fmt"
    "io"
    "math/big"
    "os"
    "path/filepath"
    "strconv"
    "strings"
)

const atto_per_second int64 = 1000000000000000000
const source_hz uint64 = 4000000
const atto_per_clock int64 = 250000000000

type trace_time struct {
    Seconds int64 `json:"seconds"`
    Attoseconds int64 `json:"attoseconds"`
}
type trace_write struct {
    Index int
    Address_row int
    Data_row int
    Time trace_time
    Clock uint64
    Reg uint8
    Value uint8
}
type trace_input struct {
    run string
    out string
    metadata map[string]string
    writes []trace_write
    first trace_time
    last trace_time
    maximum_delta_rounding *big.Int
    pins []file_pin
}
type file_pin struct {
    Path string `json:"path"`
    SHA256 string `json:"sha256"`
    Bytes int `json:"bytes"`
}
type op_snapshot struct {
    Name string `json:"name"`
    Offset int `json:"register_offset"`
    Key_bit int `json:"key_bit"`
    Command_on bool `json:"key_command_on"`
    Known bool `json:"AR_KS_RR_KC_all_observed"`
    AR int `json:"raw_AR"`
    KS int `json:"KS"`
    KC int `json:"KC"`
    Key_code int `json:"KC_bits_6_to_2"`
    KS_term int `json:"key_scale_term"`
    AR_base int `json:"AR_base_6bit"`
    AR_effective int `json:"AR_effective_6bit"`
    RR int `json:"raw_RR_nibble"`
    RR_mapped int `json:"RR_documented_mapped_5bit"`
    RR_effective int `json:"RR_effective_6bit"`
}
type program_snapshot struct {
    ID string `json:"id"`
    Channel int `json:"channel"`
    Algorithm int `json:"algorithm"`
    Algorithm_known bool `json:"algorithm_observed"`
    Register_image []string `json:"register_image_address_value_or_unknown"`
    Operators []op_snapshot `json:"operators"`
}
type key_event struct {
    Write_index int `json:"write_index_zero_based"`
    Data_bus_row int `json:"data_bus_row_zero_based_excluding_header"`
    Time trace_time `json:"time"`
    Source_clock uint64 `json:"absolute_4MHz_source_clock"`
    Channel int `json:"channel"`
    Mask int `json:"key_mask_bits_3_to_6"`
    Previous_mask int `json:"previous_key_mask"`
    Previous_known bool `json:"previous_key_mask_observed"`
    Newly_on int `json:"newly_on_mask_if_previous_known"`
    Newly_off int `json:"newly_off_mask_if_previous_known"`
    Program string `json:"program_id"`
    Algorithm int `json:"algorithm"`
    Algorithm_known bool `json:"algorithm_observed"`
    Operators []op_snapshot `json:"operators"`
}
type inventory struct {
    programs []program_snapshot
    keys []key_event
    live [][]string
    releases [][]string
    prefix [][]string
    algorithms map[string]int
    targets map[string][]string
}

func main() {
    run := flag.String("run", "", "Completed capture directory (bus.csv, registers.csv, capture.txt, exit-status.txt)")
    out := flag.String("out", "", "Fresh exclusive output directory")
    flag.Parse()
    if *run == "" || *out == "" || flag.NArg() != 0 { fmt.Fprintln(os.Stderr, "usage: rastan_inventory -run DIR -out FRESH_DIR"); os.Exit(2) }
    t := trace_input{run:*run, out:*out, maximum_delta_rounding:new(big.Int)}
    e := t.run_inventory(); if e != nil { fmt.Fprintln(os.Stderr, e); os.Exit(1) }
}
func (t *trace_input) run_inventory() error {
    e := t.read_metadata(); if e != nil { return e }
    e = t.read_bus(); if e != nil { return e }
    e = t.check_derived(); if e != nil { return e }
    for _, p := range t.pins { now,e := pin_file(p.Path); if e != nil { return e }; if now != p { return fmt.Errorf("input changed during validation: %s",p.Path) } }
    inv := t.collect()
    return t.publish(inv)
}
func (t *trace_input) read_metadata() error {
    t.metadata = map[string]string{}
    for _, name := range []string{"capture.txt","exit-status.txt","bus.csv","registers.csv","input-sha256.txt","command.txt","mame-source-commit.txt","mame-source-status.txt","output-sha256.txt","wrapper.log"} {
        p := filepath.Join(t.run,name)
        pin,e := pin_file(p); if errors.Is(e,os.ErrNotExist) && name != "capture.txt" && name != "exit-status.txt" && name != "bus.csv" && name != "registers.csv" { continue }; if e != nil { return e }
        t.pins = append(t.pins,pin)
    }
    data,e := os.ReadFile(filepath.Join(t.run,"exit-status.txt")); if e != nil { return e }; if strings.TrimSpace(string(data)) != "0" { return fmt.Errorf("capture has no successful terminal status") }
    data,e = os.ReadFile(filepath.Join(t.run,"capture.txt")); if e != nil { return e }
    for _, line := range strings.Split(strings.TrimSpace(string(data)),"\n") {
        pair := strings.SplitN(line,"=",2); if len(pair)!=2 || pair[0]=="" { return fmt.Errorf("invalid capture metadata line %q",line) }
        if _,ok := t.metadata[pair[0]]; ok { return fmt.Errorf("duplicate metadata key %s",pair[0]) }; t.metadata[pair[0]]=pair[1]
    }
    if t.metadata["source_clock_hz"] != "4000000" || t.metadata["reason"] != "emulated_time_limit" { return fmt.Errorf("require explicit 4MHz source and emulated-time terminal") }
    start,e := metadata_time(t.metadata,"start"); if e != nil { return e }; end,e := metadata_time(t.metadata,"end"); if e != nil { return e }
    if compare_time(start,end)>0 { return fmt.Errorf("capture end precedes start") }
    _,e = source_clock(start); if e != nil { return fmt.Errorf("capture-start clock: %w",e) }
    t.first=start; t.last=end
    return nil
}
func (t *trace_input) read_bus() error {
    f,e := os.Open(filepath.Join(t.run,"bus.csv")); if e != nil { return e }; defer f.Close()
    r := csv.NewReader(f); r.FieldsPerRecord=5
    header,e := r.Read(); if e != nil { return e }; if strings.Join(header,",")!="seconds,attoseconds,address,value,mask" { return fmt.Errorf("incorrect bus header") }
    var address uint8
    var address_row int
    previous := t.first
    count:=0
    for {
        row,e := r.Read(); if e==io.EOF { break }; if e!=nil { return fmt.Errorf("bus row %d: %w",count,e) }
        tm,e := parse_time(row[0],row[1]); if e!=nil { return fmt.Errorf("bus row %d: %w",count,e) }
        if compare_time(tm,previous)<0 || compare_time(tm,t.last)>0 { return fmt.Errorf("nonmonotonic/out-of-capture bus timestamp row %d",count) }; previous=tm
        clock,e := source_clock(tm); if e!=nil { return fmt.Errorf("bus row %d: %w",count,e) }
        a,e := parse_uint(row[2],16); if e!=nil { return e }; v,e := parse_uint(row[3],8); if e!=nil { return e }; m,e := parse_uint(row[4],8); if e!=nil { return e }
        expected:=uint64(0x9000+count%2); if a!=expected || m!=255 { return fmt.Errorf("bus row %d: require alternating 9000/9001 and full FF mask",count) }
        if count%2==0 { address=uint8(v); address_row=count } else { t.writes=append(t.writes,trace_write{len(t.writes),address_row,count,tm,clock,address,uint8(v)}) }
        count++
    }
    if count==0 || count%2!=0 { return fmt.Errorf("empty bus or final unmatched address") }
    declared,e := parse_uint(t.metadata["transactions"],64); if e!=nil || declared!=uint64(count) { return fmt.Errorf("capture transaction count mismatch") }
    declared,e = parse_uint(t.metadata["writes"],64); if e!=nil || declared!=uint64(len(t.writes)) { return fmt.Errorf("capture write count mismatch") }
    return nil
}
func (t *trace_input) check_derived() error {
    f,e := os.Open(filepath.Join(t.run,"registers.csv")); if e!=nil { return e }; defer f.Close()
    r:=csv.NewReader(f);r.FieldsPerRecord=3
    for i,w := range t.writes {
        row,e:=r.Read();if e!=nil { return fmt.Errorf("derived row %d: %w",i,e) }
        a,e:=parse_uint(row[1],8);if e!=nil{return e};v,e:=parse_uint(row[2],8);if e!=nil{return e}
        if uint8(a)!=w.Reg || uint8(v)!=w.Value { return fmt.Errorf("derived row %d register/value differs from bus",i) }
        delta:=trace_time{}
        if i>0 { delta=subtract_time(w.Time,t.writes[i-1].Time) }
        // Validate the producer's decimal float representation, never reconstruct
        // history by accumulating those rounded values.
        // Public attotime conversion multiplies its fractional field by 1e-18.
        // Division by 1e18 is not bit-identical at decimal serialization edges.
        fraction:=float64(delta.Attoseconds)*1e-18
        expected:=strconv.FormatFloat(float64(delta.Seconds)+fraction,'f',18,64)
        if row[0]!=expected { return fmt.Errorf("derived row %d delta serialization %q, expected %q from exact bus time",i,row[0],expected) }
        actual,e:=decimal_attoseconds(row[0]);if e!=nil{return e}
        difference:=new(big.Int).Sub(actual,total_attoseconds(delta));difference.Abs(difference)
        if difference.Cmp(t.maximum_delta_rounding)>0 { t.maximum_delta_rounding.Set(difference) }
    }
    if _,e:=r.Read();e!=io.EOF { return fmt.Errorf("extra derived rows or invalid CSV tail") }
    return nil
}
func (t *trace_input) collect() inventory {
    inv:=inventory{algorithms:map[string]int{},targets:map[string][]string{}}
    for _,name:=range []string{"raw_AR12_key_commands","effective_AR24_key_commands","documented_RR_mapped_1_or_3_key_commands","effective_RR_6bit_1_to_3_key_commands"} {inv.targets[name]=[]string{}}
    var regs [256]uint8
    var known [256]bool
    var masks [8]int
    var mask_known [8]bool
    seen:=map[string]bool{}
    for _,w:=range t.writes {
        a,v:=int(w.Reg),int(w.Value)
        if a==8 {
            ch,mask:=v&7,(v>>3)&15
            p:=snapshot(ch,mask,regs,known)
            if !seen[p.ID] { inv.programs=append(inv.programs,p);seen[p.ID]=true }
            on,off:=0,0
            if mask_known[ch] { on=mask & ^masks[ch];off=masks[ch] & ^mask }
            event:=key_event{w.Index,w.Data_row,w.Time,w.Clock,ch,mask,masks[ch],mask_known[ch],on,off,p.ID,p.Algorithm,p.Algorithm_known,p.Operators}
            inv.keys=append(inv.keys,event)
            if mask!=0 { label:="unknown";if p.Algorithm_known { label=strconv.Itoa(p.Algorithm) };inv.algorithms[label]++ }
            for _,op:=range p.Operators {
                label:=fmt.Sprintf("write%d/ch%d/%s",w.Index,ch,op.Name)
                if op.Command_on && op.Known {
                    if op.AR==12 { inv.targets["raw_AR12_key_commands"]=append(inv.targets["raw_AR12_key_commands"],label) }
                    if op.AR>0 && op.AR_effective==24 { inv.targets["effective_AR24_key_commands"]=append(inv.targets["effective_AR24_key_commands"],label) }
                    if op.RR_mapped<=3 { inv.targets["documented_RR_mapped_1_or_3_key_commands"]=append(inv.targets["documented_RR_mapped_1_or_3_key_commands"],label) }
                    if op.RR_effective>=1 && op.RR_effective<=3 { inv.targets["effective_RR_6bit_1_to_3_key_commands"]=append(inv.targets["effective_RR_6bit_1_to_3_key_commands"],label) }
                }
                if mask_known[ch] && off&(1<<(op.Key_bit-3))!=0 {
                    inv.releases=append(inv.releases,[]string{istr(w.Index),istr(ch),op.Name,istr(op.RR),istr(op.RR_mapped),istr(op.KS_term),istr(op.RR_effective),strconv.FormatBool(op.Known),strconv.FormatUint(w.Clock,10),p.ID,"key-command transition; actual EG phase/tail unobserved"})
                }
            }
            inv.prefix=append(inv.prefix,[]string{istr(len(inv.keys)-1),istr(w.Index),"0",istr(w.Index),"0",istr(w.Address_row),istr(w.Address_row),istr(w.Data_row),strconv.FormatUint(w.Clock,10),istr(w.Time.Seconds),istr(w.Time.Attoseconds),p.ID,"half-open indices; preserve initial delay from capture start"})
            masks[ch]=mask;mask_known[ch]=true
        } else {
            ch,slot,kind:=decode_parameter(a)
            keyed:=false;held:=false
            if ch>=0 { keyed=masks[ch]!=0; if slot>=0 {held=masks[ch]&(1<<(slot_key_bit(slot)-3))!=0} } else {for _,m:=range masks {keyed=keyed||m!=0}}
            if keyed && kind!="other" {
                inv.live=append(inv.live,[]string{istr(w.Index),istr(w.Time.Seconds),istr(w.Time.Attoseconds),strconv.FormatUint(w.Clock,10),fmt.Sprintf("%02X",a),fmt.Sprintf("%02X",v),istr(ch),istr(slot),kind,strconv.FormatBool(held),strconv.FormatBool(known[a]),strconv.FormatBool(known[a]&&regs[a]!=w.Value),"public key-command-held; not proof of audible/active EG"})
            }
        }
        regs[a]=w.Value;known[a]=true
    }
    return inv
}
func (t *trace_input) publish(inv inventory) error {
    e:=os.Mkdir(t.out,0755);if e!=nil{return e}
    rows:=[][]string{{"write_index_zero_based","address_bus_row_zero_based","data_bus_row_zero_based","seconds","attoseconds","absolute_4MHz_clock","delta_clocks_from_previous_write_or_capture_start","register_hex","value_hex"}}
    start,_:=source_clock(t.first)
    for _,w:=range t.writes {
        rows=append(rows,[]string{istr(w.Index),istr(w.Address_row),istr(w.Data_row),istr(w.Time.Seconds),istr(w.Time.Attoseconds),strconv.FormatUint(w.Clock,10),strconv.FormatUint(w.Clock-start,10),fmt.Sprintf("%02X",w.Reg),fmt.Sprintf("%02X",w.Value)});start=w.Clock
    }
    e=write_csv(filepath.Join(t.out,"canonical-writes.csv"),rows);if e!=nil{return e}
    e=write_json(filepath.Join(t.out,"key-events.json"),inv.keys);if e!=nil{return e}
    e=write_json(filepath.Join(t.out,"programs.json"),inv.programs);if e!=nil{return e}
    tables:=[]struct{name string;header []string;rows [][]string}{
        {"prefix-boundaries.csv",[]string{"key_event_index","trigger_write_index","prefix_first_write_inclusive","prefix_end_write_exclusive","prefix_first_bus_row_inclusive","prefix_end_bus_row_exclusive","trigger_address_bus_row","trigger_data_bus_row","trigger_source_clock","trigger_seconds","trigger_attoseconds","program_id","policy"},inv.prefix},
        {"live-writes.csv",[]string{"write_index","seconds","attoseconds","source_clock","register_hex","value_hex","channel_or_minus1","operator_slot_or_minus1","parameter_kind","operator_key_command_on","previous_value_observed","value_changed","limit"},inv.live},
        {"release-candidates.csv",[]string{"write_index","channel","operator","raw_RR","documented_RR_mapped_5bit","KS_term","RR_effective_6bit","rate_fields_observed","source_clock","program_id","limit"},inv.releases},
    }
    for _,table:=range tables {e=write_csv(filepath.Join(t.out,table.name),append([][]string{table.header},table.rows...));if e!=nil{return e}}
    outputs:=[]file_pin{}
    for _,name:=range []string{"canonical-writes.csv","key-events.json","programs.json","prefix-boundaries.csv","live-writes.csv","release-candidates.csv"} {p,e:=pin_file(filepath.Join(t.out,name));if e!=nil{return e};outputs=append(outputs,p)}
    binary,e:=os.Executable();if e!=nil{return e};exe,e:=pin_file(binary);if e!=nil{return e}
    return write_json(filepath.Join(t.out,"summary.json"),map[string]any{
        "state":"COMPLETED_REPLACEMENT_BUS_AND_DERIVED_TRACE_VALIDATED_INVENTORY_RETAINED","replacement_not_recovered_original":true,"source_clock_hz":source_hz,
        "transactions":len(t.writes)*2,"writes":len(t.writes),"key_commands":len(inv.keys),"distinct_channel_programs":len(inv.programs),"live_parameter_attempts_while_key_command_held":len(inv.live),"release_operator_transitions":len(inv.releases),
        "keyon_nonzero_mask_commands_by_algorithm":inv.algorithms,"target_candidates":inv.targets,"first_write":t.writes[0],"last_write":t.writes[len(t.writes)-1],
        "capture_metadata":t.metadata,"maximum_derived_decimal_rounding_error_attoseconds":t.maximum_delta_rounding.String(),"exact_history_time_source":"integer bus seconds/attoseconds and exact 4MHz clocks, never accumulated derived floating deltas",
        "rate_convention":"KC[6:2]>>(3-KS); AR6=min(63,2*AR+KSterm), rawAR0 inhibits; RRmapped5=2*RRnibble+1; RR6=min(63,2*RRmapped5+KSterm). Distinct labels, no inferred EG state.",
        "raw_AR0_inhibition":"AR_effective_6bit is arithmetic index only; raw AR0 remains a separate inhibition condition",
        "prefix_policy":"Every key command has full half-open preceding write/bus prefix from capture start; no register-image or one-note substitute. Captured prefix is not the unavailable historical original.",
        "program_identity":"Program ID hashes observed parameter registers and unknown markers, excluding KEYON mask. Program-file operator key flags describe only its first observation; every key event retains its own mask and operator flags.",
        "provenance_limit":"Input manifests are retained verbatim; current capture script is not inferred to be the producer. Binary hash identifies this analyzer execution, not automatically its build source.",
        "inputs":t.pins,"outputs":outputs,"analyzer_binary":exe,"argv":os.Args,
    })
}
func snapshot(ch,mask int,regs [256]uint8,known [256]bool) program_snapshot {
    p:=program_snapshot{Channel:ch,Algorithm:int(regs[0x20+ch])&7,Algorithm_known:known[0x20+ch]}
    for _,base:=range []int{0x20,0x28,0x30,0x38} {a:=base+ch;s:=fmt.Sprintf("%02X=unknown",a);if known[a]{s=fmt.Sprintf("%02X=%02X",a,regs[a])};p.Register_image=append(p.Register_image,s)}
    for slot,name:=range []string{"M1","M2","C1","C2"} {
        offset:=8*slot;arreg:=0x80+offset+ch;rrreg:=0xe0+offset+ch;kc:=int(regs[0x28+ch]);ar:=int(regs[arreg]&31);ks:=int(regs[arreg]>>6);rr:=int(regs[rrreg]&15);term:=(kc>>2 &31)>>(3-ks);bit:=slot_key_bit(slot)
        p.Operators=append(p.Operators,op_snapshot{name,offset,bit,mask&(1<<(bit-3))!=0,known[arreg]&&known[rrreg]&&known[0x28+ch],ar,ks,kc,kc>>2&31,term,2*ar,min(63,2*ar+term),rr,2*rr+1,min(63,2*(2*rr+1)+term)})
        for _,base:=range []int{0x40,0x60,0x80,0xa0,0xc0,0xe0} {a:=base+offset+ch;s:=fmt.Sprintf("%02X=unknown",a);if known[a]{s=fmt.Sprintf("%02X=%02X",a,regs[a])};p.Register_image=append(p.Register_image,s)}
    }
    sum:=sha256.Sum256([]byte(strings.Join(p.Register_image,",")));p.ID=hex.EncodeToString(sum[:]);return p
}
func slot_key_bit(slot int) int {return []int{3,5,4,6}[slot]}
func decode_parameter(a int) (int,int,string) {
    if a>=0x40 {return a&7,(a>>3)&3,fmt.Sprintf("operator_%02X",a&0xe0)}
    if a>=0x20 {return a&7,-1,fmt.Sprintf("channel_%02X",a&0xf8)}
    switch a {case 1,0xf,0x10,0x11,0x12,0x14,0x18,0x19,0x1b:return -1,-1,"global"}
    return -1,-1,"other"
}
func parse_time(s,a string) (trace_time,error) {
    sec,e:=parse_uint(s,63);if e!=nil{return trace_time{},e};atto,e:=parse_uint(a,63);if e!=nil{return trace_time{},e};if atto>=uint64(atto_per_second){return trace_time{},fmt.Errorf("attoseconds outside normalized range")};return trace_time{int64(sec),int64(atto)},nil
}
func metadata_time(m map[string]string,p string)(trace_time,error){return parse_time(m[p+"_seconds"],m[p+"_attoseconds"])}
func parse_uint(s string,bits int)(uint64,error){if s==""||strings.Trim(s,"0123456789")!=""{return 0,fmt.Errorf("invalid unsigned decimal %q",s)};return strconv.ParseUint(s,10,bits)}
func compare_time(a,b trace_time)int{if a.Seconds<b.Seconds{return -1};if a.Seconds>b.Seconds{return 1};if a.Attoseconds<b.Attoseconds{return -1};if a.Attoseconds>b.Attoseconds{return 1};return 0}
func subtract_time(a,b trace_time)trace_time{d:=trace_time{a.Seconds-b.Seconds,a.Attoseconds-b.Attoseconds};if d.Attoseconds<0{d.Seconds--;d.Attoseconds+=atto_per_second};return d}
func source_clock(t trace_time)(uint64,error){if t.Attoseconds%atto_per_clock!=0{return 0,fmt.Errorf("bus timestamp is not on exact 4MHz source-clock lattice")};s:=uint64(t.Seconds);if s>(^uint64(0)-source_hz)/source_hz{return 0,fmt.Errorf("source-clock integer overflow")};return s*source_hz+uint64(t.Attoseconds/atto_per_clock),nil}
func total_attoseconds(t trace_time)*big.Int{return new(big.Int).Add(new(big.Int).Mul(big.NewInt(t.Seconds),big.NewInt(atto_per_second)),big.NewInt(t.Attoseconds))}
func decimal_attoseconds(s string)(*big.Int,error){p:=strings.Split(s,".");if len(p)!=2||len(p[1])!=18{return nil,fmt.Errorf("derived delta must have exactly18 decimal places")};t,e:=parse_time(p[0],p[1]);if e!=nil{return nil,e};return total_attoseconds(t),nil}
func pin_file(path string)(file_pin,error){data,e:=os.ReadFile(path);if e!=nil{return file_pin{},e};sum:=sha256.Sum256(data);abs,e:=filepath.Abs(path);if e!=nil{return file_pin{},e};return file_pin{abs,hex.EncodeToString(sum[:]),len(data)},nil}
func write_csv(path string,rows [][]string)error{f,e:=os.OpenFile(path,os.O_CREATE|os.O_EXCL|os.O_WRONLY,0644);if e!=nil{return e};w:=csv.NewWriter(f);e=w.WriteAll(rows);close_e:=f.Close();if e!=nil{return e};return close_e}
func write_json(path string,v any)error{data,e:=json.MarshalIndent(v,"","  ");if e!=nil{return e};f,e:=os.OpenFile(path,os.O_CREATE|os.O_EXCL|os.O_WRONLY,0644);if e!=nil{return e};_,e=f.Write(append(data,'\n'));close_e:=f.Close();if e!=nil{return e};return close_e}
func istr[T ~int|~int64](n T)string{return strconv.FormatInt(int64(n),10)}
