/*  This file is part of JT_FRAME.
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
    Date: 28-8-2022 */

package cmd

import (
	"fmt"
	"path/filepath"
	"os"
	"github.com/jotego/jtframe/mra"

	"github.com/spf13/cobra"
)

var mra_args mra.Args
var reduce, clear_folders bool

// mraCmd represents the mra command
var mraCmd = &cobra.Command{
	Use:   "mra <core-name core-name...> or mra --reduce <path-to-mame.xml>",
	Short: "Parses the core's TOML file to generate MRA files",
	Long: `Parses the core's mame2mra.toml file to generate MRA files.

If called with --reduce, the argument must be the path to mame.xml,
otherwise the file mame.xml in $JTROOT/doc/mame.xml will be used.

Each repository is meant to have a reduced mame.xml file in $ROM as
part of the source file commited in git.

The output will either be created in $JTROOT/release or in $JTBIN
depending on the --git argument.

Macros in macros.def are parsed for the "mister" target. This is relevant when
for some macros like JTFRAME_IOCTL_RD, which may have different values for
debugging in MiST without affecting the MRA generation.

TOML elements (see full reference in mame2mra.go)

[parse]
sourcefile=[ "mamefile1.cpp", "mamefile2.cpp"... ]
skip.Setnames=["willskip1","willskip2"]
skip.Bootlegs=true # to skip bootlegs
mustbe.devices=[ "i8751"... ]
mustbe.machines=[ "machine name"... ]
# Promote an alternative set as the main one
# use when the main set doesn't work
main_setnames=[ "setname"... ]

[cheat]
# Cheat file is read by default from cores/core/cheat/machine.s
# It can disabled globally or skipped based on machine/setname
disable=false
files=[
	{ filename="sameforall.s" }, # use the same file for all games
	{ machine="baddudes", setname="", filename="hbarrel.s", skip=false },
]

[dipsw]
rename=[ {name="Bonus Life", to="Bonus", values=[ "value1", "value2"...] }, ... ]
delete=[ "name"... ]
# applies an offset to the bit position of MAME's DIP sw tag given by "name"
# JTTMNT uses this for PunkShot
offset=[
	{ machine="", setname="", name="", value=0 },...
]
# Add more options
extra=[
	{ machine="", setname="", name="", options="", bits="" },...
]
# specify default values, useful when different settings
# affect common bits
defaults=[
	# byte by byte, from LSB to MSB, comma separated
	{ machine="", setname="", value="ff,ff" }
]

[header]
# Specify the length in macros.def: JTFRAME_HEADER=length
# The header signal will be high during the header length
# verilog: if( prog_addr==0 && prog_we && header ) mycfg <= prog_data;
info="Describe the header"
fill=0xff
data = [
	{ machine="...", setname="...", dev="...", offset=3, data="12 32 43 ..." },
	...
]

# region offset table at "start" byte in the header
offset = { start=0, bits=8, reverse=true, regions=["maincpu","gfx1"...]}

[buttons]
names=[
	{ setname="...", machine="...", names="shot,jump" }
]
dial = [
	{ machine="...", raw=true, reverse=true }, # Send dial raw signals (much slower pulses)
]

[ROM]
# only specify regions that need parameters
ddr_load=true
regions = [
	{ name=maincpu, machine=optional, start="MACRONAME_START", width=16, len=0x10000,
		reverse=true, no_offset=true, overrules=[ { names="...", reverse=false }, ... ] },
	{ name==soundcpu, sequence=[2,1,0,0], no_offset=true } # inverts the order and repeats the first ROM
	{ name=plds, skip=true },
	{ name=gfx1, skip=true, remove=[ "notwanted"... ] }, # remove specific files from the dump
	{ name=proms, files=[ {name="myname", crc="12345678", size=0x200 }... ] }	# Replace mame.xml information with specific files
]
# this is the order in the MRA file
order = [ "maincpu", "soundcpu", "gfx1", "gfx2" ]
# Default NVRAM contents, usually not needed
nvram = {
	machines=[ "supports nvram..." ] # NVRAM on all machines by default
	data=[
		{ machine="...", setname="...", data="00 22 33..." },...
	]
}
# split ROM regions in two halves. Each ROM file is split in two
# and each half is merged independently
splits=[
	{ machine="...", offset=0x10000 },
	# if the region is not interleaved, an additional min_len
	# attribute can be set. See kchamp for an example
	{ machine="...", offset=0x10000, min_len=0x2000 },
]
# Patch the final ROM file, the offset will be automatically adjusted
# to add JTFRAME_HEADER
patches = [
	{ machine="...", setname="...", offset=0x0000, data="01 02 03..." },...
]
# file extensions used for cartridge loading
carts=["rom","bin"]
`,
	Run: func(cmd *cobra.Command, args []string) {
		if reduce {
			mra.Reduce(args[0])
		} else { // regular operation, core names are separated by commas
			if clear_folders {
				root := os.Getenv("JTROOT")
				if root=="" {
					fmt.Println("Environment variable JTROOT is not set")
					os.Exit(1)
				}
				e := os.RemoveAll( filepath.Join(root,"release") )
				if mra_args.Verbose && e!= nil { fmt.Println(nil) }
				e = os.RemoveAll( filepath.Join(root,"rom") )
				if mra_args.Verbose && e!= nil { fmt.Println(nil) }
			}
			mra_args.Xml_path=filepath.Join(os.Getenv("JTROOT"),"doc","mame.xml")
			mra_args.Def_cfg.Target="mister"
			for _, each := range args {
				mra_args.Def_cfg.Core = each
				mra.Run(mra_args)
			}
		}
	},
	Args: cobra.MinimumNArgs(1),
}

func init() {
	rootCmd.AddCommand(mraCmd)
	flag := mraCmd.Flags()

	mra_args.Def_cfg.Target = "mist"
	flag.StringVar(&mra_args.Def_cfg.Commit, "commit", "", "result of running 'git rev-parse --short HEAD'")
	// flag.StringVar(&mra_args.Xml_path, "xml", os.Getenv("JTROOT")+"/doc/mame.xml", "Path to MAME XML file")
	flag.StringVar(&mra_args.Year, "year", "", "Year string for MRA file comment")
	flag.BoolVarP(&mra_args.Verbose, "verbose", "v", false, "verbose")
	flag.BoolVarP(&reduce, "reduce", "r", false, "Reduce the size of the XML file by creating a new one with only the entries required by the cores.")
	flag.BoolVar(&clear_folders, "rm", false, "Deletes the release and rom folders in $JTROOT before proceeding")
	flag.BoolVarP(&mra_args.SkipMRA, "skipMRA", "s", false, "Do not generate MRA files")
	flag.BoolVarP(&mra_args.SkipROM, "skipROM", "n", false, "Do not generate .rom files")
	flag.BoolVarP(&mra_args.MainOnly, "mainonly", "o", false, "Only parse the main version of each game")
	flag.BoolVarP(&mra_args.Md5, "md5", "m", false, "Calculate MD5 sum even if the ROM is not saved")
	flag.BoolVar(&mra_args.PrintNames, "names", false, "Print out the title of each game supported")
	flag.BoolVar(&mra_args.SkipPocket, "skipPocket", false, "Do not generate JSON files for the Pocket")
	flag.BoolVarP(&mra_args.Show_platform, "show_platform", "p", false, "Show platform name and quit")
	flag.BoolVarP(&mra_args.JTbin, "git", "g", false, "Save files to JTBIN")
	flag.StringVar(&mra_args.Buttons, "buttons", "", "Buttons used by the game -upto six-")
	flag.StringVar(&mra_args.Author, "author", "jotego", "Core author")
	flag.StringVar(&mra_args.URL, "url", "https://patreon.com/jotego", "Author's URL")
}
