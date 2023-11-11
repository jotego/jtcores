package mra

import (
	"bufio"
	"fmt"

	// "io/fs"
	"os"
	"path/filepath"
	"strings"

	"github.com/jotego/jtframe/def"
)

func exists(fname string) bool {
	f, e := os.Open(fname)
	defer f.Close()
	return e == nil
}

func collect_sources(verbose bool) []string {
	sources := make([]string, 0, 16)
	cores := filepath.Join(os.Getenv("JTROOT"), "cores")
	cores_dir, e := os.ReadDir(cores)
	if e != nil {
		fmt.Println(e)
		os.Exit(1)
	}
	for _, each := range cores_dir {
		if each.IsDir() && each.Name() != "." {
			cfg := filepath.Join(cores, each.Name(), "cfg")
			args := Args{
				Def_cfg: def.Config{
					Core:    each.Name(),
					Verbose: verbose,
				},
				Toml_path: filepath.Join(cfg, "mame2mra.toml"),
				Verbose:   verbose,
			}
			if exists(def.DefPath(args.Def_cfg)) && exists(args.Toml_path) {
				if verbose {
					fmt.Println("Parsing ", args)
				}
				cfg := parse_toml(&args)
				sources = append(sources, cfg.Parse.Sourcefile...)
			}
		}
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

func Reduce(xml_in string) {
	verbose := false
	src := collect_sources(verbose)
	filter(xml_in, src)
}
