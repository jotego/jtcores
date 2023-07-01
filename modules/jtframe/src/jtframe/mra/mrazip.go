package mra

import (
	"archive/zip"
	// "fmt"
	"os"
	"path/filepath"
)

type zipfiles_t map[string]*zip.ReadCloser

var zipfiles zipfiles_t

func get_zipfile(name string) (zipfile *zip.ReadCloser) {
	if zipfiles == nil {
		zipfiles = make(zipfiles_t)
	}
	zf, ok := zipfiles[name]
	if ok {
		return zf
	}
	// Try to open the zipfile
	path := filepath.Join(os.Getenv("HOME"), ".mame", "roms", name)
	var e error
	zf, e = zip.OpenReader(path)
	if e != nil {
		// As both merged and unmerged sets may be specified, it is
		// normal to fail to open files
		// fmt.Printf("Error while parsing zip file %s ",path)
		// fmt.Println(e)
		return
	}
	zipfiles[name] = zf
	return zf
}

func close_allzip() {
	for _, each := range zipfiles {
		each.Close()
	}
	zipfiles = nil
}
