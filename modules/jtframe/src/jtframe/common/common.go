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
    Date: 4-1-2025 */

package common

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

func Must( e error ) {
	if e!=nil {
		fmt.Println(e)
		os.Exit(1)
	}
}

func MustContext( e error, context string ) {
	if e!=nil {
		fmt.Printf("%s\n%s\n",context,e.Error())
		os.Exit(1)
	}
}

func ConfigFilePath(core, file string) (full_path string) {
	if core=="" {
		panic(fmt.Errorf("Blank core name not valid"))
	}
	return filepath.Join(os.Getenv("JTROOT"),"cores",core,"cfg",file)
}

func Doc2string(doc string) string {
	fname := filepath.Join(os.Getenv("JTFRAME"),"doc",doc)
	buf, e := os.ReadFile(fname)
	Must(e)
	return string(buf)
}

func FindFileInFolders( fname string, all_paths []string ) (string, error) {
	for _, path := range all_paths {
		fullpath := filepath.Join(path,fname)
		f, e := os.Open(fullpath)
		defer f.Close()
		if e!=nil {
			return "", e
		}
		return fullpath, nil
	}
	return "",fmt.Errorf("Error cannot find file %s in folders:\n",fname)
}

func FileExists(fname string) bool {
	f, e := os.Open(fname)
	f.Close()
	return e == nil
}

// returns the first 7 hex digits of the commit
func GetCommit() (string,error) {
	cmd := exec.Command("git","rev-parse","HEAD")
	output, e := cmd.Output()
	if e!=nil {
		return "0000000",fmt.Errorf("%s\n%s\n",string(output),e.Error())
	}
	commit:=string(output)
	return commit[0:7],nil
}