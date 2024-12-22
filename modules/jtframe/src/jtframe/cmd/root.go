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

// rootCmd represents the base command when called without any subcommands
var rootCmd = &cobra.Command{
	Use:   "jtframe",
	Short: "File parser for JTFRAME projects. Jose Tejada (c) 2022",
	Long: `File parser for JTFRAME projects. Jose Tejada (c) 2022

Use jtframe to parse the core's def and yaml files to
generate simulation and synthesis files`,
	// Uncomment the following line if your bare application
	// has an action associated with it:
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

	// Cobra also supports local flags, which will only run
	// when this action is called directly.
	// rootCmd.Flags().BoolP("toggle", "t", false, "Help message for toggle")
}

var CANNOT_SOLVE_CORENAME error = errors.New("Cannot derive the core name from the current path")

func get_corename(args []string) (string, error) {
	if len(args)>0 {
		corename := args[0]
        // Check that the core folder exist
        fi, e := os.Stat( filepath.Join(os.Getenv("CORES"),args[0]) )
        if e != nil || !fi.IsDir() {
            return "", fmt.Errorf("%s is not a valid core name", corename)
        }
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

func must(e error) {
	if(e==nil) {return}
    fmt.Println(e)
    os.Exit(1)
}