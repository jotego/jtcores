/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-1-2025 */

package mra

import (
	"bufio"
	"fmt"
	"log"

	"os"
	"path/filepath"
	"strings"

	"jotego/jtframe/macros"
	"jotego/jtframe/common"
)

func Reduce(xml_in string) (error) {
	src, e := collect_sources()
	if e!=nil { return e }
	filter(xml_in, src)
	return nil
}

func collect_sources() ([]string,error) {
	sources := make([]string, 0, 16)
	cores := filepath.Join(os.Getenv("JTROOT"), "cores")
	cores_dir, e := os.ReadDir(cores)
	if e != nil { return nil,e }
	for _, each := range cores_dir {
		if each.IsDir() && each.Name() != "." {
			core := each.Name()
			blank_target := ""
			toml_path := common.ConfigFilePath(core, "mame2mra.toml")
			def_path  := common.ConfigFilePath(core, "macros.def")
			if !common.FileExists(toml_path) { continue }
			if !common.FileExists(def_path) {
				log.SetFlags(0)
				log.Println("Skipping",each.Name()," despite having TOML file as .def file was not found")
				continue
			}
			macros.MakeMacros(core, blank_target )
			cfg, e := ParseTomlFile( core ); if e!=nil { return nil,e }
			sources = append(sources, cfg.Parse.Sourcefile...)
		}
	}
	if Verbose {
		log.SetFlags(0)
		log.Println("Source files:\n", sources)
	}
	return sources, nil
}

func filter(xml_in string, src []string) {
	fin, err := os.Open(xml_in)
	defer fin.Close()
	if err != nil {
		fmt.Println("ERROR: cannot open ", xml_in)
		os.Exit(1)
	}
	scan := bufio.NewScanner(fin)
	dump := true
	for scan.Scan() {
		line := scan.Text()
		if strings.Index(line, "<machine") != -1 {
			words := strings.Fields(line)
			matched := false
			for _, each := range words {
				kv := strings.Split(each, "=")
				if kv[0] == "sourcefile" && len(kv) > 0 {
					v := filepath.Base(strings.Trim(kv[1], "\">"))

					for _, s := range src {
						if s == v {
							matched = true
							break
						}
					}
					break
				}
			}
			dump = matched
		}
		if dump {
			fmt.Println(line)
		}
		if strings.Index(line, "</machine>") != -1 {
			dump = true
		}
	}
}
