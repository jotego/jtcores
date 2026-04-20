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
	"errors"
	"fmt"
	"os"
	"strings"

	"github.com/spf13/cobra"
	"path/filepath"
)

var verbose bool

var rootCmd = &cobra.Command{
	Use:   "jtframe",
	Short: "JTFRAME project utilities",
	Long: `JTFRAME project utilities.

Use "man jtframe" for the overview. Use "man jtframe-<command>" for
command-specific documentation, for example "man jtframe-mem" or
"man jtframe-mra".`,
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
	check_environment()
}

func check_environment() {
	for _, env := range []string{"JTROOT", "JTFRAME", "CORES"} {
		value := os.Getenv(env)
		if value == "" {
			fmt.Printf("Environment variable %s is not set\n", env)
			os.Exit(1)
		}
	}
}

var CANNOT_SOLVE_CORENAME error = errors.New("Cannot derive the core name from the current path")

func get_corenames(args []string) ([]string, error) {
	if len(args) > 0 {
		for _, corename := range args {
			if e := valid_core(corename); e != nil {
				return nil, e
			}
		}
		return args, nil
	}
	corename, e := get_corename(args)
	if e != nil {
		return nil, e
	}
	return []string{corename}, nil
}

// Check that the core folder exist
func valid_core(name string) error {
	dirname, rest := filepath.Split(name)
	if dirname != "" {
		return fmt.Errorf("the core name cannot include paths")
	}
	if rest != name {
		return fmt.Errorf("the core name must be a valid file name")
	}
	if name == "" {
		return fmt.Errorf("the core name cannot be blank")
	}
	if name == "." {
		return fmt.Errorf("'.' is not a valid core name")
	}
	if name == ".." {
		return fmt.Errorf("'..' is not a valid core name")
	}

	fi, e := os.Stat(filepath.Join(os.Getenv("CORES"), name))
	if e != nil || !fi.IsDir() {
		return fmt.Errorf("%s is not a valid core name", name)
	}
	return nil
}

func get_corename(args []string) (string, error) {
	if len(args) > 0 {
		corename := args[0]
		if e := valid_core(corename); e != nil {
			return "", e
		}
		return corename, nil
	}
	// look for the core name in the path
	cwd, _ := os.Getwd()
	cores_path := filepath.Join(os.Getenv("JTROOT"), "cores")
	rel, e := filepath.Rel(cores_path, cwd)
	if e != nil {
		return "", CANNOT_SOLVE_CORENAME
	}
	parts := strings.Split(filepath.ToSlash(rel), "/")
	if len(parts) == 0 {
		return "", CANNOT_SOLVE_CORENAME
	}
	corename := parts[0]
	if e := valid_core(corename); e != nil {
		return "", fmt.Errorf("cannot derive core name from folder %s", cwd)
	}
	return corename, nil
}
