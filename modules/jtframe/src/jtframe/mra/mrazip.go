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

package mra

import (
	"archive/zip"
	// "fmt"
	"path/filepath"
)

type zipfiles_t map[string]*zip.ReadCloser

var zipfiles zipfiles_t

func get_zipfile(name, zippath string) (zipfile *zip.ReadCloser, e error) {
	if zipfiles == nil {
		zipfiles = make(zipfiles_t)
	}
	zf, ok := zipfiles[name]
	if ok {
		return zf, nil
	}
	// Try to open the zipfile
	path := filepath.Join(zippath, name)
	zf, e = zip.OpenReader(path)
	if e != nil {
		// As both merged and unmerged sets may be specified, it is
		// normal to fail to open files
		// fmt.Printf("Error while parsing zip file %s ",path)
		// fmt.Println(e)
		return nil, e
	}
	zipfiles[name] = zf
	return zf, nil
}

func close_allzip() {
	for _, each := range zipfiles {
		each.Close()
	}
	zipfiles = nil
}
