/*
Copyright © 2023 Jose Tejada <jose.tejada@jotego.es>

*/
package cmd

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/spf13/cobra"
)

// md5Cmd represents the md5 command
var md5Cmd = &cobra.Command{
	Use:   "md5",
	Short: "List the MD5 sum value of all MRA files",
	Long: `The asm_md5 attribute in MRA files indicate the right sum for all the
data in the file. This is affected by file order and interleaving. Keeping track
of asm_md5 is useful to catch unintentional changes in MRA files`,
	Run: func(cmd *cobra.Command, args []string) {
		list_md5()
	},
}

func init() {
	rootCmd.AddCommand(md5Cmd)
}

func get_mradata(fname string, fi os.DirEntry, err error) error {
    if err != nil {
        fmt.Println(err)
        return nil
    }
    if fi.IsDir() { return nil }
    // get the information
   	var simpleMRA struct{
   		MRA `xml:"misterromdescription"`
   	}
    return nil
}

func list_md5() {

	e := filepath.WalkDir( filepath.Join(os.Getenv("JTBIN"),"mra"), get_mradata)
    if e != nil {
        fmt.Printf(e)
    }
}