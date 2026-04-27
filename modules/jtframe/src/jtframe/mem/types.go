/*  This file is part of JTFRAME.
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
    Date: 4-1-2025 */

package mem

import (
	"fmt"
	"regexp"
	"strconv"
	"strings"
)

var Verbose bool

type Args struct {
	Core     string
	Target   string
	Verbose  bool
	Local    bool // Dump to local folder, else dump to target folder
	Make_inc bool
	Nodbg    bool
	// The memory selection (SDRAM, DDR, BRAM...) will be here
}

type path_finder interface {
	get_path(fname string, prefix bool) string
}

type Bus interface {
	Get_dw() int
	Get_aw() int
	Get_dname() string
	Is_wr() bool
	Is_nbits(n int) bool
}

type BRAMBus struct {
	// MacroEnabled
	When   []string `yaml:"when"`
	Unless []string `yaml:"unless"`

	Name       string        `yaml:"name"`
	Size       interface{}   `yaml:"size"`
	Addr_width int           `yaml:"addr_width"` // Width for counting all *bytes*
	Data_width int           `yaml:"data_width"`
	Rw         bool          `yaml:"rw"`
	We         string        `yaml:"we"`
	Addr       string        `yaml:"addr"`
	Din        string        `yaml:"din"`  // optional name for din signal
	Dout       string        `yaml:"dout"` // optional name for dout signal
	Simfile    BRAMSimfile   `yaml:"simfile"`
	Prom       bool          `yaml:"prom"` // program contents after JTFRAME_PROM_START
	Ioctl      BRAMBus_Ioctl `yaml:"ioctl"`
	Dual_port  struct {
		Name string `yaml:"name"`
		Addr string `yaml:"addr"` // may be needed if the RAM is 8 bits, but the dual port comes from a 16-bit address bus, so [...:1] should be added
		Din  string `yaml:"din"`  // optional name for din signal
		Dout string `yaml:"dout"` // optional name for dout signal
		Rw   bool   `yaml:"rw"`
		We   string `yaml:"we"`
		// filled later
		AddrFull string // contains the bus indexes
	} `yaml:"dual_port"`
	ROM struct { // Use the BRAM as ROM
		Offset string `yaml:"offset"`
	} `yaml:"rom"`
	// Derived information
	PROM_offset int // PROM offset in .rom file
}

func parse_memory_size(size_text string) (int, error) {
	size_text = strings.TrimSpace(size_text)
	if size_text == "" {
		return 0, fmt.Errorf("size cannot be empty")
	}
	parts := regexp.MustCompile(`^(\d+)(?:\s*(B|k|kB|M|MB))?$`).FindStringSubmatch(size_text)
	if parts == nil {
		return 0, fmt.Errorf("size must be an integer number of bytes, or use the exact suffixes B, k, kB, M or MB")
	}
	size_value, err := strconv.Atoi(parts[1])
	if err != nil {
		return 0, fmt.Errorf("size must be an integer number of bytes, or use the exact suffixes B, k, kB, M or MB")
	}
	if size_value <= 0 {
		return 0, fmt.Errorf("size must be greater than zero")
	}
	multiplier := 1
	switch parts[2] {
	case "k", "kB":
		multiplier = 1024
	case "M", "MB":
		multiplier = 1024 * 1024
	}
	return size_value * multiplier, nil
}

type BRAMBus_Ioctl struct {
	// Instantiating MacroEnabled anonymously does not work
	// with the YAML package, so When and Unless are duplicated here
	When    []string `yaml:"when"`
	Unless  []string `yaml:"unless"`
	Save    bool     `yaml:"save"`
	Order   int      `yaml:"order"`
	Restore bool     `yaml:"restore"`
}

type DownloadCfg struct {
	Pre_addr  bool `yaml:"pre_addr"`  // Pass some signals to the game so it can remap the download address
	Post_addr bool `yaml:"post_addr"` // Pass some signals to the game so it can remap the download address
	Post_data bool `yaml:"post_data"` // Pass some signals to the game so it can remap the download data
	Noswab    bool `yaml:"noswab"`    // SWAB parameter of jtframe_download
}

type Include struct {
	Core string `yaml:"core"` // if not null, it will load from that game cfg folder
	File string `yaml:"file"` // if null, mem.yaml will be used
}

type Param struct {
	Name  string `yaml:"name"`
	Value string `yaml:"value"` // if null, the value will be a macro of the same name
	// use "..." if the value starts by ` because of a macro calling
}

type Port struct {
	Name  string `yaml:"name"`
	MSB   int    `yaml:"msb"`
	LSB   int    `yaml:"lsb"`
	Input bool   `yaml:"input"`
}

type ClockCfg struct {
	Div     int      `yaml:"div"` // only div or freq may be used
	Mul     int      `yaml:"mul"` // defaults to 1 if missing
	Freq    string   `yaml:"freq"`
	Outputs []string `yaml:"outputs"`
	Gate    []string `yaml:"gate"` // SDRAM buses that will halt the clock enable
	// values for jtframe_frac_cen instantiation
	ClkName string
	KHz     int // clock frequency in kHz
	WC, W   int
	OutStr  string
	Comment string
	Busy    string
	// private
	ratio float64
	freq  float64
}

type IoctlBus struct { // not a YAML type
	DW, AW, AWl                      int
	Blocks, SkipBlocks, Size, SizekB int
	Name, Dout, A, Amx, Din, We      string
}

type Ioctl struct {
	Dump    bool
	DinName string
	SkipAll int
	Buses   [6]IoctlBus
}

type AudioRC struct {
	R string `yaml:"r"`
	C string `yaml:"c"`
}

type AudioCh struct {
	Name   string    `yaml:"name"`
	Module string    `yaml:"module"`
	Rsum   string    `yaml:"rsum"`
	Rout   string    `yaml:"rout"` // output impedance
	Pre    string    `yaml:"pre"`  // pre-amplifier gain
	Vpp    string    `yaml:"vpp`   // peak-to-peak voltage range, 1.0=>5V
	RC     []AudioRC `yaml:"rc"`
	Fir    string    `yaml:"fir"` // CSV file containing filter coefficients
	DCrm   bool      `yaml:"dcrm"`
	// These two are filled from Module, if the Module is present
	Stereo     bool `yaml:"stereo"`
	Unsigned   bool `yaml:"unsigned"`
	Data_width int  `yaml:"data_width"`
	Rc_en      bool `yaml:"rc_en"`
	// Derived from RC information
	Firhex  string // name for file with FIR filter coefficients in hexadecimal
	Filters int    // number of RC filters (each one is made of two poles)
	Pole    string
	rcen    string
	Fcut    [2]int
	Gain    string
	gain    float64
	rout    float64
}

type AudioPCB struct {
	Machine  string    `yaml:"machine"`
	Machines string    `yaml:"machines"`
	Rfb      string    `yaml:"rfb"`   // feedback resistor of final opamp
	Rsums    []string  `yaml:"rsums"` // summing resistor for each channel
	Pres     []float64 `yaml:"pres`   // pre-gains
	// Derived, not in YAML
	Gaincfg string
}

type Audio struct {
	Mute              bool      `yaml:"mute"`
	RC                AudioRC   `yaml:"rc"`
	Rsum              string    `yaml:"rsum"`
	Rsum_feedback_res bool      `yaml:"rsum_feedback_res"`
	Gain              float64   `yaml:"gain"` // additional global gain
	Channels          []AudioCh `yaml:"channels"`
	// Fractional divider information to generate 192kHz clock
	FracW, FracN, FracM int
	PCB                 []AudioPCB `yaml:"pcb"`
	// Derived information
	GlobalPole string
	GlobalFcut int
	Stereo     bool
}

type MemConfig struct {
	Include  []Include   `yaml:"include"`
	Download DownloadCfg `yaml:"download"`
	SDRAM    SDRAMCfg    `yaml:"sdram"`
	BRAM     []BRAMBus   `yaml:"bram"`
	Params   []Param     `yaml:"params"`
	Ports    []Port      `yaml:"ports"`
	Game     string      `yaml:"game"` // optional: Overrides using Core as the jt<core>_game module
	Audio    Audio       `yaml:"audio"`
	// There will be other memory models supported here
	// Like DDR, BRAM, etc.
	// This part does not go in the YAML file
	// But is acquired from the .def or the Args
	Core   string
	Macros map[string]string
	Clocks map[string][]ClockCfg `yaml:"clocks"`
	// Precalculated values
	Colormsb int
	Unused   [4]bool // true for unused banks
	// Derived information
	Ioctl                 Ioctl
	Gfx4                  string
	Gfx8                  string
	Gfx16, Gfx16b, Gfx16c string
	Gfx8b0, Gfx16b0       int
	Balut, Lutsh          int
}

type SDRAMCfg struct {
	Banks       []SDRAMBank      `yaml:"banks"`
	Burst       string           `yaml:"burst"`
	Big_endian  bool             `yaml:"big_endian"`
	Cache_lanes []SDRAMCacheLine `yaml:"cache-lanes"`
	Burst_len   int
}

type SDRAMBank struct {
	Buses []SDRAMBus `yaml:"buses"`
	// Precalculated values
	MemType string
}

type SDRAMBus struct {
	// MacroEnabled
	When   []string `yaml:"when"`
	Unless []string `yaml:"unless"`

	Name       string          `yaml:"name"`
	Offset     string          `yaml:"offset"`
	Latch      string          `yaml:"latch"`
	Addr       string          `yaml:"addr"`
	Addr_width int             `yaml:"addr_width"` // Width for counting all *bytes*
	Data_width int             `yaml:"data_width"`
	Cache_size int             `yaml:"cache_size"`
	Rw         bool            `yaml:"rw"`
	Dont_erase bool            `yaml:"do_not_erase"`
	Dsn        string          `yaml:"dsn"` // optional name for dsn signal
	Din        string          `yaml:"din"` // optional name for din signal
	Cs         string          `yaml:"cs"`
	Gfx        string          `yaml:"gfx_sort"`
	Gfx_en     string          `yaml:"gfx_sort_en"`
	Simfile    SDRAMBusSimfile `yaml:"simfile"`
}

type SDRAMCacheLine struct {
	When       []string          `yaml:"when"`
	Unless     []string          `yaml:"unless"`
	Name       string            `yaml:"name"`
	Data_width int               `yaml:"data_width"`
	Blocks     SDRAMCacheCfg     `yaml:"blocks"`
	At         SDRAMCacheAddr    `yaml:"at"`
	Rw         bool              `yaml:"rw"`
	Simfile    SDRAMCacheSimfile `yaml:"simfile"`
	Total      int
	Span_bytes int
	Full_range bool
}

type SDRAMCacheCfg struct {
	Count      int    `yaml:"count"`
	Size       string `yaml:"size"`
	Size_bytes int
}

type BRAMSimfile struct {
	Enabled    bool
	Big_endian bool `yaml:"big_endian"`
}

type SDRAMBusSimfile struct {
	Name       string `yaml:"name"`
	Big_endian bool   `yaml:"big_endian"`
	Data_type  string `yaml:"data_type"`
}

type SDRAMCacheSimfile struct {
	Name       string `yaml:"name"`
	Big_endian bool   `yaml:"big_endian"`
	Data_type  string `yaml:"data_type"`
}

type SDRAMCacheAddr struct {
	Bank         int    `yaml:"bank"`
	Offset       string `yaml:"offset"`
	Length       string `yaml:"length"`
	Length_bytes int
	Defined      bool
}

// This function checks the syntax in the mem.yaml file and it applies the
// read values to *line
func (line *SDRAMCacheLine) UnmarshalYAML(unmarshal func(interface{}) error) error {
	type raw_line struct {
		When       []string          `yaml:"when"`
		Unless     []string          `yaml:"unless"`
		Name       string            `yaml:"name"`
		Data_width int               `yaml:"data_width"`
		Blocks     SDRAMCacheCfg     `yaml:"blocks"`
		At         SDRAMCacheAddr    `yaml:"at"`
		Rw         bool              `yaml:"rw"`
		Simfile    SDRAMCacheSimfile `yaml:"simfile"`
	}
	var raw_map map[string]interface{}
	if err := unmarshal(&raw_map); err != nil {
		return err
	}
	var aux raw_line
	if err := unmarshal(&aux); err != nil {
		return err
	}
	line.When = aux.When
	line.Unless = aux.Unless
	line.Name = aux.Name
	line.Data_width = aux.Data_width
	line.Blocks = aux.Blocks
	line.At = aux.At
	line.Rw = aux.Rw
	line.Simfile = aux.Simfile
	for key := range raw_map {
		switch key {
		case "name", "when", "unless", "data_width", "blocks", "at", "rw", "simfile":
		default:
			return fmt.Errorf("Unexpected field %s in cache line", key)
		}
	}
	if line.Name == "" {
		return fmt.Errorf("cache line entries must a name")
	}
	return nil
}

func (bus *BRAMBus) UnmarshalYAML(unmarshal func(interface{}) error) error {
	type raw_bram struct {
		When       []string      `yaml:"when"`
		Unless     []string      `yaml:"unless"`
		Name       string        `yaml:"name"`
		Size       interface{}   `yaml:"size"`
		Addr_width int           `yaml:"addr_width"`
		Data_width int           `yaml:"data_width"`
		Rw         bool          `yaml:"rw"`
		We         string        `yaml:"we"`
		Addr       string        `yaml:"addr"`
		Din        string        `yaml:"din"`
		Dout       string        `yaml:"dout"`
		Simfile    BRAMSimfile   `yaml:"simfile"`
		Prom       bool          `yaml:"prom"`
		Ioctl      BRAMBus_Ioctl `yaml:"ioctl"`
		Dual_port  struct {
			Name     string `yaml:"name"`
			Addr     string `yaml:"addr"`
			Din      string `yaml:"din"`
			Dout     string `yaml:"dout"`
			Rw       bool   `yaml:"rw"`
			We       string `yaml:"we"`
			AddrFull string
		} `yaml:"dual_port"`
		ROM struct {
			Offset string `yaml:"offset"`
		} `yaml:"rom"`
	}
	var raw_map map[string]interface{}
	if err := unmarshal(&raw_map); err != nil {
		return err
	}
	var aux raw_bram
	if err := unmarshal(&aux); err != nil {
		return err
	}
	bus.When = aux.When
	bus.Unless = aux.Unless
	bus.Name = aux.Name
	bus.Size = aux.Size
	bus.Addr_width = aux.Addr_width
	bus.Data_width = aux.Data_width
	bus.Rw = aux.Rw
	bus.We = aux.We
	bus.Addr = aux.Addr
	bus.Din = aux.Din
	bus.Dout = aux.Dout
	bus.Simfile = aux.Simfile
	bus.Prom = aux.Prom
	bus.Ioctl = aux.Ioctl
	bus.Dual_port = aux.Dual_port
	bus.ROM = aux.ROM
	for key := range raw_map {
		switch key {
		case "when", "unless", "name", "size", "addr_width", "data_width", "rw", "we",
			"addr", "din", "dout", "simfile", "prom", "ioctl", "dual_port", "rom":
		default:
			return fmt.Errorf("Unexpected field %s in BRAM bus", key)
		}
	}
	return nil
}

func (bus *SDRAMBus) UnmarshalYAML(unmarshal func(interface{}) error) error {
	type raw_bus struct {
		When       []string        `yaml:"when"`
		Unless     []string        `yaml:"unless"`
		Name       string          `yaml:"name"`
		Offset     string          `yaml:"offset"`
		Latch      string          `yaml:"latch"`
		Addr       string          `yaml:"addr"`
		Addr_width int             `yaml:"addr_width"`
		Data_width int             `yaml:"data_width"`
		Cache_size int             `yaml:"cache_size"`
		Rw         bool            `yaml:"rw"`
		Dont_erase bool            `yaml:"do_not_erase"`
		Dsn        string          `yaml:"dsn"`
		Din        string          `yaml:"din"`
		Cs         string          `yaml:"cs"`
		Gfx        string          `yaml:"gfx_sort"`
		Gfx_en     string          `yaml:"gfx_sort_en"`
		Simfile    SDRAMBusSimfile `yaml:"simfile"`
	}
	var raw_map map[string]interface{}
	if err := unmarshal(&raw_map); err != nil {
		return err
	}
	var aux raw_bus
	if err := unmarshal(&aux); err != nil {
		return err
	}
	bus.When = aux.When
	bus.Unless = aux.Unless
	bus.Name = aux.Name
	bus.Offset = aux.Offset
	bus.Latch = aux.Latch
	bus.Addr = aux.Addr
	bus.Addr_width = aux.Addr_width
	bus.Data_width = aux.Data_width
	bus.Cache_size = aux.Cache_size
	bus.Rw = aux.Rw
	bus.Dont_erase = aux.Dont_erase
	bus.Dsn = aux.Dsn
	bus.Din = aux.Din
	bus.Cs = aux.Cs
	bus.Gfx = aux.Gfx
	bus.Gfx_en = aux.Gfx_en
	bus.Simfile = aux.Simfile
	for key := range raw_map {
		switch key {
		case "when", "unless", "name", "offset", "latch", "addr", "addr_width", "data_width",
			"cache_size", "rw", "do_not_erase", "dsn", "din", "cs", "gfx_sort",
			"gfx_sort_en", "simfile":
		default:
			return fmt.Errorf("Unexpected field %s in SDRAM bus", key)
		}
	}
	return nil
}

func (sim *BRAMSimfile) UnmarshalYAML(unmarshal func(interface{}) error) error {
	type raw_sim struct {
		Big_endian bool `yaml:"big_endian"`
	}
	var raw_map map[string]interface{}
	if err := unmarshal(&raw_map); err != nil {
		return err
	}
	var aux raw_sim
	if err := unmarshal(&aux); err != nil {
		return err
	}
	sim.Enabled = true
	sim.Big_endian = aux.Big_endian
	for key := range raw_map {
		switch key {
		case "big_endian":
		default:
			return fmt.Errorf("Unexpected field %s in BRAM simfile", key)
		}
	}
	return nil
}

func (sim *SDRAMBusSimfile) UnmarshalYAML(unmarshal func(interface{}) error) error {
	type raw_sim struct {
		Name       string `yaml:"name"`
		Big_endian bool   `yaml:"big_endian"`
		Data_type  string `yaml:"data_type"`
	}
	var raw_map map[string]interface{}
	if err := unmarshal(&raw_map); err != nil {
		return err
	}
	var aux raw_sim
	if err := unmarshal(&aux); err != nil {
		return err
	}
	sim.Name = aux.Name
	sim.Big_endian = aux.Big_endian
	sim.Data_type = aux.Data_type
	for key := range raw_map {
		switch key {
		case "name", "big_endian", "data_type":
		default:
			return fmt.Errorf("Unexpected field %s in SDRAM bus simfile", key)
		}
	}
	return nil
}

func (cfg *SDRAMCacheCfg) UnmarshalYAML(unmarshal func(interface{}) error) error {
	type raw_cfg struct {
		Count int    `yaml:"count"`
		Size  string `yaml:"size"`
	}
	var raw_map map[string]interface{}
	if err := unmarshal(&raw_map); err != nil {
		return err
	}
	var aux raw_cfg
	if err := unmarshal(&aux); err != nil {
		return err
	}
	cfg.Count = aux.Count
	cfg.Size = aux.Size
	for key := range raw_map {
		switch key {
		case "count", "size":
		default:
			return fmt.Errorf("Unexpected field %s in cache blocks", key)
		}
	}
	return nil
}

func (sim *SDRAMCacheSimfile) UnmarshalYAML(unmarshal func(interface{}) error) error {
	type raw_sim struct {
		Name       string `yaml:"name"`
		Big_endian bool   `yaml:"big_endian"`
		Data_type  string `yaml:"data_type"`
	}
	var raw_map map[string]interface{}
	if err := unmarshal(&raw_map); err != nil {
		return err
	}
	var aux raw_sim
	if err := unmarshal(&aux); err != nil {
		return err
	}
	sim.Name = aux.Name
	sim.Big_endian = aux.Big_endian
	sim.Data_type = aux.Data_type
	for key := range raw_map {
		switch key {
		case "name", "big_endian", "data_type":
		default:
			return fmt.Errorf("Unexpected field %s in cache simfile", key)
		}
	}
	return nil
}

func (addr *SDRAMCacheAddr) UnmarshalYAML(unmarshal func(interface{}) error) error {
	type raw_addr struct {
		Bank   int    `yaml:"bank"`
		Offset string `yaml:"offset"`
		Length string `yaml:"length"`
	}
	var raw_map map[string]interface{}
	if err := unmarshal(&raw_map); err != nil {
		return err
	}
	var aux raw_addr
	if err := unmarshal(&aux); err != nil {
		return err
	}
	addr.Defined = true
	addr.Bank = aux.Bank
	addr.Offset = aux.Offset
	addr.Length = aux.Length
	for key := range raw_map {
		switch key {
		case "bank", "offset", "length":
		case "start":
			return fmt.Errorf("Unexpected field %s in cache line address; use offset instead", key)
		default:
			return fmt.Errorf("Unexpected field %s in cache line address", key)
		}
	}
	return nil
}

type Optional interface {
	Enabled() bool
}
