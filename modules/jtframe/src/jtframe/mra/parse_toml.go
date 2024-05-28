package mra

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strconv"

	toml "github.com/komkom/toml"
)

func TomlPath( corename string ) string {
	return filepath.Join(os.Getenv("CORES"), corename, "cfg", "mame2mra.toml")
}

func ParseToml( toml_path string, macros map[string]string, corename string, verbose bool) (mra_cfg Mame2MRA) {
	toml_file, err := os.ReadFile(toml_path)
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
	json_enc := toml.New(bytes.NewBuffer(toml_file))
	dec := json.NewDecoder(json_enc)

	err = dec.Decode(&mra_cfg)
	if err != nil {
	       fmt.Println("jtframe mra: problem while parsing TOML file after JSON transformation:\n\t", err)
	       fmt.Println(json_enc)
	       os.Exit(1)
	}

	if len(mra_cfg.Global.Author)==0 {
		mra_cfg.Global.Author=[]string{"jotego"}
	}
	mra_cfg.Dipsw.base, _ = strconv.Atoi(macros["JTFRAME_DIPBASE"])
	// Set the number of buttons to the definition in the macros.def
	if mra_cfg.Buttons.Core == 0 {
		mra_cfg.Buttons.Core, _ = strconv.Atoi(macros["JTFRAME_BUTTONS"])
	}

	if mra_cfg.Header.Len > 0 {
		fmt.Println(`The use of header.len in the TOML file is deprecated.
Set JTFRAME_HEADER=length in macros.def instead`)
	}
	aux, _ := strconv.ParseInt(macros["JTFRAME_HEADER"], 0, 32)
	mra_cfg.Header.Len = int(aux)
	if len(mra_cfg.Dipsw.Delete) == 0 {
		mra_cfg.Dipsw.Delete = []DIPswDelete{
			{ Names: []string{"Unused", "Unknown"} },
		}
	}
	// Add the NVRAM section if it was in the .def file
	if macros["JTFRAME_IOCTL_RD"] != "" {
		aux, err := strconv.ParseInt(macros["JTFRAME_IOCTL_RD"], 0, 32)
		mra_cfg.ROM.Nvram.length = int(aux)
		if err != nil {
			fmt.Println("JTFRAME_IOCTL_RD was ill defined")
			fmt.Println(err)
		}
	}
	// For each ROM region, set the no_offset flag if a
	// sorting option was selected
	// And translate the Start macro to the private start integer value
	for k := 0; k < len(mra_cfg.ROM.Regions); k++ {
		this := &mra_cfg.ROM.Regions[k]
		if this.Start != "" {
			start_str, good1 := macros[this.Start]
			if !good1 {
				fmt.Printf("ERROR: ROM region %s uses undefined macro %s in core %s\n", this.Name, this.Start, corename)
				os.Exit(1)
			}
			aux, err := strconv.ParseInt(start_str, 0, 64)
			if err != nil {
				fmt.Println("ERROR: Macro %s is used as a ROM start, but its value (%s) is not a number\n",
					this.Start, start_str)
				os.Exit(1)
			}
			this.start = int(aux)
			if verbose {
				fmt.Printf("Start in .ROM set to %X for region %s",this.start, this.Name)
				if this.Rename!="" { fmt.Printf(" (%s)",this.Rename)}
				fmt.Println()
			}
		}
		if  this.Sort_even ||
			this.Singleton || len(this.Ext_sort) > 0 ||
			len(this.Name_sort) > 0 || len(this.Sequence) > 0 {
			this.No_offset = true
		}
	}
	return mra_cfg
}