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

var Verbose bool

type Args struct {
    Core     string
    Target   string
    Verbose  bool
    Local    bool  // Dump to local folder, else dump to target folder
    Make_inc bool
    Nodbg    bool
    // The memory selection (SDRAM, DDR, BRAM...) will be here
}

type path_finder interface {
    get_path( fname string, prefix bool ) string
}

type Bus interface {
    Get_dw() int
    Get_aw() int
    Get_dname() string
    Is_wr() bool
    Is_nbits(n int) bool
}

type SDRAMBus struct {
    // MacroEnabled
    When    []string `yaml:"when"`
    Unless  []string `yaml:"unless"`

    Name       string `yaml:"name"`
    Offset     string `yaml:"offset"`
    Addr       string `yaml:"addr"`
    Addr_width int    `yaml:"addr_width"` // Width for counting all *bytes*
    Data_width int    `yaml:"data_width"`
    Cache_size int    `yaml:"cache_size"`
    Rw         bool   `yaml:"rw"`
    Dont_erase bool   `yaml:"do_not_erase"`
    Dsn        string `yaml:"dsn"`  // optional name for dsn signal
    Din        string `yaml:"din"`  // optional name for din signal
    Cs         string `yaml:"cs"`
    Gfx        string `yaml:"gfx_sort"`
}

type BRAMBus_Ioctl struct {
    // Instantiating MacroEnabled anonymously does not work
    // with the YAML package, so When and Unless are duplicated here
    When    []string `yaml:"when"`
    Unless  []string `yaml:"unless"`
    Save    bool `yaml:"save"`
    Order   int  `yaml:"order"`
    Restore bool `yaml:"restore"`
}

type BRAMBus struct {
    // MacroEnabled
    When    []string `yaml:"when"`
    Unless  []string `yaml:"unless"`

    Name       string `yaml:"name"`
    Addr_width int    `yaml:"addr_width"` // Width for counting all *bytes*
    Data_width int    `yaml:"data_width"`
    Rw         bool   `yaml:"rw"`
    We         string `yaml:"we"`
    Addr       string `yaml:"addr"`
    Din        string `yaml:"din"`  // optional name for din signal
    Dout       string `yaml:"dout"` // optional name for dout signal
    Sim_file   bool   `yaml:"sim_file"`
    Prom       bool   `yaml:"prom"` // program contents after JTFRAME_PROM_START
    Ioctl      BRAMBus_Ioctl `yaml:"ioctl"`
    Dual_port  struct {
        Name string `yaml:"name"`
        Addr string `yaml:"addr"` // may be needed if the RAM is 8 bits, but the dual port comes from a 16-bit address bus, so [...:1] should be added
        Din  string `yaml:"din"`  // optional name for din signal
        Dout string `yaml:"dout"` // optional name for dout signal
        Rw   bool   `yaml:"rw"`
        We   string `yaml:"we"`
        // filled later
        AddrFull string           // contains the bus indexes
    } `yaml:"dual_port"`
    ROM struct { // Use the BRAM as ROM
        Offset string `yaml:"offset"`
    } `yaml:"rom"`
}

type SDRAMBank struct {
    Buses []SDRAMBus `yaml:"buses"`
    // Precalculated values
    MemType string
}

type DownloadCfg struct {
    Pre_addr  bool `yaml:"pre_addr"`  // Pass some signals to the game so it can remap the download address
    Post_addr bool `yaml:"post_addr"` // Pass some signals to the game so it can remap the download address
    Post_data bool `yaml:"post_data"` // Pass some signals to the game so it can remap the download data
    Noswab    bool `yaml:"noswab"`    // SWAB parameter of jtframe_download
}

type SDRAMCfg struct {
    Banks []SDRAMBank `yaml:"banks"`
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
    Name string `yaml:"name"`
    MSB  int `yaml:"msb"`
    LSB  int `yaml:"lsb"`
    Input bool `yaml:"input"`
}

type ClockCfg struct {
    Div     int      `yaml:"div"`       // only div or freq may be used
    Mul     int      `yaml:"mul"`       // defaults to 1 if missing
    Freq    float64  `yaml:"freq"`
    Outputs []string `yaml:"outputs"`
    Gate    []string `yaml:"gate"`      // SDRAM buses that will halt the clock enable
    // values for jtframe_frac_cen instantiation
    ClkName string
    KHz     int         // clock frequency in kHz
    WC, W   int
    OutStr  string
    Comment string
    Busy    string
}

type IoctlBus struct{ // not a YAML type
    DW, AW, AWl int
    Blocks, SkipBlocks, Size, SizekB int
    Name, Dout, A, Amx, Din, We string
}

type Ioctl struct {
    Dump bool
    DinName string
    SkipAll int
    Buses [6]IoctlBus
}

type AudioRC struct {
    R   string `yaml:"r"`
    C   string `yaml:"c"`
}

type AudioCh struct {
    Name       string `yaml:"name"`
    Module     string `yaml:"module"`
    Rsum       string `yaml:"rsum"`
    Rout       string `yaml:"rout"` // output impedance
    Pre        string `yaml:"pre"`  // pre-amplifier gain
    Vpp        string `yaml:"vpp`   // peak-to-peak voltage range, 1.0=>5V
    RC         []AudioRC `yaml:"rc"`
    Fir        string `yaml:"fir"` // CSV file containing filter coefficients
    DCrm       bool   `yaml:"dcrm"`
    // These two are filled from Module, if the Module is present
    Stereo     bool   `yaml:"stereo"`
    Unsigned   bool   `yaml:"unsigned"`
    Data_width int    `yaml:"data_width"`
    Rc_en      bool   `yaml:"rc_en"`
    // Derived from RC information
    Firhex     string   // name for file with FIR filter coefficients in hexadecimal
    Filters    int      // number of RC filters (each one is made of two poles)
    Pole       string
    rcen       string
    Fcut       [2]int
    Gain       string
    gain       float64
    rout       float64
}

type AudioPCB struct{
    Machine     string `yaml:"machine"`
    Machines    string `yaml:"machines"`
    Rfb         string `yaml:"rfb"`     // feedback resistor of final opamp
    Rsums     []string `yaml:"rsums"`   // summing resistor for each channel
    Pres      []float64 `yaml:"pres`    // pre-gains
    // Derived, not in YAML
    Gaincfg     string
}

type Audio struct {
    Mute    bool   `yaml:"mute"`
    RC         AudioRC `yaml:"rc"`
    Rsum    string `yaml:"rsum"`
    Rsum_feedback_res bool `yaml:"rsum_feedback_res"`
    Gain    float64 `yaml:"gain"` // additional global gain
    Channels []AudioCh `yaml:"channels"`
    // Fractional divider information to generate 192kHz clock
    FracW,FracN,FracM int
    PCB []AudioPCB `yaml:"pcb"`
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
    Core     string
    Macros   map[string]string
    Clocks   map[string][]ClockCfg `yaml:"clocks"`
    // Precalculated values
    Colormsb int
    Unused   [4]bool // true for unused banks
    // Derived information
    Ioctl    Ioctl
    Gfx8     string
    Gfx16    string
    Gfx8b0, Gfx16b0 int
    Balut,Lutsh int
}

type Optional interface{
    Enabled() bool
}