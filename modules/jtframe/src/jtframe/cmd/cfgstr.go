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
    Version: 1.0
    Date: 7-9-2022 */

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
        Long: Doc2string("jtframe-cfgstr.md"),
        Run: cfgstr_cmd,
        Args: cobra.MaximumNArgs(1),
    }

    rootCmd.AddCommand(cfgstrCmd)
    flag := cfgstrCmd.Flags()

    flag.StringP     ("target", "t",  "mist", "Target platform (mist, mister, sidi, sidi128, neptuno, mc2, mcp, pocket, sockit, de1soc, de10std)")
    flag.String      ("tpl",              "", "Path to template file")
    flag.Bool        ("nodbg",         false, "No debug features")
    flag.StringSliceP("def",    "d",     nil, "Defines macros, separated by comma")
    flag.StringSliceP("undef",  "u",     nil, "Undefines macros, separated by comma")
    flag.StringP     ("output", "o", "cfgstr",
        "Type of output: \n\tcfgstr -> config string\n\tbash -> bash script\n\tquartus -> quartus tcl\n\tsimulator name as specified in jtsim")
}

func cfgstr_cmd(cmd *cobra.Command, args []string) {
    cfgstr, e := new_cfgstr_runner(cmd.Flags(),args); Must(e)
    e=cfgstr.Run(); Must(e)
}

func new_cfgstr_runner(flags *pflag.FlagSet, args []string) (cfg *cfgstr.Config,e error){
    cfg = &cfgstr.Config{}
    cfg.Core, e = get_corename(args)
    if e!=nil { return nil, e }
    target,_ := flags.GetString("target")
    if e=validate_target(target); e!=nil { return nil,e }
    cfg.Target     = target
    cfg.Template,_   = flags.GetString("tpl")
    cfg.Add,_        = flags.GetStringSlice("def")
    cfg.Discard,_    = flags.GetStringSlice("undef")
    cfg.Output,_     = flags.GetString("output")
    cfgstr.Verbose   = verbose
    if nodbg,_ := flags.GetBool("nodbg"); nodbg {
        cfg.SetReleaseMode()
    }
    return cfg,nil
}

func validate_target(target string) (e error) {
    folderpath := filepath.Join(os.Getenv("JTFRAME"),"target",target)
    folderInfo, e := os.Stat(folderpath)
    if os.IsNotExist(e) || !folderInfo.IsDir() {
        return fmt.Errorf("jtframe cfgstr: unsupported target '%s'", target)
    }
    return nil
}
