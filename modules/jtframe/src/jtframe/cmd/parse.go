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
    Date: 21-1-2023 */

package cmd

import (
	"bytes"
	"fmt"
	"os"
	"text/template"
	"path/filepath"

	"github.com/jotego/jtframe/common"
	"github.com/jotego/jtframe/macros"

	"github.com/spf13/cobra"
	"github.com/Masterminds/sprig/v3"	// more template functions
)

var target, output_filename string
// declared in cfgstr.go:
// var extra_def, extra_undef string

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
		parsed, e := parse_txt(args[0], args[1], extra_def )
		common.Must(e)
		e = os.WriteFile(output_filename,parsed,0664)
		common.Must(e)
	},
}

func init() {
	rootCmd.AddCommand(parseCmd)
	flag := parseCmd.Flags()

	flag.StringVarP(&target, "target", "t", "mist", "Target platform: mist, mister, pocket, etc.")
	flag.StringVarP(&extra_def, "def", "d", "", "Defines macros, separated by comma")
	flag.StringVarP(&output_filename, "output", "o", "/dev/stdout", "Output file")
}

var funcMap = template.FuncMap{
	"env": os.Getenv,
}

func parse_txt( corename, tpath, newdef string ) ([]byte,error) {
	macros.MakeMacros( corename, target )
	macros.AddKeyValPairs(newdef)

	basename := filepath.Base(tpath)
	t, e := template.New(basename).Funcs(sprig.FuncMap()).Funcs(funcMap).ParseFiles(tpath)
	if e!= nil {
		fmt.Println(e)
		os.Exit(1)
	}
	var buffer bytes.Buffer
	template_info := struct{
		Macros map[string]string
	}{
		Macros: macros.CopyToMap(),
	}
	e = t.Execute(&buffer, template_info )
	if e!=nil {
		return nil,e
	}
	return buffer.Bytes(),nil
}