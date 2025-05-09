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
    Version: 1.0
    Date: 7-7-2022 */

package cfgstr

import (
    //"text/template"
    "bytes"
    "fmt"
    "log"
    "os"
    "strconv"
    "strings"
    "text/template"

    . "jotego/jtframe/common"
    "jotego/jtframe/macros"
)

var Verbose bool

func (cfg *Config)Run() (e error){
    def := cfg.prepare_macros()
    e = cfg.dump_macros(def)
    return e
}

func (cfg Config)prepare_macros() (copy map[string]string) {
    macros.MakeMacros(cfg.Core,cfg.Target,cfg.Add...)
    macros.Remove(cfg.Discard...)
    Must(macros.CheckMacros())
    return macros.CopyToMap()
}

func (cfg Config)dump_macros(def map[string]string) error {
    switch cfg.Output {
    case "cfgstr": {
        cfgstr, e := cfg.make_cfgstr(def); if e!=nil { return e }
        dump_cfgstr(cfgstr)
        // show the config string
        if Verbose {
            fmt.Printf("def.Config for target %s (%d bits)\n\n", cfg.Target, len(cfgstr)*8)
            fmt.Println(cfgstr, "\n\nBreak up:")
            aux := strings.Split(cfgstr, ";")
            for _, s := range aux {
                fmt.Println("\t", s)
            }
        }
    }
    case "cpp":
        dump_cpp(def)
    case "bash":
        dump_bash(def)
    case "quartus":
        dump_verilog(def, "set_global_assignment -name VERILOG_MACRO \"%s=%s\"", false)
        // dump_parameter(def, "set_parameter -name %s %s")
    case "iverilog", "verilator":
        dump_verilog(def, "+define+%s=%s", false) // do not escape quotes
    case "ncverilog", "synapticad", "modelsim", "questasim":
        dump_verilog(def, "+define+%s=%s", true) // escape quotes
    case "xcelium":
        dump_verilog(def, "-define %s=%s", true) // escape quotes
    default: {
            return fmt.Errorf("cfgstr: requested invalid output '%s'\n", cfg.Output)
        }
    }
    return nil
}

func (cfg Config)make_cfgstr(def map[string]string) (cfgstr string, e error) {
    jtframe_path := os.Getenv("JTFRAME")
    if jtframe_path == "" {
        log.Fatal("Environment variable JTFRAME must be set")
    }
    var tpath string
    if cfg.Template == "" {
        tfolder := cfg.Target
        if cfg.Target == "sidi" || cfg.Target == "sidi128" { // SiDi shares the config string with MiST
            tfolder = "mist"
        }
        if cfg.Target == "pocket" { // Pocket doesn't have a config string
            return "",nil
        }
        tpath = jtframe_path + "/target/" + tfolder + "/cfgstr"
    } else {
        tpath = cfg.Template
    }
    t, e := template.ParseFiles(tpath); if e!=nil { return "",e }
    var buffer bytes.Buffer
    if e = t.Execute(&buffer, def); e!= nil { return "",e }
    cfgstr = buffer.String()
    // Trim spaces
    chunks := strings.Split(cfgstr, ";")
    cfgstr = ""
    for _, s := range chunks {
        cfgstr = cfgstr + strings.TrimSpace(s) + ";"
    }
    // Removes any ; at the end
    for len(cfgstr) > 0 && cfgstr[len(cfgstr)-1] == ';' {
        cfgstr = cfgstr[0 : len(cfgstr)-1]
    }
    return cfgstr,nil
}

func dump_cfgstr(cfgstr string) {
    f, err := os.Create("cfgstr.hex")
    if err != nil {
        log.Fatal(err)
    }
    defer f.Close()
    for k, c := range cfgstr {
        fmt.Fprintf(f, "%02X ", c)
        if k&0xf == 0xf {
            fmt.Fprintln(f, "")
        }
    }
    for k := len(cfgstr); k < 1024; k++ {
        fmt.Fprintf(f, "00 ")
        if k&0xf == 0xf {
            fmt.Fprintln(f, "")
        }
    }
}

func dump_bash(def map[string]string) {
    for k, v := range def {
        fmt.Printf("export %s=\"%s\"\n", k, v)
    }
}

func dump_cpp(def map[string]string) {
    expected := map[string]bool{
        "JTFRAME_CLK24": false,
        "JTFRAME_CLK48": false,
        "JTFRAME_CLK96": false,
        "JTFRAME_SDRAM96": false,
    }
    for k, v := range def {
        if k == "JTFRAME_PLL" {
            v = strings.TrimPrefix(v, "jtframe_pll")
        }
        // Get only the numerical part
        fmt.Printf("#define _%s %s\n", k, v)
        _, exists := expected[k]
        if exists {
            expected[k] = true
        }
    }
    for k,v := range expected {
        fmt.Printf("const bool %s = %t;\n", k, v)
    }
}

func dump_verilog(def map[string]string, fmtstr string, esc_quotes bool) {
    pllsim := "10.416"
    for k, v := range def {
        // Optionally escape quote characters
        apost := "'"
        if esc_quotes {
            v = strings.ReplaceAll(v, "\"", "\\\"")
            apost = "\\'"
        }
        if len(v) > 2 && v[0:2] == "0x" {
            val, _ := strconv.ParseInt(v, 0, 0)
            v = fmt.Sprintf("'h%X", val)
        }
        // Output the key=value pair in the format
        // given by fmtstr, but skip it if the value
        // contains spaces, as simulators will get
        // confused
        if strings.Index(v, " ") == -1 {
            if k=="JTFRAME_WIDTH" || k=="JTFRAME_HEIGHT" {
                vint, e := strconv.Atoi(v)
                if e != nil {
                    fmt.Printf("Error in %s definition (%s) when converting to integer: ", k, v )
                    fmt.Println( e )
                    os.Exit(1)
                }
                if vint < 512 {
                    v = "9"+apost+"d"+v
                } else {
                    v = "10"+apost+"d"+v
                }
            }
            fmt.Printf(fmtstr+"\n", k, v)
        }
        if k == "JTFRAME_PLL" {
            // Converts to ns for simulation
            khz, err := strconv.Atoi(strings.TrimPrefix(v, "jtframe_pll"))
            if err != nil {
                log.Fatal("cfgstr: while parsing JTFRAME_PLL ", nil)
            }
            ns := 1e6 / float32(khz*16)
            pllsim = fmt.Sprintf("%.3f", ns)
        }
    }
    // Output an extra macro used by fast_pll.v
    fmt.Printf(fmtstr+"\n", "JTFRAME_PLLSIM", pllsim)
}

func dump_parameter(def map[string]string, fmtstr string) {
    for k, v := range def {
        if !strings.HasPrefix(k, "JTFRAME_") {
            continue
        }
        if len(v) == 0 {
            v = "1"
        }
        if len(v) > 2 && v[0:2] == "0x" {
            val, _ := strconv.ParseInt(v, 0, 0)
            v = fmt.Sprintf("'h%X", val)
        }
        // Output the key=value pair in the format
        // given by fmtstr, but skip it if the value
        // contains spaces, as simulators will get
        // confused
        if strings.Index(v, " ") == -1 {
            fmt.Printf(fmtstr+"\n", k, v)
        }
    }
}
