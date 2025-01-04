/*
Copyright © 2022 NAME HERE <EMAIL ADDRESS>

*/
package cmd

import (
	"errors"
	"fmt"
	"os"
	"strings"

	"path/filepath"
	"github.com/spf13/cobra"
)

var verbose bool

var rootCmd = &cobra.Command{
	Use:   "jtframe",
	Short: "File parser for JTFRAME projects. Jose Tejada (c) 2022",
	Long: `File parser for JTFRAME projects. Jose Tejada (c) 2022

Use jtframe to parse the core's def and yaml files to
generate simulation and synthesis files`,
	// Run: func(cmd *cobra.Command, args []string) { },
}

// Execute adds all child commands to the root command and sets flags appropriately.
// This is called by main.main(). It only needs to happen once to the rootCmd.
func Execute() {
	err := rootCmd.Execute()
	if err != nil {
		os.Exit(1)
	}
}

func init() {
	// Here you will define your flags and configuration settings.
	// Cobra supports persistent flags, which, if defined here,
	// will be global for your application.

	// rootCmd.PersistentFlags().StringVar(&cfgFile, "config", "", "config file (default is $HOME/.jtframe.yaml)")
	rootCmd.PersistentFlags().BoolVarP(&verbose, "verbose", "v", false, "verbose")
	// Cobra also supports local flags, which will only run
	// when this action is called directly.
	// rootCmd.Flags().BoolP("toggle", "t", false, "Help message for toggle")
}

var CANNOT_SOLVE_CORENAME error = errors.New("Cannot derive the core name from the current path")

func get_corenames(args []string) ([]string,error) {
	if len(args)>0 {
		for _,corename := range args {
			if e := valid_core(corename); e!= nil { return nil, e }
		}
		return args, nil
	}
	corename, e := get_corename(args)
	if e!= nil { return nil, e }
	return []string{corename},nil
}

// Check that the core folder exist
func valid_core(name string) error {
    fi, e := os.Stat( filepath.Join(os.Getenv("CORES"),name) )
    if e != nil || !fi.IsDir() {
        return fmt.Errorf("%s is not a valid core name", name)
    }
    return nil
}

func get_corename(args []string) (string, error) {
	if len(args)>0 {
		corename := args[0]
		if e := valid_core(corename); e!= nil { return "", e }
		return corename, nil
	}
	// look for the core name in the path
	cwd, _ := os.Getwd()
	cores_path := filepath.Join(os.Getenv("JTROOT"),"cores")
	rel, e := filepath.Rel(cores_path,cwd); if e!=nil { return "",CANNOT_SOLVE_CORENAME }
	parts := strings.Split( filepath.ToSlash(rel), "/" )
	if len(parts)==0 { return "",CANNOT_SOLVE_CORENAME }
	return parts[0],nil
}
