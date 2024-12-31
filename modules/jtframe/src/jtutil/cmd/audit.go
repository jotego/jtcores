package cmd

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strconv"

	"github.com/spf13/cobra"
	"github.com/jotego/jtframe/mem"
)

// auditCmd represents the audit command
var auditCmd = &cobra.Command{
	Use:   "audit",
	Short: "Creates a CSV file with the audio channel gains used on each core",
	Run: func(cmd *cobra.Command, args []string) {
		audit_audio()
	},
}

func init() {
	rootCmd.AddCommand(auditCmd)
}

func audit_audio() {
	tmp_dir, e := os.MkdirTemp("/tmp","")
	if e!=nil {
		fmt.Println(e)
		os.Exit(1)
	}
	output, e := os.Create("audit.csv")
	if e!=nil {
		fmt.Println(e)
		os.Exit(1)
	}
	defer output.Close()
	for _, core := range get_valid_cores() {
		var cfg mem.MemConfig
		mem.Parse_file(core,"mem",nil,&cfg)
		e = mem.Make_audio(nil,&cfg,core,tmp_dir)
		if e!=nil { fmt.Println(e)}
		fmt.Fprintf(output,"%s",core)
		report(cfg.Audio.Channels,output)
	}
	os.RemoveAll(tmp_dir)
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
		fmt.Fprintf(output,",%s,%.2f",ch.Name,convert_gain(ch.Gain))
	}
	if len(channels)!=0 { fmt.Fprintln(output) }
}

func convert_gain(hex string) (real float64) {
	if len(hex)!=5 { panic(fmt.Sprintf("Expected 8'hxx but got %s",hex)) }
	fixedpoint,_ := strconv.ParseInt(hex[3:],16,64)
	real = float64(fixedpoint)/128.0
	return real
}