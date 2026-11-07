/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 7-9-2022 */

package cmd

import (
	"fmt"
	"os"
	"path/filepath"

	"jotego/jtframe/cfgstr"
	. "jotego/jtframe/common"

	"github.com/spf13/cobra"
	"github.com/spf13/pflag"
)

var extra_def, extra_undef string

func init() {
	var cfgstrCmd = &cobra.Command{
		Use:   "cfgstr [core-name]",
		Short: `Parses the macros.def file in the cfg folder`,
		Long:  man_blurb("jtframe-cfgstr", "Parse macros.def data and cfgstr templates for a core."),
		Run:   cfgstr_cmd,
		Args:  cobra.MaximumNArgs(1),
	}

	rootCmd.AddCommand(cfgstrCmd)
	flag := cfgstrCmd.Flags()

	flag.StringP("target", "t", "mist", "Target platform (mist, mister, sidi, sidi128, neptuno, mc2, mcp, pocket, sockit, de1soc, de10std)")
	flag.String("tpl", "", "Path to template file")
	flag.Bool("nodbg", false, "No debug features")
	flag.StringSliceP("def", "d", nil, "Defines macros, separated by comma")
	flag.StringSliceP("undef", "u", nil, "Undefines macros, separated by comma")
	flag.StringP("output", "o", "cfgstr",
		"Type of output: \n\tcfgstr -> config string\n\tbash -> bash script\n\tquartus -> quartus tcl\n\tsimulator name as specified in jtsim")
}

func cfgstr_cmd(cmd *cobra.Command, args []string) {
	cfgstr, e := new_cfgstr_runner(cmd.Flags(), args)
	Must(e)
	e = cfgstr.Run()
	Must(e)
}

func new_cfgstr_runner(flags *pflag.FlagSet, args []string) (cfg *cfgstr.Config, e error) {
	cfg = &cfgstr.Config{}
	cfg.Core, e = get_corename(args)
	if e != nil {
		return nil, e
	}
	target, _ := flags.GetString("target")
	if e = validate_target(target); e != nil {
		return nil, e
	}
	cfg.Target = target
	cfg.Template, _ = flags.GetString("tpl")
	cfg.Add, _ = flags.GetStringSlice("def")
	cfg.Discard, _ = flags.GetStringSlice("undef")
	cfg.Output, _ = flags.GetString("output")
	cfgstr.Verbose = verbose
	if nodbg, _ := flags.GetBool("nodbg"); nodbg {
		cfg.SetReleaseMode()
	}
	return cfg, nil
}

func validate_target(target string) (e error) {
	folderpath := filepath.Join(os.Getenv("JTFRAME"), "target", target)
	folderInfo, e := os.Stat(folderpath)
	if os.IsNotExist(e) || !folderInfo.IsDir() {
		return fmt.Errorf("jtframe cfgstr: unsupported target '%s'", target)
	}
	return nil
}
