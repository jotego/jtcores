package mra

import(
	"encoding/xml"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
)

func delete_core_mrafiles(corename,folder string) error {
	return filepath.WalkDir(folder, func(path string, d fs.DirEntry, err error) error {
		if err != nil { return err }
		if d.IsDir() || strings.HasSuffix(path, ".mra") { return nil }

		mra_corename, e := get_corename_from_mra(path)
		if mra_corename!="" && mra_corename!=corename {return nil}

		if e = os.Remove(path); e != nil {
			return fmt.Errorf("Cannot delete old mra %s. %w", path,e)
		}
		if Verbose {
			fmt.Println("Deleted ", path)
		}
		return nil
	})
}

func get_corename_from_mra(path string) (string,error) {
	mradata, e := os.ReadFile(path); if e != nil { return "",e }
	var testmra MRA
	e = xml.Unmarshal(mradata, &testmra)
	if e != nil {
		return "",fmt.Errorf("Cannot unmarshal %w", e)
	}
	return strings.ToUpper(testmra.Rbf),nil
}
