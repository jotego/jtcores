/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 20-2-2026 */

package vcd

import (
	"fmt"
	"os"
	"slices"
	"strings"
)

type CSVConverter struct {
	// if DumpTime is set, the first column of the CSV file contains the VCD time
	DumpTime bool
	// Name of the output file
	OutputFileName string
	// Only dump if these signals are set
	MustBeSet []string

	must_be_set_aliases []string

	ln_file *LnFile
	signals VCDData
	header  []string
	Writer  func(string, ...any) (n int, e error)
}

func (csv *CSVConverter) Convert(filename string) (e error) {
	var f *os.File
	if csv.Writer == nil {
		csv.Writer = func(format string, a ...any) (n int, e error) {
			return fmt.Fprintf(f, format, a...)
		}
	}
	csv.ln_file, csv.signals = LoadVCD(filename)
	if csv.OutputFileName == "" {
		csv.make_output_filename(filename)
	}
	f, e = os.Create(csv.OutputFileName)
	if e != nil {
		return e
	}
	defer f.Close()
	e = csv.fill_aliases()
	if e != nil {
		return e
	}
	csv.make_header()
	csv.dump_header()
	return csv.convert()
}

func (csv *CSVConverter) make_output_filename(filename string) {
	k := len(filename)
	if strings.HasSuffix(filename, ".vcd") && len(filename) > 4 {
		k -= 4
	}
	csv.OutputFileName = filename[0:k] + ".csv"
}

func (csv *CSVConverter) make_header() {
	csv.header = make([]string, 0, len(csv.signals))
	for alias, this_signal := range csv.signals {
		is_constant_signal := slices.Contains(csv.must_be_set_aliases, this_signal.alias)
		if is_constant_signal {
			continue
		}
		csv.header = append(csv.header, alias)
	}
	slices.SortFunc(csv.header, func(a, b string) int {
		return strings.Compare(csv.signals[a].Name, csv.signals[b].Name)
	})
}

func (csv *CSVConverter) fill_aliases() error {
	if len(csv.MustBeSet) == 0 {
		return nil
	}
	csv.must_be_set_aliases = make([]string, len(csv.MustBeSet))
	for k, name := range csv.MustBeSet {
		matches := csv.signals.GetAllNameMatches(name)
		if len(matches) == 0 {
			return fmt.Errorf("Cannot find signal %s in VCD file", name)
		}
		if len(matches) > 1 {
			return fmt.Errorf("Too many signals match %s", name)
		}
		csv.must_be_set_aliases[k] = matches[0].alias
	}
	return nil
}

func (csv *CSVConverter) dump_header() {
	if csv.DumpTime {
		csv.Writer("time,")
	}
	first := true
	for _, alias := range csv.header {
		if !first {
			csv.Writer(",")
		}
		first = false
		csv.Writer(csv.signals[alias].Name)
	}
	csv.Writer("\n")
}

func (csv *CSVConverter) convert() error {
	for csv.ln_file.NextVCD(csv.signals) {
		if csv.skip() {
			continue
		}
		csv.dump_line()
	}
	return nil
}

func (csv *CSVConverter) skip() bool {
	for _, alias := range csv.must_be_set_aliases {
		if csv.signals[alias].Value == 0 {
			return true
		}
	}
	return false
}

func (csv *CSVConverter) dump_line() {
	if csv.DumpTime {
		csv.Writer("%d,", csv.ln_file.time)
	}
	first := true
	for _, name := range csv.header {
		if !first {
			csv.Writer(",")
		}
		first = false
		this_signal, found := csv.signals[name]
		if !found {
			continue
		}
		csv.Writer("%s", this_signal.HexValue())
	}
	csv.Writer("\n")
}
