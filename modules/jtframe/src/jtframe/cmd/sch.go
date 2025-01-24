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
	 "fmt"
	"io/fs"
	"path/filepath"
	"os"
	"os/exec"
	"strings"
	"sync"

	"github.com/spf13/cobra"
)

var jtbin, dryrun bool
var output_folder string

type kicad_sch struct{
	path, name string
}

var schCmd = &cobra.Command{
	Use:   "sch [core-name...]",
	Short: "Produces PDF views of the schematics associated with a core in the release/sch folder",
	// Long: "",
	Run: run_sch,
	Args: cobra.ArbitraryArgs,
}

func init() {
	rootCmd.AddCommand(schCmd)
	flag := schCmd.Flags()

	flag.BoolVarP(&jtbin,  "git",    "g", false, "Save files to $JTBIN/sch")
	flag.BoolVar (&dryrun, "dryrun",      false, "Only show what will be done")
}

func run_sch(cmd *cobra.Command, args []string) {
	os.Chdir(os.Getenv("JTROOT"))
	core_folders := get_core_folder_names(args)
	make_output_folder()
	all_sch := find_all_sch(core_folders)
	extract_in_parallel(all_sch)
}

func get_core_folder_names( names []string) (folders []string) {
	if len(names)!=0 {
		return names
	}
	return find_core_folder_names()
}

func find_core_folder_names() (folders []string) {
	cores_fs := os.DirFS( filepath.Join(os.Getenv("JTROOT"),"cores") )
	all_entries, e := fs.ReadDir( cores_fs, "." )
	if e!= nil {
		panic(e)
	}
	folders = make([]string,0,128)
	for _, entry := range all_entries {
		if !entry.IsDir() { continue }
		folders = append(folders,entry.Name())
	}
	return folders
}

func make_output_folder() {
	if jtbin {
		output_folder = filepath.Join(os.Getenv("JTBIN"),"sch")
	} else {
		output_folder = filepath.Join(os.Getenv("JTROOT"),"release","sch")
	}
	os.MkdirAll(output_folder,0776)
}

func find_all_sch(core_folders []string) (all_sch []kicad_sch) {
	cores_fs := os.DirFS( filepath.Join(os.Getenv("JTROOT"),"cores") )
	all_sch = make([]kicad_sch,0,128)
	for _, corename := range core_folders {
		newly_found := parse_folder( corename, cores_fs, filepath.Join(corename,"sch") )
		all_sch = append(all_sch, newly_found...)
	}
	return all_sch
}

func parse_folder( corename string, cores_fs fs.FS, path string) (all_sch []kicad_sch) {
	entries, e := fs.ReadDir( cores_fs, path )
	if e != nil {
		return nil
	}
	all_sch = make([]kicad_sch,0,4)
	for _, entry := range entries {
		if entry.IsDir() {
			found_sch := parse_folder( entry.Name(), cores_fs, filepath.Join(path,entry.Name()) )
			all_sch = append(all_sch,found_sch...)
			continue
		}
		if is_KiCAD_project(entry.Name()) {
			project_path := filepath.Join(os.Getenv("CORES"),path)
			found_sch := kicad_sch{
				name: entry.Name(),
				path: project_path,
			}
			all_sch = append(all_sch,found_sch)
			continue
		}
	}
	return all_sch
}

func is_KiCAD_project(name string) bool {
	return strings.HasSuffix(name,".kicad_pro")
}

func extract_in_parallel(all_sch []kicad_sch) {
	var wg sync.WaitGroup
	wg.Add(len(all_sch))
	for _, sch := range all_sch {
		go run_KiCAD_in_wg(sch,&wg)
	}
	wg.Wait()
}

func run_KiCAD_in_wg(sch kicad_sch,wg *sync.WaitGroup) {
	sch.make_KiCAD_PDF()
	wg.Done()
}

func (sch *kicad_sch) make_KiCAD_PDF() {
	raw_name := strings.TrimSuffix(sch.name,".kicad_pro")
	kicad_sch := filepath.Join(sch.path,raw_name+".kicad_sch")
	pdf_filename := filepath.Join(output_folder,raw_name+".pdf")
	cmd_args := []string{
		"kicad-cli","sch","export","pdf",
		kicad_sch,
		"--output", pdf_filename,
	}
	if verbose || dryrun {
		fmt.Printf("%s\n", strings.Join(cmd_args," "))
	}
	if dryrun {
		return
	}
	cmd := exec.Command( cmd_args[0], cmd_args[1:]... )
	e := cmd.Run()
	if e != nil {
		fmt.Println("warning: ",e)
	}
	if verbose {
		fmt.Printf("- %-20s completed.\n",raw_name)
	}
}

