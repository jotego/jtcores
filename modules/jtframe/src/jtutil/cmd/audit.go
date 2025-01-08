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
    Date: 4-1-2025 */

package cmd

import (
	"fmt"
	"io"
	"os"
	"path/filepath"

	"github.com/spf13/cobra"
	"github.com/jotego/jtframe/mem"
)

// auditCmd represents the audit command
var auditCmd = &cobra.Command{
	Use:   "audit",
	Short: "Creates a CSV file with the audio channel gains used on each core",
	Run: func(cmd *cobra.Command, args []string) {
		e := audit_audio()
		if e!=nil {
			fmt.Println(e)
			os.Exit(1)
		}
	},
}

func init() {
	rootCmd.AddCommand(auditCmd)
}

func audit_audio() error {
	tmp_dir, e := os.MkdirTemp("/tmp","")
	if e!=nil { return e }
	output, e := os.Create("audit.csv")
	if e!=nil { return e }
	defer output.Close()
	for _, core := range get_valid_cores() {
		var cfg mem.MemConfig
		mem.Parse_file(core,"mem.yaml",&cfg)
		e = mem.Make_audio(&cfg,core,tmp_dir); if e!=nil { return fmt.Errorf("%w\nwhile parsing %s",e,core) }
		fmt.Fprintf(output,"%s",core)
		report(cfg.Audio.Channels,output)
	}
	os.RemoveAll(tmp_dir)
	return nil
}

func get_valid_cores() (valid []string) {
	corepath := os.Getenv("CORES")
	if corepath=="" { return nil }
	valid = make([]string,0,128)
	filepath.Walk(corepath,func( folderpath string, info os.FileInfo, e error ) error {
		if e!=nil { return e }
		if info.IsDir() {
			f, e := os.Open(filepath.Join(folderpath,"cfg","mem.yaml"))
			defer f.Close()
			if e==nil {
				corename := filepath.Base(folderpath)
				valid=append(valid,corename)
			}
		}
		return nil
	})
	return valid
}

func report(channels []mem.AudioCh, output io.Writer ) {
	for _, ch := range channels {
		if ch.Name=="" { break }
		fmt.Fprintf(output,",%s,%s",ch.Name,mem.Gain2dec(ch.Gain))
	}
	if len(channels)!=0 { fmt.Fprintln(output) }
}
