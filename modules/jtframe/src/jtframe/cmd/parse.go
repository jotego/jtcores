/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 21-1-2023 */

package cmd

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"
	"text/template"

	"jotego/jtframe/common"
	"jotego/jtframe/macros"

	"github.com/Masterminds/sprig/v3" // more template functions
	"github.com/spf13/cobra"
)

var target, output_filename string

// declared in cfgstr.go:
// var extra_def, extra_undef string

// parseCmd represents the parse command
var parseCmd = &cobra.Command{
	Use:   "parse <core-name> <template path>",
	Short: "Parses a text template and replaces core macro definitions in it",
	Long:  man_blurb("jtframe-parse", "Parse a text template and replace JTFRAME macro definitions."),
	Args:  cobra.ExactArgs(2),
	Run: func(cmd *cobra.Command, args []string) {
		parsed, e := parse_txt(args[0], args[1], extra_def)
		common.Must(e)
		e = os.WriteFile(output_filename, parsed, 0664)
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

func parse_txt(corename, tpath, newdef string) ([]byte, error) {
	macros.MakeMacros(corename, target)
	macros.AddKeyValPairs(newdef)

	basename := filepath.Base(tpath)
	t, e := template.New(basename).Funcs(sprig.FuncMap()).Funcs(funcMap).ParseFiles(tpath)
	if e != nil {
		fmt.Println(e)
		os.Exit(1)
	}
	var buffer bytes.Buffer
	template_info := struct {
		Macros map[string]string
	}{
		Macros: macros.CopyToMap(),
	}
	e = t.Execute(&buffer, template_info)
	if e != nil {
		return nil, e
	}
	return buffer.Bytes(), nil
}
