`ifdef JTFRAME_SRAM
    output    [16:0]  sram_addr,
    output    [15:0]  sram_din,
    input     [15:0]  sram_dout,
    output            sram_wen,
    output    [ 1:0]  sram_dsn,
    input             sram_ok,
`endif
    input cen6, cen12, // 12000000 = 48000000*1/4 Hz 
    input cen2, cen4, // 4000000 = 48000000*1/12 Hz 

    // Audio channels
    
    output signed [15:0] fm,
    output [ 7:0] dac1,
    output [ 7:0] dac2,
    // Memory ports
`ifdef JTFRAME_SDRAM_XL
    input   [23:0]  prog_addr,
`elsif JTFRAME_SDRAM_LARGE
    input   [22:0]  prog_addr,
`else
    input   [21:0]  prog_addr,
`endif
    input   [ 7:0]  prog_data,
    input           prog_we,
    input   [ 1:0]  prog_ba,
`ifdef JTFRAME_SDRAM_XL
    input   [26:0]  ioctl_addr,
`else
    input   [25:0]  ioctl_addr,
`endif
    input           prom_we,
`ifdef JTFRAME_HEADER
    input           header,
`endif
`ifdef JTFRAME_IOCTL_RD
    input           ioctl_wr,
    output   [ 7:0] ioctl_din,
    input    [ 7:0] ioctl_dout, `endif
    input           ioctl_ram,
    input           ioctl_cart,
    // Explicit ports
    input   [7:0] ocpu_dout,
    output   [7:0] objbank_addr,
    input   [3:0] objbank_data,
    input   [3:0] blue_data,
    input   [3:0] objlut_data,
    output    vcwr_we,
    input   [7:0] vattr_dout,
    output    vawr_we,
    input   [7:0] vawr_dout,
    output   [8:0] ocpu_addr,
    output   [13:0] m4rom_addr,
    output    ocpu_we,
    input   [3:0] red_data,
    input   [7:0] vcode_dout,
    output   [9:0] vcwr_addr,
    output   [9:0] vattr_scan,
    output   [8:0] odma_addr,
    input   [7:0] oram_dout,
    output   [7:0] red_addr,
    output   [7:0] green_addr,
    output   [7:0] blue_addr,
    output   [7:0] vcwr_din,
    input   [7:0] m4rom_data,
    input   [7:0] vcwr_dout,
    output   [7:0] ocpu_din,
    input   [3:0] green_data,
    output   [7:0] objlut_addr,
    output   [9:0] vcode_scan,
    output   [9:0] vawr_addr,
    output   [7:0] vawr_din,
    // Buses to BRAM

    
    
    
    
    
    
    
    
    
    // Buses to SDRAM
    input    [ 7:0] main_data,
    output          main_cs,
    output   [16:0] main_addr,
    input           main_ok,

    input    [15:0] bgmap_data,
    output          bgmap_cs,
    output   [14:1] bgmap_addr,
    input           bgmap_ok,

    input    [ 7:0] snd_data,
    output          snd_cs,
    output   [15:0] snd_addr,
    input           snd_ok,

    input    [31:0] char_data,
    output          char_cs,
    output   [14:2] char_addr,
    input           char_ok,

    input    [31:0] scr_data,
    output          scr_cs,
    output   [16:2] scr_addr,
    input           scr_ok,

    input    [31:0] obj_data,
    output          obj_cs,
    output   [16:2] obj_addr,
    input           obj_ok
