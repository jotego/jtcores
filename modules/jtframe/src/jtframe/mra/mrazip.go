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
