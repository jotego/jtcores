    // From this line down, do not modify ports manually:
    input   [21:0]  prog_addr,
    input   [ 7:0]  prog_data,
    input           prog_we,
    input   [ 1:0]  prog_ba,
    input   [24:0]  ioctl_addr,
`ifdef JTFRAME_PROM_START
    input           prom_we,
`endif
`ifdef JTFRAME_HEADER
    input           header,
`endif
`ifdef JTFRAME_IOCTL_RD
    input           ioctl_ram,
    output   [ 7:0] ioctl_din,
`endif
    // Explicit ports
    output    gfx_cs,
    // Buses to BRAM
    // Buses to SDRAM
    input    [15:0] xram_data,
    output          xram_cs,
    output   [18:1] xram_addr,
    output          xram_we,
    output   [15:0] xram_din,
    output   [ 1:0] xram_dsn,
    input           xram_ok,

    input    [15:0] main_data,
    output          main_cs,
    output   [18:1] main_addr,
    input           main_ok,

    input    [15:0] map1_data,
    output   [15:1] map1_addr,
    input           map1_ok,

    input    [15:0] map2_data,
    output   [15:1] map2_addr,
    input           map2_ok,

    input    [ 7:0] snd_data,
    output          snd_cs,
    output   [18:0] snd_addr,
    input           snd_ok,

    input    [ 7:0] pcm_data,
    output          pcm_cs,
    output   [16:0] pcm_addr,
    input           pcm_ok,

    input    [31:0] char_data,
    output   [19:2] char_addr,
    input           char_ok,

    input    [31:0] scr1_data,
    output   [19:2] scr1_addr,
    input           scr1_ok,

    input    [31:0] scr2_data,
    output   [19:2] scr2_addr,
    input           scr2_ok,

    input    [15:0] obj_data,
    output          obj_cs,
    output   [20:1] obj_addr,
    input           obj_ok
