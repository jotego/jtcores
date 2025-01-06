package files

import(
	"path/filepath"
	"fmt"
	"os"
	"strings"
)

func dump_qip(all []string) error {
	fout, err := os.Create("files.qip")
	if err != nil { return err }
	defer fout.Close()
	for _, each := range all {
		filetype := ""
		switch filepath.Ext(each) {
		case ".sv":
			filetype = "SYSTEMVERILOG_FILE"
		case ".vhd":
			filetype = "VHDL_FILE"
		case ".v":
			filetype = "VERILOG_FILE"
		case ".qip":
			filetype = "QIP_FILE"
		case ".sdc":
			filetype = "SDC_FILE"
		default:
			return fmt.Errorf("JTFILES: unsupported file extension %s in file %s", filepath.Ext(each), each)
		}
		aux := "set_global_assignment -name " + filetype
		if args.Rel {
			aux = aux + "[file join $::quartus(qip_path) " + each + "]"
		} else {
			aux = aux + " " + each
		}
		fmt.Fprintln(fout, aux)
	}
	return nil
}

func dump_sim(all []string ) error {
	fout, err := os.Create( "game.f" )
	if err != nil { return err }
	fout_vhdl, err := os.Create("jtsim_vhdl.f")
	if err != nil { return err }
	defer fout.Close()
	defer fout_vhdl.Close()
	for _, each := range all {
		dump := true
		switch filepath.Ext(each) {
		case ".sv", ".v":
			dump = true
		case ".qip",".sdc":
			dump = false
		case ".vhd":
			fmt.Fprintln(fout_vhdl, each)
			dump = false
		default:
			return fmt.Errorf("JTFILES: unsupported file extension %s in file %s", filepath.Ext(each), each)
		}
		if dump {
			fmt.Fprintln(fout, each)
		}
	}
	return nil
}

func dump_plain(all []string ) error {
	fout, err := os.Create( "files" )
	if err != nil { return err }
	defer fout.Close()
	jtroot := os.Getenv("JTROOT")+"/"
	for _, each := range all {
		each=strings.TrimPrefix(each,jtroot)
		fmt.Fprintln(fout, each)
	}
	return nil
}