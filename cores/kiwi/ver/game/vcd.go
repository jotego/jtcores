package main

import(
    "bufio"
    "fmt"
    "os"
    "strings"
    "strconv"
    "sync"
)

type Watcher struct {
    Name string `yaml:"name"`
    Scope string `yaml:"scope"`
    Clock string `yaml:"clock"`
    Cpu_dout string `yaml:"cpu_dout"`
    ram_dout string `yaml:"ram_dout"`
    cpu_wrn string `yaml:"wr_n"`

}

type Value struct {
    Time uint64
    Value uint
}

type Signal struct {
    Scope, Name string
    key string
    Width int
    Values []Value
}

type Access struct {
    data, addr int
    write bool
    line int
}

type Signals map[string]*Signal

func ReadVCD( fname string, watch []string ) Signals {
    fin, _ := os.Open(fname)
    defer fin.Close()
    sc := bufio.NewScanner(fin)
    signals := make(Signals)
    scope := ""
    var time uint64
    valid := make(map[string]bool)
    for _,each := range watch {
        valid[each] = true
    }
    for sc.Scan() {
        t := sc.Text()
        if t[0] == '#' {
            time, _ = strconv.ParseUint( t[1:], 10, 64 )
            continue
        }
        if t[0] == '1' {
            s := signals[t[1:]]
            if s!= nil {
                s.Values = append(s.Values,Value{time,1})
            }
        }
        if t[0] == '0' {
            s := signals[t[1:]]
            if s!= nil {
                s.Values = append(s.Values,Value{time,0})
            }
        }
        if t[0] == 'b' {
            tokens := strings.Split(t[1:]," ")
            s := signals[tokens[1]]
            if s!= nil {
                v,_ := strconv.ParseUint( tokens[0], 2, 64 )
                s.Values = append( s.Values, Value{time,uint(v)})
            }
        }
        if strings.HasPrefix(t,"$scope module") {
            var module string
            fmt.Sscanf( t, "$scope module %s $end", &module )
            if scope != "" {
                scope += "."
            }
            scope = scope + module
            // fmt.Println(scope)
            continue
        }
        if strings.HasPrefix(t,"$upscope") {
            if k := strings.LastIndex(scope,"."); k!=-1 {
                scope = scope[0:k]
                // fmt.Println(scope)
                continue
            }
        }
        if strings.HasPrefix(t,"$var wire") {
            var s Signal
            fmt.Sscanf( t,"$var $wire %d ", &s.Width )
            tokens := strings.Split(t," ")
            s.key = tokens[3]
            s.Name = tokens[4]
            s.Scope = scope
            if valid[ s.Scope+"."+s.Name] {
                // fmt.Println(s.Name)
                signals[s.key] = &s
            }
            continue
        }
    }
    return signals
}

func sample( signals Signals, module string, wg *sync.WaitGroup ) {
    fout, _ := os.Create( module+".log" )
    defer fout.Close()
    defer wg.Done()
    scope := "TOP.game_test.u_game.u_game.u_" + module
    watched := make([]*Signal,5)
    mapping := map[string]int{ "ram_cs":0,"dout":1,"ram_dout":2,"wr_n":3,"A":4}
    for _, s := range signals {
        if s.Scope == scope {
            k, e := mapping[s.Name]
            if e {
                watched[k] = s
                fmt.Println("Found ", s.Scope, s.Name)
            }
        }
    }
    l := 0
    ptr := []int{ 0, 0, 0, 0, 0}
    for ptr[0]=0; ptr[0]<len(watched[0].Values);ptr[0]++ {
        cur := watched[0].Values[ptr[0]].Value
        if cur == 1 && l == 0 {
            // Advance each signal until this time
            t := watched[0].Values[ptr[0]].Time
            for k:=1; k<len(watched); k++ {
                var j int
                for j=ptr[k];j<len(watched[k].Values); j++ {
                    if watched[k].Values[j].Time > t {
                        j--
                        break
                    }
                }
                if j>=len(watched[k].Values) {
                    j--
                }
                ptr[k] = j
            }
            // Print each signal
            fmt.Fprintf(fout,"%04X", watched[4].Values[ptr[4]].Value)
            if( watched[3].Values[ptr[3]].Value==1 ) { // wr_n
                fmt.Fprintf(fout," -> %02X\n", watched[2].Values[ptr[2]].Value )
            } else {
                fmt.Fprintf(fout," <- %02X\n", watched[1].Values[ptr[1]].Value )
            }
        }
        l = int(cur)
    }
}

func main() {
    watch := []string{
        "TOP.game_test.u_game.u_game.u_main.ram_cs",
        "TOP.game_test.u_game.u_game.u_main.dout",
        "TOP.game_test.u_game.u_game.u_main.ram_dout",
        "TOP.game_test.u_game.u_game.u_main.wr_n",
        "TOP.game_test.u_game.u_game.u_main.A",
        "TOP.game_test.u_game.u_game.u_sound.ram_cs",
        "TOP.game_test.u_game.u_game.u_sound.dout",
        "TOP.game_test.u_game.u_game.u_sound.ram_dout",
        "TOP.game_test.u_game.u_game.u_sound.wr_n",
        "TOP.game_test.u_game.u_game.u_sound.A",
    }
    signals := ReadVCD("sim.vcd", watch)

    var wg sync.WaitGroup
    wg.Add(2)
    for _, each := range []string{"main","sound"} {
        go sample( signals, each, &wg )
    }
    wg.Wait()
}