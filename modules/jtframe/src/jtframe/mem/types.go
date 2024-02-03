package mem

type Args struct {
    Core     string
    Target   string
    Verbose  bool
    Local    bool  // Dump to local folder, else dump to target folder
    Make_inc bool
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

type Selectable struct {
    Target      string
    Targets   []string
    NoTarget    string
    NoTargets []string
}

type SDRAMBus struct {
    Selectable
    Name       string `yaml:"name"`
    Offset     string `yaml:"offset"`
    Addr       string `yaml:"addr"`
    Addr_width int    `yaml:"addr_width"` // Width for counting all *bytes*
    Data_width int    `yaml:"data_width"`
    Cache_size int    `yaml:"cache_size"`
    Rw         bool   `yaml:"rw"`
    Dsn        string `yaml:"dsn"`  // optional name for dsn signal
    Din        string `yaml:"din"`  // optional name for din signal
    Cs         string `yaml:"cs"`
    Gfx        string `yaml:"gfx_sort"`
}

type BRAMBus struct {
    Selectable
    Name       string `yaml:"name"`
    Addr_width int    `yaml:"addr_width"` // Width for counting all *bytes*
    Data_width int    `yaml:"data_width"`
    Rw         bool   `yaml:"rw"`
    We         string `yaml:"we"`
    Addr       string `yaml:"addr"`
    Din        string `yaml:"din"`  // optional name for din signal
    Dout       string `yaml:"dout"` // optional name for dout signal
    Sim_file   bool   `yaml:"sim_file"`
    Ioctl      struct {
        Save bool `yaml:"save"`
        Order int `yaml:"order"`
        Restore bool `yaml:"restore"`
    } `yaml:"ioctl"`
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
    Region  string
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
    Game string `yaml:"game"` // if not null, it will load from that game folder
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

type MemConfig struct {
    Include  []Include   `yaml:"include"`
    Download DownloadCfg `yaml:"download"`
    SDRAM    SDRAMCfg    `yaml:"sdram"`
    BRAM     []BRAMBus   `yaml:"bram"`
    Params   []Param     `yaml:"params"`
    Ports    []Port      `yaml:"ports"`
    Game     string      `yaml:"game"` // optional: Overrides using Core as the jt<core>_game module
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
    Balut,Lutsh,Lutdw int
}