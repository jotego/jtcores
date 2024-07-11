package cmd

import (
	"encoding/xml"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"
)

var mra_args struct{
	zip, core *bool
}

// mraCmd represents the mra command
var mraCmd = &cobra.Command{
	Use:   "mra",
	Short: "MRA inspection utilities",
	Long: `List zip files used in JTBIN's .mra files`,
	Run: func(cmd *cobra.Command, args []string) {
		if( *mra_args.zip  ) { list_zip() }
		if( *mra_args.core ) { list_cores() }
	},
}

func init() {
	rootCmd.AddCommand(mraCmd)

	mra_args.zip  = mraCmd.Flags().BoolP("zip", "z", false, "Shows all zip files used in MRA files")
	mra_args.core = mraCmd.Flags().BoolP("core", "c", false, "Shows games supported by each core")
}

func readin_mra(fname string, fi os.DirEntry, game *MRA, err error) (error) {
	if !strings.HasSuffix(fname,".mra") { return nil }
	if err != nil {
		fmt.Println(err)
		return nil
	}
	if fi.IsDir() {
		return nil
	}
	// get the information
	buf, e := os.ReadFile(fname)
	if e != nil {
		return e
	}
	xml.Unmarshal(buf, game)
	if game.Name=="" {
		fmt.Printf("Warning: no game Name for file %s\n",fname)
		return nil
	}
	return err
}

func list_zip() {
	zipuse := make(map[string]bool)

	get_mradata := func(fname string, fi os.DirEntry, err error) error {
		var game MRA
		readin_mra( fname, fi, &game, err )
		if len(game.Rom)==0 { return nil }
		names := strings.Split(game.Rom[0].Zip, "|")
		if len(names) == 0 {
			return nil
		}
		merged := names[len(names)-1]
		zipuse[merged] = true
		return nil
	}
	e := filepath.WalkDir(filepath.Join(os.Getenv("JTBIN"), "mra"), get_mradata)
	if e != nil {
		fmt.Println(e)
		os.Exit(1)
	}
	first := true
	for each, _ := range zipuse {
		if !first {
			fmt.Print(" ")
		}
		fmt.Print(each)
		first = false
	}
}

func list_cores() {
	games := make(map[string][]string)

	get_mradata := func(fname string, fi os.DirEntry, err error) error {
		var game MRA
		readin_mra( fname, fi, &game, err )
		if game.Setname=="" { return nil }
		list, found := games[game.Rbf]
		if !found || list==nil {
			list = make([]string,0,16)
		}
		games[game.Rbf]=append(list,game.Setname)
		return nil
	}
	e := filepath.WalkDir(filepath.Join(os.Getenv("JTBIN"), "mra"), get_mradata)
	if e != nil {
		fmt.Println(e)
		os.Exit(1)
	}
	for key, val := range games {
		for _,each := range val {
			fmt.Printf("%-12s %s\n",key,each)
		}
	}
}
