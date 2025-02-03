Parses the core's mame2mra.toml file to generate MRA files.

If called with --reduce, the argument must be the path to mame.xml,
otherwise the file mame.xml in $JTROOT/doc/mame.xml will be used. The tool
should be used to update $JTROOT/doc/mame.xml with new data each tiem a new
core is added. The core folder should contain both the .def and .toml files,
defining at least the MAME source file and the core name.

Each repository is meant to have a reduced mame.xml file in $ROM as
part of the source file commited in git.

The output will either be created in $JTROOT/release or in $JTBIN
depending on the --git argument.

Macros in macros.def are parsed for the "mister" target. This is relevant when
for some macros like JTFRAME_IOCTL_RD, which may have different values for
debugging in MiST without affecting the MRA generation.

TOML elements (see full reference in mame2mra.go)

```
[global]
Orientation={ Fixed=true } # use when rotation CW/CCW information from MAME is not reliable

[parse]
sourcefile=[ "mamefile1.cpp", "mamefile2.cpp"... ]
skip.Setnames=["willskip1","willskip2"]
skip.Bootlegs=true # to skip bootlegs
debug={ # do not parse when --nodbg is set
	machines=[ "1942", "1943" ]
	setnames=[ "gng" ]
}
mustbe.devices=[ "i8751"... ]
mustbe.machines=[ "machine name"... ]
# Promote an alternative set as the main one
# use when the main set doesn't work
main_setnames=[ "setname"... ]

[Pocket]
display_modes=[ 0x61 ] # add extra display modes for Analogue Pocket

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
delete=[ { machine="..." names=[ "Name*", "match??" ] }, ... ] # use */? for matching
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
# this can be used in mem.yaml for audio gain selection
PCBs = [
    { machine=  "aliens"   },
    { machines=["crimfght","gbusters"] },
    { machine=  "thunderx" },
    { machine=  "scontra"  },
]
data = [
	{ pcb_id = true, offset=0 } # filled with the PCB array innformation
	{ machine="...", setname="...", dev="...", offset=3, data="12 32 43 ..." },
	...
]

# region offset table at "start" byte in the header. This will also enable
# the LUT parameters in jtframe_dwnld automatically
offset = { start=0, bits=8, reverse=true, regions=["maincpu","gfx1"...]}

# if there are black bars on the side of the image
# because of black tiles rendered by the software in some games, but not all
# this can be removed by the framework. In some cases, the value will be taken
# from MAME correctly, but in others with assymetrical bands, a compromise
# value must be set here.
# MAME may have wrong information too. The explicit definition here will
# override the calculation derived from MAME.
frames = [
    { width=8 },
]

[buttons]
names=[
	{ setname="...", machine="...", names="shot,jump" }
]
dial = [
	{ machine="...", raw=true, reverse=true }, # Send dial raw signals (much slower pulses)
]

[ROM]
# these MAME ROM regions make up the .rom file (index 1 in MiSTer)
# only specify regions that need parameters
regions = [
	{ name=maincpu, machine=optional, start="MACRONAME_START", width=16, len=0x10000,
		reverse=true, no_offset=true, overrules=[ { names="...", reverse=false }, ... ] },
	{ name==soundcpu, sequence=[2,1,0,0], no_offset=true } # inverts the order and repeats the first ROM
	{ name=plds, skip=true },
	{ name=gfx1, skip=true, remove=[ "notwanted"... ] }, # remove specific files from the dump
	{ name=proms, files=[ {name="myname", crc="12345678", size=0x200 }... ] }	# Replace mame.xml information with specific files
	# regions called "nvram" are automatically skipped
]
# this is the order in the MRA file
order = [ "maincpu", "soundcpu", "gfx1", "gfx2" ]
# Default NVRAM contents, usually not needed
nvram = {
	machines=[ "supports nvram..." ] # NVRAM on all machines by default
	# if a file with the machine or setname and .nvm extension exists in the
	# cfg folder, its data will be set as the default NVRAM content
	defaults=[
		{ machine="...", setname="...", data="00 22 33..." },...
	]
	# if a ROM region with the name "nvram" exists, and no default data
	# was specified, it will be loaded here
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
```