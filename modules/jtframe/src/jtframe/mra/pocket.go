package mra

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"time"

	"jotego/jtframe/betas"
	"jotego/jtframe/macros"
	"jotego/jtframe/common"
	. "jotego/jtframe/xmlnode"
)

const DIP_LIMIT = 14

var meta CoreMetadata
var pck_dir struct {
	root,
	cores, // JSON files defining the core go here
	common, // .rom files produced by the mra tool go here
	assets, // JSON instance files to load each .rom go here
	presets, // JSON interact files to load each .rom go here
	inputs, // JSON input files to load each .rom go here
	saves,  // .sav files for NVRAM go here
	platform string // The platform name and image go here
}
var platform_name, platform_type string

const APF_Version string = "APF_VER_1"

type Audio struct {
	Magic string `json:"magic"`
}

type Data_slots struct {
	Name       string   `json:"name"`
	Id         int      `json:"id"`
	Required   bool     `json:"required"`
	Parameters string   `json:"parameters"`
	Filename	string	`json:"filename,omitempty"`
	Extensions []string `json:"extensions"`
	// Size_exact   int      `json:"size_exact"`
	// Size_maximum int      `json:"size_maximum"`
	Address string `json:"address"`
	Nonvolatile  bool     `json:"nonvolatile"`
	// Deferload    bool     `json:"deferload"`
}

type Data struct {
	Magic      string       `json:"magic"`
	Data_slots []Data_slots `json:"data_slots"`
}

type NameValue struct {
	Name  string `json:"name"`
	Value string `json:"value"`
}

type OSDVariable struct {
	Name       string      `json:"name"`
	Id         int         `json:"id"`
	Type       string      `json:"type"`
	Enabled    bool        `json:"enabled"`
	Persist    bool        `json:"persist"`
	Writeonly  bool        `json:"writeonly,omitempty"`
	Address    string      `json:"address"`
	Defaultval int         `json:"defaultval"` // The 'check' type fails if this omitted for 0. See 1941 (JTCPS1)
	Value      int         `json:"value"`
	ValueOff   int         `json:"value_off,omitempty"`
	Mask       string      `json:"mask,omitempty"`
	Options    []NameValue `json:"options,omitempty"`
}

type Interact struct {
	setname   string
	desc      string
	Magic     string        `json:"magic"`
	Variables []OSDVariable `json:"variables"`
	Messages  []string      `json:"messages"`
	clone     bool
}

type Scaler_modes struct {
	Width    int `json:"width"`
	Height   int `json:"height"`
	Aspect_w int `json:"aspect_w"`
	Aspect_h int `json:"aspect_h"`
	Rotation int `json:"rotation"`
	Mirror   int `json:"mirror"`
}

type Display_mode struct {
	Id string `json:"id"`
}

type Video struct {
	Magic         string         `json:"magic"`
	Scaler_modes  []Scaler_modes `json:"scaler_modes"`
	Display_modes []Display_mode `json:"display_modes"`
}

type Metadata struct {
	Platform_ids []string `json:"platform_ids"`
	Shortname    string   `json:"shortname"`
	Description  string   `json:"description"`
	Author       string   `json:"author"`
	Url          string   `json:"url"`
	Version      string   `json:"version"`
	Date_release string   `json:"date_release"`
}

type Core struct {
	Magic     string     `json:"magic"`
	Metadata  Metadata   `json:"metadata"`
	Framework Framework  `json:"framework"`
	Cores     []CoreItem `json:"cores"`
}

type Dock struct {
	Supported     bool `json:"supported"`
	Analog_output bool `json:"analog_output"`
}

type Hardware struct {
	Link_port         bool `json:"link_port"`
	Cartridge_adapter int  `json:"cartridge_adapter"`
}

type Framework struct {
	Target_product   string   `json:"target_product"`
	Version_required string   `json:"version_required"`
	Sleep_supported  bool     `json:"sleep_supported"`
	Dock             Dock     `json:"dock"`
	Hardware         Hardware `json:"hardware"`
}

type CoreItem struct {
	Name     string `json:"name"`
	Id       int    `json:"id"`
	Filename string `json:"filename"`
}

type Variant struct {
	Magic        string   `json:"magic"`
	Variant_list []string `json:"variant_list"`
}

type CoreMetadata struct {
	Audio Audio `json:"audio"`
	Data  Data  `json:"data"`
	// The Pocket requires empty "input" and
	// "interact" keys in the metadata so
	// the individual per-asset ones are parsed
	// correctly. Empty means the full skeleton
	// with all the keys, but no values except
	// for magic
	Input    InputMap `json:"input"`
	Interact Interact `json:"interact"`
	Video    Video    `json:"video"`
	Core     Core     `json:"core"`
	Variants Variant  `json:"variants"`
	Updaters struct {
		Filename string `json:"filename"`
	} `json:"license"`
}

type ContMapping struct {
	Id   int    `json:"id"`
	Name string `json:"name"`
	Key  string `json:"key"`
}

type Controller struct {
	Type     string        `json:"type"`
	Mappings []ContMapping `json:"mappings"`
}

type InputMap struct {
	Magic       string       `json:"magic"`
	Controllers []Controller `json:"controllers"`
	desc        string
	clone		bool
}

type InstSlot struct {
	Id       int    `json:"id"`
	Filename string `json:"filename"`
	Md5	 	string	`json:"md5,omitempty"`
}

type VariantSelect struct {
	Id     int  `json:"id"`
	Select bool `json:"select"`
}

type MemWrite struct {
	Address string `json:"address"`
	Data    string `json:"data"`
}

type CoreInstance struct {
	Magic          string        `json:"magic"`
	Variant_select VariantSelect `json:"variant_select"`
	Data_path      string        `json:"data_path"`
	Data_slots     []InstSlot    `json:"data_slots"`
	Memory_writes  []MemWrite    `json:"memory_writes"`
}

type CoreInstMeta struct {
	name, desc string
	clone	   bool
	inst       CoreInstance
}

type Platform struct {
	Category     string `json:"category"`
	Name         string `json:"name"`
	Year         int    `json:"year"`
	Manufacturer string `json:"manufacturer"`
}

var pck_instances []CoreInstMeta
var pck_interacts []Interact
var pck_mappers []InputMap

func make_dir(dir string, delete_first bool) {
	if dir != "." && dir != "" {
		if delete_first {
			if Verbose {
				fmt.Println("First delete the path ", dir)
			}
			if e := os.RemoveAll(dir); e != nil {
				fmt.Println("Couldn't delete path ", dir, "\n\t", e)
			}
		}
		if Verbose {
			fmt.Println("Creating path ", dir)
		}
		err := os.MkdirAll(dir, 0777)
		if err != nil && !os.IsExist(err) {
			log.Fatal("(pocket.go) Error while creating Pocket folders:\n", err)
		}
	}
}

func copy_image(dst, src string) {
	src = filepath.Join(os.Getenv("JTFRAME"), "target", "pocket", "images", src)
	input, err := ioutil.ReadFile(src)
	if err != nil {
		fmt.Println(err, "\n\twhile reading ", src)
		return
	}

	err = ioutil.WriteFile(dst, input, 0644)
	if err != nil {
		fmt.Println(err, "\n\twhile creating ", dst)
		return
	}
}

func set_display_modes(cfg Mame2MRA, video *Video) {
	video.Display_modes = make([]Display_mode,0,8)
	for _,each := range cfg.Pocket.Display_modes {
		video.Display_modes = append(video.Display_modes,
			Display_mode{ Id: fmt.Sprintf("0x%02x",each) })
	}
	for _, each := range []Display_mode{
			{ Id: "0x10" },
			{ Id: "0x20" },
			{ Id: "0x30" },
			{ Id: "0x40" },
			{ Id: "0xE0" },
			{ Id: "0xE1" },} {
		video.Display_modes=append(video.Display_modes,each)
	}
}

func pocket_init(cfg Mame2MRA, args Args) {
	platform_type = "Arcade"
	platform_name = cfg.Global.Platform
	MakeMetaData(&meta, cfg.ROM.Carts, cfg.ROM.Firmware, args, betas.IsBetaFor(cfg.rbf[2:],"pocket"), cfg.Global.Author[0])
	// Create the output directory
	full_name := "jotego." + platform_name
	meta.Core.Metadata.Shortname = platform_name
	meta.Core.Metadata.Url = args.URL
	meta.Core.Metadata.Version = macros.Get("JTFRAME_COMMIT")
	meta.Core.Metadata.Platform_ids[0] = platform_name
	// Scaler video modes
	// 0 = no rotation, no clip
	// 1 = 270 rot, 2=90 rot
	// 3 = no rot, -16 clip
	// 4 = 270 rot, 5=90 rot
	// 6 = no rot, -32 clip
	// 7 = 270 rot

	meta.Video.Scaler_modes[0].Width    = macros.GetInt("JTFRAME_WIDTH")
	meta.Video.Scaler_modes[0].Height   = macros.GetInt("JTFRAME_HEIGHT")
	meta.Video.Scaler_modes[0].Aspect_w = macros.GetInt("JTFRAME_ARX")
	meta.Video.Scaler_modes[0].Aspect_h = macros.GetInt("JTFRAME_ARY")
	for k:=1;k<8;k++ { meta.Video.Scaler_modes = append(meta.Video.Scaler_modes, meta.Video.Scaler_modes[0]) }
	meta.Video.Scaler_modes[1].Rotation = 270
	meta.Video.Scaler_modes[2].Rotation = 90
	meta.Video.Scaler_modes[3].Width  -= 16
	meta.Video.Scaler_modes[4].Height -= 16
	meta.Video.Scaler_modes[5].Height -= 16
	meta.Video.Scaler_modes[4].Rotation = 270
	meta.Video.Scaler_modes[5].Rotation = 90
	meta.Video.Scaler_modes[7].Rotation = 270
	meta.Video.Scaler_modes[6].Width  -= 32
	meta.Video.Scaler_modes[7].Height -= 32
	set_display_modes(cfg, &meta.Video)
	// Prepare Pocket folders
	pck_dir.root = args.pocketdir
	pck_dir.cores = filepath.Join(args.pocketdir, "Cores", full_name)
	pck_dir.common = filepath.Join(args.pocketdir, "Assets", platform_name, "common")
	pck_dir.assets = filepath.Join(args.pocketdir, "Assets", platform_name, full_name)
	pck_dir.presets = filepath.Join(args.pocketdir, "Presets", full_name,
		"Interact", platform_name, full_name)
	pck_dir.inputs = filepath.Join(args.pocketdir, "Presets", full_name,
		"Input", platform_name, full_name)
	pck_dir.platform = filepath.Join(args.pocketdir, "Platforms")
	pck_dir.saves = filepath.Join(args.pocketdir, "Saves", platform_name, "common")
	make_dir(pck_dir.cores, false)
	make_dir(pck_dir.common, true)
	make_dir(pck_dir.assets, true)
	make_dir(pck_dir.platform, false)
	make_dir(pck_dir.presets, true)
	make_dir(pck_dir.inputs, true)
	ioutil.WriteFile(filepath.Join(pck_dir.common, "LICENSE"),
		[]byte(`
FPGA arcade hardware by JOTEGO
This work is licensed to be used with software legally owned
by the final user.

This work is not mantained or supported by Analogue

Third party arcade games may be compatible with this work
provided the game owner does some transformation from
the ROM chips in the PCB to a file compatible with this work.

Third party arcade games released as software for home
game consoles may be compatible with this work, provided
the software owner does some transformation from the software
files to a file compatible with this work. This transformation
should be allowed by the third party software EULA.

This work can be used with a file obtained in a method described
above only if that method is legal in the end user's country.

Third party software may be developed to run on this work. The
software developer will set the software license for that case.
If the software is distributed with this work, then the software
needs to comply with the GPL v3 license.

JOTEGO does not endorse or participate in illegal distribution
of copyrighted material. This work can be used with compatible
software. This software can be homebrew projects or legally
obtained memory dumps of compatible games.

Please support this development
Patreon: https://patreon.com/jotego
`), 0644)
	// Copy images
	images := filepath.Join(args.pocketdir, "Platforms", "_images")
	make_dir(images, false)
	copy_image(filepath.Join(images, platform_name+".bin"), "jt-white.bin")
	copy_image(filepath.Join(pck_dir.cores, "icon.bin"), "jt-icon.bin")
}

func pocket_def_dipsw(mra_dips string) string {
	tokens := strings.Split(mra_dips, ",")
	return strings.Join(tokens, "")
}

func pocket_dip_interact(machine *MachineXML, cfg Mame2MRA, def_dipsw int, dipcnt *int, i *Interact )  {
	maxdip := DIP_LIMIT
	if machine.Display.Rotate!=0 { maxdip-- } // vertical games use one more option to choose the screen orientation
	pocket_mame_dips ( machine,cfg,dipcnt,maxdip,i )
	pocket_extra_dips( machine,cfg,def_dipsw,dipcnt,maxdip,i )
}

// convert DIP definitions to the interact JSON format
func pocket_mame_dips(machine *MachineXML, cfg Mame2MRA, dipcnt *int, maxdip int, i *Interact) {
diploop:
	for _, each := range machine.Dipswitch {
        for _, delcfg := range cfg.Dipsw.Delete {
            if delcfg.Match(machine)>0 {
                for _, name := range delcfg.Names {
                    if match,_ := filepath.Match(strings.ToLower(name),strings.ToLower(each.Name)); match {
                    	if Verbose { fmt.Printf("Pocket: DIP sw '%s' skipped\n", each.Name) }
                    	continue diploop
                    }
            	}
            }
        }
		if Verbose {fmt.Printf("\t%-16s %02d:%02d -> 0x%06x\n", each.Name, each.msb, each.lsb, each.full_mask )}
		tr := func( v int ) int {
			return v<<each.offset
		}
		if each.Condition.Tag != "" && each.Condition.Value == 0 {
			if Verbose {
				fmt.Printf("Skipping DIP setting %s on Pocket because it is conditional\n", each.Name)
			}
			continue diploop // This switch depends on others, skip it
		}
		o := OSDVariable{
			Name:    each.Name,
			Id:      *dipcnt,
			Type:    "list",
			Enabled: true,
			Persist: true,
			Address: "0xfa000000",
			Mask:    fmt.Sprintf("0x%X", uint(^each.full_mask)&0xffffffff),
			Options: []NameValue{},
		}
		if len(each.Dipvalue) == 2 &&
			((each.Dipvalue[0].Name == "Off" && each.Dipvalue[1].Name == "On") ||
				(each.Dipvalue[1].Name == "Off" && each.Dipvalue[0].Name == "On") ||
				(each.Dipvalue[0].Name == "Yes" && each.Dipvalue[1].Name == "No") ||
				(each.Dipvalue[0].Name == "No" && each.Dipvalue[1].Name == "Yes")) {
			o.Type = "check"
			o.Options = nil
			if each.Dipvalue[0].Name == "Off" || each.Dipvalue[0].Name == "No" {
				o.ValueOff = tr(each.Dipvalue[0].Value)
				o.Value = tr(each.Dipvalue[1].Value)
				if each.Dipvalue[0].Default == "yes" {
					o.Defaultval = 0
				} else {
					o.Defaultval = 1
				}
			} else {
				o.ValueOff = tr(each.Dipvalue[1].Value)
				o.Value = tr(each.Dipvalue[0].Value)
				if each.Dipvalue[0].Default == "yes" {
					o.Defaultval = 1
				} else {
					o.Defaultval = 0
				}
			}
		} else {
			for cnt, andeach := range each.Dipvalue {
				v := NameValue{
					Name:  andeach.Name,
					Value: fmt.Sprintf("0x%X", tr(andeach.Value)),
				}
				if andeach.Default == "yes" {
					o.Defaultval = cnt
				}
				o.Options = append(o.Options, v)
			}
		}
		if *dipcnt < maxdip { // Hard limit of 16 items in total, minus 2 pre-used values
			i.Variables = append(i.Variables, o)
		} else {
			fmt.Printf("Pocket: skipping DIP switch %s (in %s). Not enough room in JSON\n", each.Name, machine.Name )
		}
		*dipcnt++
	}
}

func pocket_extra_dips( machine *MachineXML, cfg Mame2MRA, def_dipsw int, dipcnt *int, maxdip int, i *Interact) {
	for _, each := range cfg.Dipsw.Extra {
		if each.Match(machine)==0 { continue }
		o := OSDVariable{
			Name:    each.Name,
			Id:      *dipcnt,
			Type:    "list",
			Enabled: true,
			Persist: true,
			Address: "0xfa000000",
			Mask:    fmt.Sprintf("0x%X",dip_mask(each.Bits)),
			Options: []NameValue{},
		}
		lwr := strings.ToLower(each.Options)
		bit0,_ := strconv.ParseInt( strings.Split(each.Bits,",")[0], 10, 64 )
		tr := func( v int ) int {
			return v<<bit0
		}
		if lwr=="off,on" || lwr=="on,off" {
			// the on/off case is not taking the default value from
			// the MRA definition. We may need to change this
			o.Type = "check"
			o.Options = nil
			if lwr=="off,on" {
				o.ValueOff   = tr(0)
				o.Value      = tr(1)
				o.Defaultval = 0
			} else {
				o.ValueOff   = tr(1)
				o.Value      = tr(0)
				o.Defaultval = 1
			}
		} else {
			for cnt, opt := range strings.Split(each.Options,",") {
				v := NameValue{
					Name:  opt,
					Value: fmt.Sprintf("0x%X", tr(cnt)),
				}
				o.Options = append(o.Options, v)
			}
			// Default value taken from MRA
			o.Defaultval = (def_dipsw&^dip_mask(each.Bits))>>bit0
		}
		if *dipcnt < maxdip { // Hard limit of 16 items in total, minus 2 pre-used values
			i.Variables = append(i.Variables, o)
		} else {
			fmt.Printf("Pocket: skipping DIP switch %s (in %s). Not enough room in JSON\n", each.Name, machine.Name )
		}
		*dipcnt++
	}
}

func pocket_pico( data []byte ) {
	fname := filepath.Join(os.Getenv("JTROOT"),"release","pocket","raw","Assets","jtpatreon","common")
	os.MkdirAll(fname,0775)
	fname = filepath.Join( fname, "cheat.bin" )
	f, _ := os.Create( fname )
	f.Write( data )
	f.Close()
}

func pocket_clear() {
	// forgets about the previously done core
	pck_instances = make([]CoreInstMeta,0)
	pck_interacts = make([]Interact,0)
	pck_mappers   = make([]InputMap,0)
}

func pocket_add(machine *MachineXML, cfg Mame2MRA, args Args, def_dipsw string, coremod int, mra *XMLNode) {
	meta.Core.Cores[0].Name = cfg.rbf
	meta.Core.Cores[0].Filename = strings.ToLower(cfg.rbf) + ".rbf_r"
	// Do not require input files for cores with no ROM set associated
	if mra.GetNode("rom").GetAttr("zip")=="" {
		meta.Data.Data_slots[0].Required=false
		meta.Data.Data_slots[0].Extensions=[]string{"bin"} // this will hide it from the options menu
		meta.Data.Data_slots[1].Required=false
	}
	// New instance
	if pck_instances == nil {
		pck_instances = make([]CoreInstMeta, 0)
	}
	inst_meta := CoreInstMeta{
		name: machine.Name,
		desc: machine.Description,
		clone: machine.Cloneof!="" && !slices.Contains(cfg.Parse.Main_setnames,machine.Name),
		inst: CoreInstance{
			Magic: APF_Version,
			Variant_select: VariantSelect{
				Id:     0,
				Select: false,
			},
			Data_slots: []InstSlot{
				{
					Id:       1,
					Filename: machine.Name + ".rom",
					Md5:	  find_md5(mra, "0"),
				},
			},
			Memory_writes: []MemWrite{
				{ // this the MOD byte
					// Plus the Pocket goes crazy if there is no write in an instance.json
					Address: "0xf9000000",
					Data:    fmt.Sprintf("0x%X", coremod),
				},
				pocket_button_map(machine, cfg),
				// Default DIP switches cannot go in here, as they get
				// overwritten by the JSON instance file
			},
		},
	}
	if macros.IsInt("JTFRAME_IOCTL_RD") {
		inst_meta.inst.Data_slots = append( inst_meta.inst.Data_slots, InstSlot{
			Id: 2,
			Filename: machine.Name + ".sav",
		})
	}
	if betas.IsBetaFor( cfg.rbf[2:], "pocket" ) {
		inst_meta.inst.Data_slots = append( inst_meta.inst.Data_slots, InstSlot{
			Id: 17,
			Filename: "beta.bin",
			Md5:	  betas.Md5sum,
		})
	}
	pck_instances = append(pck_instances, inst_meta )
	// New interact
	pck_interacts = append(pck_interacts, pocket_parse_dips(machine, cfg, def_dipsw, inst_meta.clone, coremod))
	// New controller
	pck_mappers = append(pck_mappers, pocket_parse_inputs(machine, cfg))
	pocket_nvram(machine, cfg, args.Core)
}

// Creates a .nvm file if there are default values for the NVRAM
func pocket_nvram(machine *MachineXML, cfg Mame2MRA, corename string) {
	if cfg.ROM.Nvram.length == 0 { return }
	save := func( data []byte ) {
		os.MkdirAll(pck_dir.saves,0775)
		fname := filepath.Join(pck_dir.saves,machine.Name+".sav")
		common.Must(os.WriteFile(fname, data,0664))
	}
	// Is there a .nvm file in the cfg folder matching the machine name?
	if rawbytes, e := nvram_file(machine, corename ); e== nil {
		if len(rawbytes)!=0 { save(rawbytes) }
		return
	}
	// Are there explicit default data in the TOML?
	if cfg.ROM.Nvram.Match(machine)==0 { return }
	for _, each := range cfg.ROM.Nvram.Defaults {
		if each.Match(machine)==0 || each.Data=="" { continue }
		save(rawdata2bytes(each.Data))
	}
}

func pocket_parse_dips(machine *MachineXML, cfg Mame2MRA, def_dipsw string, clone bool, coremod int) (i Interact) {
	i = Interact{
		setname: machine.Name,
		desc:    machine.Description,
		clone:   clone,
		Magic:   APF_Version,
		Variables: make([]OSDVariable,0,16),
		Messages: []string{},
	}
	dipcnt := 0
	if machine.Display.Rotate != 0 {
		o := OSDVariable{
			Name:       "Rotate screen",
			Id:         dipcnt,
			Type:       "check",
			Enabled:    true,
			Persist:    true,
			Address:    "0xfb000000",
			Mask:       fmt.Sprintf("0x%X", ^(uint32(1) << 2)), // bit defined in $JTFRAME/doc/osd.md
			Defaultval: 4,
			Value:      4,
		}
		i.Variables = append(i.Variables, o)
		dipcnt++
	}
	if macros.IsSet("JTFRAME_JOY1_POS") {
		o := OSDVariable{
			Name:       "Player 1 is",
			Id:         dipcnt,
			Type:       "list",
			Enabled:    true,
			Persist:    true,
			Address:    "0xfb000000",
			Mask:       fmt.Sprintf("0x%X", ^(uint32(3) << 18)), // bit defined in $JTFRAME/doc/osd.md
			Defaultval: 0,
			Options: []NameValue{
				{Name: "First",  Value: "0x00000"},
				{Name: "Second", Value: "0x40000"},
				{Name: "Third",  Value: "0x80000"},
				{Name: "Fourth", Value: "0xC0000"},
			},
		}
		i.Variables = append(i.Variables, o)
		dipcnt++
	}
	if macros.IsSet("JTFRAME_OSD_VOL") {
		o := OSDVariable{
			Name:       "FX Volume",
			Id:         dipcnt,
			Type:       "list",
			Enabled:    true,
			Persist:    true,
			Address:    "0xfb000000",
			Mask:       fmt.Sprintf("0x%X", ^(uint32(3) << 6)), // bit defined in $JTFRAME/doc/osd.md
			Defaultval: 0,
			Options: []NameValue{
				{Name: "high", Value: "0x00"},
				{Name: "very high", Value: "0x40"},
				{Name: "very low", Value: "0x80"},
				{Name: "low", Value: "0xc0"},
			},
		}
		i.Variables = append(i.Variables, o)
		dipcnt++
	}
	if macros.IsSet("JTFRAME_DIAL") && machine.Dial() {
		o := OSDVariable{
			Name:       "Dial sensitivity",
			Id:         dipcnt,
			Type:       "list",
			Enabled:    true,
			Persist:    true,
			Address:    "0xfb000004",
			Mask:       fmt.Sprintf("0x%X", ^uint32(3)), // bit defined in $JTFRAME/doc/osd.md
			Defaultval: 3,
			Options: []NameValue{
				{Name: "very high", Value: "0x1"}, // see jtframe_dial
				{Name: "high",      Value: "0x0"},
				{Name: "low",       Value: "0x3"},
				{Name: "very low",  Value: "0x2"},
			},
		}
		i.Variables = append(i.Variables, o)
		dipcnt++
	}
	if macros.IsSet("JTFRAME_LIGHTGUN") && ((coremod&0x2)!=0) {
		o := OSDVariable{
			Name:       "Lightgun sensitivity",
			Id:         dipcnt,
			Type:       "list",
			Enabled:    true,
			Persist:    true,
			Address:    "0xfb000004",
			Mask:       fmt.Sprintf("0x%X", ^uint32(3)), // bit defined in $JTFRAME/doc/osd.md
			Defaultval: 3,
			Options: []NameValue{
				{Name: "very high", Value: "0x1"}, // see jtframe_lightgun_joyemu
				{Name: "high",      Value: "0x0"},
				{Name: "low",       Value: "0x3"},
				{Name: "very low",  Value: "0x2"},
			},
		}
		i.Variables = append(i.Variables, o)
		dipcnt++
	}
	if len(machine.Dipswitch) == 0 && len(cfg.Dipsw.Extra)==0 {
		return i
	}

	def_int, _ := strconv.ParseInt(pocket_def_dipsw(def_dipsw), 16, 32)
	pocket_dip_interact( machine, cfg, int(def_int),  &dipcnt, &i )
	i.Variables = append(i.Variables, OSDVariable{
		Name:       "Default",
		Id:         1015,
		Type:       "number_u32",
		Enabled:    false,
		Persist:    false,
		Address:    "0xfa000000",
		Writeonly:  true,
		Defaultval: int(def_int),
	})
	return i
}

func pocket_button_map(machine *MachineXML, cfg Mame2MRA) MemWrite {
	value := 0x543210 // Identity mapping, also clears the previous game's map.
	selected := cfg.select_buttons(machine)
	if selected != nil && selected.Map != "" {
		value = 0xffffff
		names := strings.Split(selected.Names, ",")
		for k, key := range selected.Map {
			if k >= cfg.Buttons.Core { break }
			if strings.TrimSpace(names[k]) == "-" { continue }
			index := strings.IndexRune("ABXYLR", key)
			value = (value & ^(15 << (4*k))) | (index << (4*k))
		}
	}
	return MemWrite{Address: "0xfc000000", Data: fmt.Sprintf("0x%06X", value)}
}

func pocket_parse_inputs(machine *MachineXML, cfg Mame2MRA) (i InputMap) {
	selected := cfg.select_buttons(machine)
	buttons, button_map := "", ""
	if selected != nil { buttons, button_map = selected.Names, selected.Map }
	if buttons == "" && len(machine.Input.Control) > 0 {
		// No button information in the toml file, get it from MAME
		for k := 0; k < machine.Input.Control[0].Buttons; k++ {
			if k != 0 {
				buttons = buttons + ","
			}
			buttons = fmt.Sprintf("%sbutton %d", buttons, k)
		}
	}
	var mappers []ContMapping
	keys := []string{
		"pad_btn_a",
		"pad_btn_b",
		"pad_btn_x",
		"pad_btn_y",
		"pad_trig_l",
		"pad_trig_r",
	}
	for k, each := range strings.Split(buttons, ",") {
		key := keys[k]
		if button_map != "" {
			if k >= cfg.Buttons.Core { break }
			if strings.TrimSpace(each) == "-" { continue }
			key = keys[strings.IndexByte("ABXYLR", button_map[k])]
		}
		mappers = append(mappers, ContMapping{
			Id:   k,
			Name: each,
			Key:  key,
		})
		if k == len(keys)-1 {
			break
		}
	}
	i = InputMap{
		Magic: APF_Version,
		Controllers: []Controller{
			{
				Type:     "default",
				Mappings: mappers,
			},
		},
		desc: machine.Description,
	}
	i.clone = machine.Cloneof!="" && !slices.Contains(cfg.Parse.Main_setnames,machine.Name)
	return i
}

func pocket_save() {
	meta.SavePocket()
}

func MakeMetaData(meta *CoreMetadata, carts []string, firmware string, args Args, beta bool, author string) {
	now := time.Now()
	if beta {
		meta.Updaters.Filename="beta.bin"
	} else {
		meta.Updaters.Filename=""
	}
	meta.Core.Magic = APF_Version
	meta.Core.Metadata.Author = "jotego" // strings.ToLower(author) -- not a satisfying solution but needed to make the Pocket read the files correctly
	meta.Core.Metadata.Description = platform_type
	meta.Core.Metadata.Url = args.URL
	meta.Core.Metadata.Date_release = fmt.Sprintf("%04d-%02d-%02d", now.Year(), now.Month(), now.Day())
	meta.Core.Metadata.Platform_ids = []string{ "", "jtpatreon" }
	meta.Core.Cores = make([]CoreItem, 1)
	meta.Core.Cores[0].Name = "jtcore"
	meta.Core.Cores[0].Id = 0
	meta.Core.Cores[0].Filename = "jtcore.rbf_r" // This will be replaced later

	meta.Core.Framework.Target_product = "Analogue Pocket"
	meta.Core.Framework.Version_required = "1.1"
	meta.Core.Framework.Dock.Supported = true
	meta.Core.Framework.Hardware.Cartridge_adapter = 0
	meta.Audio.Magic = APF_Version
	meta.Input = InputMap{
		Magic: APF_Version,
		Controllers: []Controller{
			{
				Type:     "default",
				Mappings: []ContMapping{},
			},
		},
	}
	meta.Interact = Interact{
		Magic:     APF_Version,
		Variables: []OSDVariable{},
	}
	meta.Data.Magic = APF_Version
	meta.Data.Data_slots = []Data_slots{
		{
			Name:       "Arcade Game",
			Id:         0,
			Required:   true,
			Parameters: "0x113",
			Extensions: []string{"json"},
		},
		{
			Name:       "ROM",
			Id:         1,
			Required:   true,
			Parameters: "0x108", // read only
			Extensions: []string{"rom"},
			Address:    "0x00000000",
		},
		{
			Name:       "NVRAM",
			Id:         2,
			Required:   false,
			Nonvolatile: true,
			Parameters: "0x100", // reset after a load
			Extensions: []string{"sav"},
			Address:    "0x00000000",
		},
		{
			Name:       "CRT config",
			Id:         18,
			Required:   false,
			Filename:   "crtcfg.bin",
			Parameters: "0x1000000",	// use jtpatreon platform
			Extensions: []string{"bin"},
			Address:    "0x00000000",
		},
	}
	if macros.GetInt("JTFRAME_CART_OFFSET")!=0 || len(carts)!=0 {
		platform_type="Handheld"
		meta.Core.Metadata.Description = platform_type
		meta.Data.Data_slots[0]=Data_slots{
			Name:	"Cartridge",
			Id:		4,
			Parameters: "0x09", // OSD load, read only
			Extensions: carts,
			Required: true,
			Address:    "0x00000000",
		}
		meta.Data.Data_slots[1]=Data_slots{
			Name:	"firmware",
			Id:		1,
			Required: true,
			Parameters: "0x108", // read only, reset after load
			Extensions: []string{"rom","bin"},
			Filename:   firmware,
			Address:    "0x00000000",
		}
	}
	if beta {
		meta.Data.Data_slots = append(meta.Data.Data_slots, Data_slots{
			Name:       "JTBETA",
			Id:         17,
			Required:   false,
			Filename:   "beta.bin",
			Parameters: "0x1000000",	// use jtpatreon platform
			Extensions: []string{"bin"},
			Address:    "0x00000000",
		})
	}
	meta.Video = Video{
		Magic: APF_Version,
		Scaler_modes: []Scaler_modes{
			{   Width: 	  256,
				Height:   240,
				Aspect_w: 4,
				Aspect_h: 3},
		},
	}
	meta.Variants = Variant{
		Magic:        APF_Version,
		Variant_list: []string{},
	}
}

func saveJSON(filename, topname string, data []byte) {
	if len(topname) > 0 {
		buf := bytes.NewBufferString("{\n\t" + `"` + topname + `"` + ":")
		buf.Write(data)
		buf.WriteString("\n}")
		ioutil.WriteFile(filename, buf.Bytes(), 0644)
	} else {
		ioutil.WriteFile(filename, data, 0644)
	}
}

func json_name(raw string) string {
	goodname := strings.Replace(raw, "?", "", -1)
	goodname = strings.Replace(goodname, ":", "", -1)
	return goodname + ".json"
}

func saveLicense(path string) {
	buf := bytes.NewBufferString(
		`FPGA arcade hardware by JOTEGO
This work is licensed to be used with software legally owned
by the final user.

This work is not mantained or supported by Analogue

Third party arcade games may be compatible with this work
provided the game owner does some transformation from
the ROM chips in the PCB to a file compatible with this work.

Third party arcade games released as software for home
game consoles may be compatible with this work, provided
the software owner does some transformation from the software
files to a file compatible with this work. This transformation
should be allowed by the third party software EULA.

This work can be used with a file obtained in a method described
above only if that method is legal in the end user's country.

Third party software may be developed to run on this work. The
software developer will set the software license for that case.
If the software is distributed with this work, then the software
needs to comply with the GPL v3 license.

JOTEGO does not endorse or participate in illegal distribution
of copyrighted material. This work can be used with compatible
software. This software can be homebrew projects or legally
obtained memory dumps of compatible games.

Please support this development
Patreon: https://patreon.com/jotego
`)
	ioutil.WriteFile(filepath.Join(path, "LICENSE"), buf.Bytes(), 0644)
}

func (meta *CoreMetadata) SavePocket() {
	var bytestream []byte

	// File that defines the platform
	bytestream, _ = json.MarshalIndent(
		Platform{
			Category:     platform_type,
			Name:         platform_name,
			Manufacturer: "JT FPGA",
			Year:         time.Now().Year(),
		},
		"\t", "\t")
	saveJSON(filepath.Join(pck_dir.platform, platform_name+".json"), "platform", bytestream)
	// Files that define the core
	bytestream, _ = json.MarshalIndent(meta.Core, "\t", "\t")
	saveJSON(filepath.Join(pck_dir.cores, "core.json"), "core", bytestream)
	if meta.Updaters.Filename!="" { // list beta.bin for cores in beta phase
		bytestream, _ = json.MarshalIndent(meta.Updaters, "\t", "\t")
		saveJSON(filepath.Join(pck_dir.cores, "updaters.json"), "license", bytestream)
	}

	bytestream, _ = json.MarshalIndent(meta.Audio, "\t", "\t")
	saveJSON(filepath.Join(pck_dir.cores, "audio.json"), "audio", bytestream)

	bytestream, _ = json.MarshalIndent(meta.Data, "\t", "\t")
	saveJSON(filepath.Join(pck_dir.cores, "data.json"), "data", bytestream)

	bytestream, _ = json.MarshalIndent(meta.Input, "\t", "\t")
	saveJSON(filepath.Join(pck_dir.cores, "input.json"), "input", bytestream)

	bytestream, _ = json.MarshalIndent(meta.Interact, "\t", "\t")
	saveJSON(filepath.Join(pck_dir.cores, "interact.json"), "interact", bytestream)

	bytestream, _ = json.MarshalIndent(meta.Video, "\t", "\t")
	saveJSON(filepath.Join(pck_dir.cores, "video.json"), "video", bytestream)

	bytestream, _ = json.MarshalIndent(meta.Variants, "\t", "\t")
	saveJSON(filepath.Join(pck_dir.cores, "variants.json"), "variants", bytestream)

	// Files that define each game for the core
	var rom_readme strings.Builder
	rom_readme.WriteString("Place the following files in this folder:\n\n")
	for _, each := range pck_instances {
		bytestream, _ = json.MarshalIndent(each.inst, "\t", "\t")
		dest_folder := pck_dir.assets
		if each.clone {
			dest_folder = filepath.Join(dest_folder, "_alternatives")
			os.MkdirAll(dest_folder, 0777)
		}
		saveJSON(filepath.Join( dest_folder, json_name(each.desc)), "instance", bytestream)
		rom_readme.WriteString(each.inst.Data_slots[0].Filename)
		rom_readme.WriteString("\n")
	}
	rom_readme.WriteString(`
These files are generated using the mra tool in:
https://github.com/sebdel/mra-tools-c/tree/master/release

Check out the short tutorial in:
https://github.com/jotego/jtbin/wiki/Analogue-Pocket-Cores

DISCLAIMER: This PocketFPGA core is licensed to be used only
with legally owned dumps of videogame data. It is also licensed
to be used with freeware (homebrew) compatible with the platform.
`)
	ioutil.WriteFile(filepath.Join(pck_dir.common, "README"), []byte(rom_readme.String()), 0644)

	for _, each := range pck_interacts {
		bytestream, _ = json.MarshalIndent(each, "\t", "\t")
		dest_folder := pck_dir.presets
		if each.clone {
			dest_folder = filepath.Join(dest_folder, "_alternatives")
			os.MkdirAll(dest_folder, 0777)
		}
		saveJSON(filepath.Join(dest_folder, json_name(each.desc)), "interact", bytestream)
	}

	for _, each := range pck_mappers {
		bytestream, _ = json.MarshalIndent(each, "\t", "\t")
		dest_folder := pck_dir.inputs
		if each.clone {
			dest_folder = filepath.Join(dest_folder, "_alternatives")
			os.MkdirAll(dest_folder, 0777)
		}
		saveJSON(filepath.Join(dest_folder, json_name(each.desc)), "input", bytestream)
	}
	// README file
	var file_readme strings.Builder
	file_readme.WriteString(fmt.Sprintf("%s - Arcade compatible hardware for Pocket FPGA\n", platform_name))
	file_readme.WriteString(`Developed by JOTEGO - https://patreon.com/jotego

The following arcade titles are compatible with this core. Generate
the required .rom file using the mra tool (read below).
Place the *.rom files in `)
	file_readme.WriteString("Assets/" + platform_name + "/common\n\n")

	for _, each := range pck_instances {
		file_readme.WriteString(fmt.Sprintf("%s --> %s\n", each.desc, each.inst.Data_slots[0].Filename))
	}
	file_readme.WriteString(`

These files are generated using the mra tool in:
https://github.com/sebdel/mra-tools-c/tree/master/release

Boogermann's ORCA tool can also be used to generate the files:
https://github.com/opengateware/tools-orca

Check out the short tutorial in:
https://github.com/jotego/jtbin/wiki/Analogue-Pocket-Cores

DISCLAIMER: This PocketFPGA core is licensed to be used only
with legally owned dumps of videogame data. It is also licensed
to be used with freeware (homebrew) compatible with the platform.
`)
	ioutil.WriteFile(filepath.Join(pck_dir.root, platform_name+".txt"), []byte(file_readme.String()), 0644)
	//////// Create shell script to copy each ROM file to the right place
	var cp_script strings.Builder
	cp_script.WriteString(`#!/bin/bash
SRC=.
if [ "$1" = "-u" -o "$1" = "--update" ]; then
	CPUPD=-u
	shift
fi
if [ ! -z "$1" ]; then
	SRC="$1"
	if [ ! -d "$SRC" ]; then
		echo "Error: folder $SRC does not exist"
		exit 1
	fi
fi
`)
	for _, each := range pck_instances {
		cp_script.WriteString(fmt.Sprintf("cp $CPUPD $SRC/%s /media/$USER/POCKET/Assets/%s/common\n", each.inst.Data_slots[0].Filename, platform_name))
	}
	cp_fname := fmt.Sprintf("%s/rom/cp_%s.sh", os.Getenv("JTROOT"), platform_name[2:])
	ioutil.WriteFile(cp_fname, []byte(cp_script.String()), 0744)
	// Save a copy of the license file in each folder
	saveLicense(pck_dir.cores)
	saveLicense(pck_dir.common)
	saveLicense(pck_dir.assets)
	saveLicense(pck_dir.presets)
	saveLicense(pck_dir.inputs)
}

func find_md5(mra *XMLNode, index string ) string {
	if mra==nil { return "" }
	n := mra.FindMatch( func( x *XMLNode) bool { return x.GetName()=="rom" && x.GetAttr("index")==index } )
	if n==nil { return "" }
	return n.GetAttr("asm_md5")
}
