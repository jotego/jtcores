`ifdef JTFRAME_SRAM
    output    [16:0]  sram_addr,
    output    [15:0]  sram_din,
    input     [15:0]  sram_dout,
    output            sram_wen,
    output    [ 1:0]  sram_dsn,
    input             sram_ok,
`endif
    input fm_cen, // 7999998 = 57272720*44/315 Hz 
    input snd_cen, // 4999999 = 57272720*11/126 Hz 
    input snd4_cen, // 3999999 = 57272720*22/315 Hz 

    // Audio channels
    output signed [15:0] fm_l,
    output signed [15:0] fm_r,
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
    input   [15:0] lut1_dout,
    input   [15:0] mix_pal,
    output   [1:0] ram_we,
    input   [15:0] scr_vram,
    output   [1:0] oram_we,
    output   [1:0] oram1_we,
    output   [13:1] ram2_addr,
    output   [12:1] vram1_addr,
    output   [1:0] lut1_we,
    output   [15:1] lut1_addr,
    input   [15:0] pal_dout,
    output   [11:1] rascr_addr,
    output   [11:1] ras_addr,
    output   [15:1] lut_addr,
    input   [15:0] objl_dout,
    input   [15:0] objr_dout,
    input   [15:0] oram1_dout,
    input   [15:0] objr1_dout,
    input   [15:0] objl1_dout,
    output   [15:1] ram_addr,
    output   [12:1] scr_addr,
    input   [15:0] scr1_vram,
    output   [10:1] oram_addr,
    output   [11:1] mix_addr,
    input   [15:0] vram_dout,
    output   [10:1] objr_addr,
    output   [11:1] pal_addr,
    input   [15:0] oram_dout,
    input   [15:0] lut_dout,
    output   [1:0] pal_we,
    output   [12:1] vram_addr,
    output   [12:1] scr1v_addr,
    input   [15:0] rascr_dout,
    output   [1:0] rascr_we,
    output   [15:0] main_dout,
    input   [15:0] ras_dout,
    output   [15:1] objl1_addr,
    input   [15:0] vram1_dout,
    output   [1:0] vram1_we,
    output   [10:1] oram1_addr,
    output   [10:1] objr1_addr,
    input   [15:0] ram_dout,
    input   [15:0] ram2_dout,
    output   [1:0] ram2_we,
    output   [1:0] vram_we,
    output   [1:0] lut_we,
    output   [15:1] objl_addr,
    // Buses to BRAM

    
    
    
    
    
    
    
    
    
    
    // Buses to SDRAM
    input    [31:0] scr0_data,
    output          scr0_cs,
    output   [19:2] scr0_addr,
    input           scr0_ok,

    input    [15:0] main_data,
    output          main_cs,
    output   [19:1] main_addr,
    input           main_ok,

    input    [ 7:0] snd_data,
    output          snd_cs,
    output   [16:0] snd_addr,
    input           snd_ok,

    input    [31:0] obj1_data,
    output          obj1_cs,
    output   [20:2] obj1_addr,
    input           obj1_ok,

    input    [ 7:0] pcma_data,
    output          pcma_cs,
    output   [19:0] pcma_addr,
    input           pcma_ok,

    input    [31:0] obj0_data,
    output          obj0_cs,
    output   [21:2] obj0_addr,
    input           obj0_ok,

    input    [ 7:0] pcmb_data,
    output          pcmb_cs,
    output   [18:0] pcmb_addr,
    input           pcmb_ok,

    input    [31:0] scr1_data,
    output          scr1_cs,
    output   [20:2] scr1_addr,
    input           scr1_ok
