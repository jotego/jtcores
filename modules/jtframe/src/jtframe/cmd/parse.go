/*
Copyright © 2024 NAME HERE <EMAIL ADDRESS>

*/
package cmd

import (
	"bytes"
	"fmt"
	"os"
	"strings"
	"text/template"
	"path/filepath"

	"github.com/jotego/jtframe/macros"

	"github.com/spf13/cobra"
	"github.com/Masterminds/sprig/v3"	// more template functions
)

var target string

// parseCmd represents the parse command
var parseCmd = &cobra.Command{
	Use:   "parse <core-name> <template path>",
	Short: "Parses a text template and replaces core macro definitions in it",
	Long: `The input file must follow reglar Go template syntax. It can also
use sprig functions. The output is produced to stdout

Macros are accesible like:
	{{ .Macros.TARGET }} => will produce "mist" for the MiST target
	{{ .Macros.JTFRAME_BA1_START }} => will show the value of JTFRAME_BA1_START

Sprig functions: https://masterminds.github.io/sprig/
Standard Go template functions: https://pkg.go.dev/text/template
`,
	Args: cobra.ExactArgs(2),
	Run: func(cmd *cobra.Command, args []string) {
		parse_txt(args[0], args[1], extra_def )
	},
}

func init() {
	rootCmd.AddCommand(parseCmd)
	flag := parseCmd.Flags()

	flag.StringVarP(&target, "target", "t", "mist", "Target platform: mist, mister, pocket, etc.")
	flag.StringVarP(&extra_def, "def", "d", "", "Defines macros, separated by comma")
}

var funcMap = template.FuncMap{
	"env": os.Getenv,
}

func parse_txt( corename, tpath, newdef string ) {
	var cfg struct {
		Macros map[string]string
	}
	macros.MakeMacros( corename, target )
	// additional macros
	for _,each := range strings.Split(newdef,",") {
		parts := strings.SplitN(each,"=",2)
		if len(parts)==0 || parts[0]=="" { continue }
		if len(parts)==1 {
			cfg.Macros[parts[0]]=""
		} else {
			cfg.Macros[parts[0]]=parts[1]
		}
	}

	basename := filepath.Base(tpath)
	t, e := template.New(basename).Funcs(sprig.FuncMap()).Funcs(funcMap).ParseFiles(tpath)
	if e!= nil {
		fmt.Println(e)
		os.Exit(1)
	}
	var buffer bytes.Buffer
	t.Execute(&buffer, cfg)
	os.Stdout.Write(buffer.Bytes())
}