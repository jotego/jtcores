    input   [25:0]  ioctl_addr,
    input   [ 7:0]  ioctl_dout,
    input           ioctl_wr,
    input           ioctl_rom,
    `ifdef JTFRAME_IOCTL_RD
        input           ioctl_ram,
        output   [ 7:0] ioctl_din,
    `endif
    output          dwnld_busy,
    input   [15:0]  data_read,
    input           ioctl_cart,
    `ifdef JTFRAME_SDRAM_BANKS
        `ifdef JTFRAME_SDRAM_LARGE
            output [22:0]
        `else
            output [21:0]
        `endif
            ba0_addr, ba1_addr, ba2_addr, ba3_addr,
        output [ 3:0] ba_rd, ba_wr,
        input  [ 3:0] ba_dst, ba_dok, ba_rdy, ba_ack,
        output [15:0] ba0_din, ba1_din, ba2_din, ba3_din,
        output [ 1:0] ba0_dsn, ba1_dsn, ba2_dsn, ba3_dsn,
        output [15:0]  prog_data,
        input          prog_rdy, prog_ack, prog_dst, prog_dok,
        output [ 1:0]  prog_ba,
    `else
        output        sdram_req,
        output [21:0] sdram_addr,
        input         data_dst,
        input         data_rdy,
        input         sdram_ack,
        output [ 7:0] prog_data,
    `endif
    output          prog_we,
    output          prog_rd,
    output  [ 1:0]  prog_mask,
    `ifdef JTFRAME_SDRAM_LARGE
        output [22:0] `else output [21:0]
    `endif
                    prog_addr   // no comma here, end of port list