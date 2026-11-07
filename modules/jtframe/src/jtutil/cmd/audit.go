/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-1-2025 */

package cmd

import (
	"fmt"
	"io"
	"os"
	"path/filepath"

	"github.com/spf13/cobra"
	"jotego/jtframe/mem"
)

// auditCmd represents the audit command
var auditCmd = &cobra.Command{
	Use:   "audit",
	Short: "Creates a CSV file with the audio channel gains used on each core",
	Long:  man_blurb("jtutil-audit", "Create a CSV file with the audio channel gains used on each core."),
	Run: func(cmd *cobra.Command, args []string) {
		e := audit_audio()
		if e != nil {
			fmt.Println(e)
			os.Exit(1)
		}
	},
}

func init() {
	rootCmd.AddCommand(auditCmd)
}

func audit_audio() error {
	tmp_dir, e := os.MkdirTemp("/tmp", "")
	if e != nil {
		return e
	}
	output, e := os.Create("audit.csv")
	if e != nil {
		return e
	}
	defer output.Close()
	for _, core := range get_valid_cores() {
		var cfg mem.MemConfig
		mem.ParseFile(core, "mem.yaml", &cfg)
		e = mem.Make_audio(&cfg, core, tmp_dir)
		if e != nil {
			return fmt.Errorf("%w\nwhile parsing %s", e, core)
		}
		fmt.Fprintf(output, "%s", core)
		report(cfg.Audio.Channels, output)
	}
	os.RemoveAll(tmp_dir)
	return nil
}

func get_valid_cores() (valid []string) {
	corepath := os.Getenv("CORES")
	if corepath == "" {
		return nil
	}
	valid = make([]string, 0, 128)
	filepath.Walk(corepath, func(folderpath string, info os.FileInfo, e error) error {
		if e != nil {
			return e
		}
		if info.IsDir() {
			f, e := os.Open(filepath.Join(folderpath, "cfg", "mem.yaml"))
			defer f.Close()
			if e == nil {
				corename := filepath.Base(folderpath)
				valid = append(valid, corename)
			}
		}
		return nil
	})
	return valid
}

func report(channels []mem.AudioCh, output io.Writer) {
	for _, ch := range channels {
		if ch.Name == "" {
			break
		}
		fmt.Fprintf(output, ",%s,%s", ch.Name, mem.Gain2dec(ch.Gain))
	}
	if len(channels) != 0 {
		fmt.Fprintln(output)
	}
}
