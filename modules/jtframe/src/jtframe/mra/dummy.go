//go:build !pocket

package mra

import "fmt"

var pocket_warning bool

func pocket_add(machine *MachineXML, cfg Mame2MRA, args Args, def_dipsw string, coremod int, mra *XMLNode) {
	if args.Verbose && !pocket_warning {
		fmt.Println("****  Skipping Pocket file generation ****")
		pocket_warning = true
	}
	// Does nothing
}

func pocket_init(cfg Mame2MRA, args Args) {
	// Does nothing
}

func pocket_save() {
	// Does nothing
}

func pocket_pico( data []byte ) {
	// Does nothing
}

func pocket_clear() {
	// Does nothing
}
