/*
Copyright © 2023 NAME HERE <EMAIL ADDRESS>

*/
package cmd

import (
	"bytes"
	"fmt"
	"math"
	"path/filepath"
	"os"
	"sort"
	"strings"
	"text/template"

	"github.com/Masterminds/sprig/v3"
	"github.com/spf13/cobra"
	"gopkg.in/yaml.v2"
)

// ucodeCmd represents the ucode command
var ucodeCmd = &cobra.Command{
	Use:   "ucode <module> [variation]",
	Short: "Generate verilog files for microcode",
	Long: `Parses a .uc file, which is in YAML format and generates
a Verilog module and a verilog include file.
`,
	Args: cobra.RangeArgs(1,2),
	Run: func(cmd *cobra.Command, args []string) {
		fname := args[0]
		if len(args)==2 {
			fname = args[1]
		}
		if !strings.HasSuffix(fname,".uc") {
			fname = fname+".uc"
		}
		make_files( args[0], fname )
	},
}

func init() {
	rootCmd.AddCommand(ucodeCmd)

	// Here you will define your flags and configuration settings.

	// Cobra supports Persistent Flags which will work for this command
	// and all subcommands, e.g.:
	// ucodeCmd.PersistentFlags().String("foo", "", "A help for foo")

	// Cobra supports local flags which will only run when this command
	// is called directly, e.g.:
	// ucodeCmd.Flags().BoolP("toggle", "t", false, "Help message for toggle")
}

type UcCtrl map[string][]string

type UcSeq struct{
	Id string `yaml:"id"`
	Seq []string `yaml:"seq"`
	// filled by the program
	Start int
}

type UcConfig struct{
	Control UcCtrl `yaml:"control"`
	Seq []UcSeq `yaml:"sequence"`
	Config struct{
		Seq_len int `yaml:"seq_len"`
	} `yaml:"config"`
}

type UcMacro struct{
	Name string
	Value uint64
}

type UcSignal struct{
	Name string
	Pos, Bw int
	Macros []UcMacro
}

type Signals []UcSignal

func make_signals( fpath string, cfg UcConfig) (int,Signals) {
	signals := make(Signals,0)
	bitcnt := 0
	defined := make(map[string]bool)
	add := func( sig UcSignal ) {
		if _, found := defined[sig.Name]; found {
			fmt.Printf("ERROR: duplicated signal definition %s in %s\n", sig.Name, fpath)
			os.Exit(1)
		}
		defined[sig.Name]=true
		signals = append( signals, sig )
		bitcnt += sig.Bw
	}
	for k,v := range cfg.Control {
		if v==nil || len(v)==0 {
			add( UcSignal{
				Name: strings.ToLower(k),
				Pos: bitcnt,
				Bw: 1,
			})
		} else {
			newsig:=UcSignal{
				Name: strings.ToLower(k+"_ctrl"),
				Pos: bitcnt,
				Bw: int(math.Ceil(math.Log2(float64(len(v))))),
				Macros: make([]UcMacro,len(v)),
			}
			lock_zero := false
			for cnt, each := range v {
				if each=="0" {
					if cnt!=0 {
						fmt.Printf("%s: the \"0\" entry must be the first one. Error in control signal %s\n", fpath, k)
						os.Exit(1)
					}
					each="DEF"
					lock_zero = true
				}
				if lock_zero && cnt!=0 && each=="DEF" {
					fmt.Printf("%s: cannot use DEF as a name for control signal %s because it is already defined\n", fpath, k)
					os.Exit(1)
				}
				newsig.Macros[cnt].Value = uint64(cnt)
				if k!="0" {
					newsig.Macros[cnt].Name = strings.ToUpper(each+"_"+k)
				}
			}
			add( newsig )
		}
	}
	return bitcnt, signals
}

// This is not efficient, but it's easy to write and
// will be fast for the size of our problem
func find_macro( name string, ss Signals ) (pos, bw int, value uint64) {
	for _, sig := range ss {
		if sig.Name==strings.ToLower(name) {
			return sig.Pos, sig.Bw, 1
		}
		if sig.Macros==nil { continue }
		for _, each := range sig.Macros {
			if each.Name==name {
				return sig.Pos, sig.Bw, each.Value
			}
		}
	}
	return -1,-1,0
}

func make_ucode( bw int, ss Signals, cfg UcConfig ) []uint64 {
	if bw>64 {
		fmt.Printf("ERROR: control signal count limited to 64, but %d needed\n",bw)
		os.Exit(1)
	}

	entries := make([]uint64,0)
	k := 0
	for proc_k, _ := range cfg.Seq {
		cfg.Seq[proc_k].Start = k
		for _, all := range cfg.Seq[proc_k].Seq {
			parts := strings.Split(all,",")
			entry := uint64(0)
			for parts_k, _ := range parts {
				parts[parts_k] = strings.TrimSpace(parts[parts_k])
				if parts[parts_k]=="" { continue }
				pos, _, value := find_macro(parts[parts_k], ss)
				if pos==-1 {
					fmt.Printf("Cannot find signal definition for %s\n", parts[parts_k])
					os.Exit(1)
				}
				entry |= value<<pos
			}
			entries = append( entries, entry )
			k++
		}
		// comply with the required sequence length
		if cfg.Config.Seq_len!=0 {
			mod := k%cfg.Config.Seq_len
			k += mod
			for mod>0 {
				entries = append( entries, 0 )
				mod--
			}
		}
	}
	return entries
}

func dump_include( modname string, ss Signals, seq []UcSeq ) {
	temp_data := struct{
		Ss Signals
		Seq []UcSeq
		Seq_bw int
	}{
		Ss: ss,
		Seq: seq,
		Seq_bw: int(math.Ceil(math.Log2(float64(len(seq))))),
	}
	tpath := filepath.Join(os.Getenv("JTFRAME"),"src","jtframe","ucode","ucode.vh")
	t := template.Must(template.New("ucode.vh").Funcs(sprig.FuncMap()).ParseFiles(tpath))
	var buffer bytes.Buffer
	t.Execute(&buffer, temp_data)
	// Dump the file
	outpath := modname+".vh"
	os.WriteFile( outpath, buffer.Bytes(), 0644 )
}

func dump_ucode( modname string, bw int, ucode []uint64, ss Signals ) {
	temp_data := struct{
		Modname string
		Aw, Dw int
		Data []uint64
		Ss Signals
	}{
		Modname: modname,
		Aw: int(math.Ceil(math.Log2(float64(len(ucode))))),
		Dw: bw,
		Data: ucode,
		Ss: ss,
	}
	sort.Slice( temp_data.Ss, func(i,j int) bool {
		suffix_i := strings.HasSuffix(temp_data.Ss[i].Name,"_ctrl")
		suffix_j := strings.HasSuffix(temp_data.Ss[j].Name,"_ctrl")
		if !suffix_i && suffix_j {
			return true
		} else if suffix_i && !suffix_j {
			return false
		}
		return temp_data.Ss[i].Name<temp_data.Ss[j].Name
	} )
	tpath := filepath.Join(os.Getenv("JTFRAME"),"src","jtframe","ucode","ucode.v")
	t := template.Must(template.New("ucode.v").Funcs(sprig.FuncMap()).ParseFiles(tpath))
	var buffer bytes.Buffer
	t.Execute(&buffer, temp_data)
	// Dump the file
	outpath := modname+"_ucode.v"
	os.WriteFile( outpath, buffer.Bytes(), 0644 )
}

func make_files( mname, fname string ) {
	fpath := filepath.Join( os.Getenv("MODULES"),mname,"hdl",fname )
	buf, err := os.ReadFile(fpath)
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
	var cfg UcConfig
	err = yaml.Unmarshal(buf, &cfg)
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
	// generate the data
	bw, signals := make_signals( fpath, cfg )
	ucode := make_ucode( bw, signals, cfg )
	// dump it
	dump_include( mname, signals, cfg.Seq )
	dump_ucode( mname, bw, ucode, signals )
}