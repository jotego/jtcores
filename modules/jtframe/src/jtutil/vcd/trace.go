package vcd

import(
    "fmt"
    "strconv"
    "strings"
)

type trace_parser_t struct{
    nv NameValue

    line, regs, rest string
}

func parseTrace( s string ) NameValue {
    var parser trace_parser_t
    return parser.Parse(s)
}

func (tp *trace_parser_t)Parse(s string) NameValue {
    tp.line = s
    tp.nv = make(NameValue)
    tp.notify_interrupts()
    tp.parse_tokens()
    return tp.nv
}

func (tp *trace_parser_t)notify_interrupts() {
    k := strings.Index(tp.line,"*")
    if k==-1 {
        tp.regs=tp.line
        return
    }
    tp.rest = tp.line[k:]
    tp.regs = tp.line[0:k]
    if k:=strings.Index(tp.rest,"RTI");k!=-1 {
        tp.nv["RTI"]=1
        fmt.Printf("MAME RTI\n")
    }
    if k:=strings.Index(tp.rest,"868D");k!=-1 {
        fmt.Printf("MAME enters IRQ\n")
    }
}

func (tp *trace_parser_t)parse_tokens() {
    for _, token := range strings.Split(tp.regs,",") {
        k := strings.Index(token,"=")
        if k==-1 || k+1>len(token) { continue }
        value_text := strings.TrimSpace(token[k+1:])
        v,_ := strconv.ParseInt(value_text,16,64)
        n := token[0:k]
        tp.nv[n] = uint64(v)
    }
}