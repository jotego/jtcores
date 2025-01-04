package mra

import (
	"bufio"
	"fmt"
	"log"

	// "io/fs"
	"os"
	"path/filepath"
	"strings"

	"github.com/jotego/jtframe/def"
	"github.com/jotego/jtframe/common"
)

func Reduce(xml_in string) {
	src := collect_sources()
	filter(xml_in, src)
}

func collect_sources() []string {
	sources := make([]string, 0, 16)
	cores := filepath.Join(os.Getenv("JTROOT"), "cores")
	cores_dir, e := os.ReadDir(cores)
	if e != nil {
		fmt.Println(e)
		os.Exit(1)
	}
	for _, each := range cores_dir {
		if each.IsDir() && each.Name() != "." {
			cfg_path := filepath.Join(cores, each.Name(), "cfg")
			args := Args{
				Def_cfg: def.Config{
					Core:    each.Name(),
					Verbose: Verbose,
				},
				Toml_path: filepath.Join(cfg_path, "mame2mra.toml"),
			}
			if !common.FileExists(args.Toml_path) { continue }
			if !common.FileExists(def.DefPath(args.Def_cfg)) {
				log.SetFlags(0)
				log.Println("Skipping",each.Name()," despite having TOML file as .def file was not found")
				continue
			}
			def.MakeMacros(args.Def_cfg)
			cfg := ParseToml( args.Toml_path, args.Def_cfg.Core)
			sources = append(sources, cfg.Parse.Sourcefile...)
		}
	}
	if Verbose {
		log.SetFlags(0)
		log.Println("Source files:\n", sources)
	}
	return sources
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
