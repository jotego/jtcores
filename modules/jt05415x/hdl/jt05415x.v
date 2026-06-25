module jt05415x(
    input             rst,
    input             clk,

    input             cs_156,
    input             cs_157,
    input       [5:1] addr,
    input             rnw,
    input      [15:0] din,
    output     [15:0] dout,
    input       [1:0] dsn,

    // IOCTL dump
    input       [5:0] ioctl_addr,
    output      [7:0] ioctl_156_din,
    output      [7:0] ioctl_157_din,
    // Debug
    input       [7:0] debug_bus,
    output      [7:0] st_156_dout,
    output      [7:0] st_157_dout
);

parameter SIMFILE156 = "rest.bin",
          SIMFILE157 = "rest.bin",
          SEEK156    = 0,
          SEEK157    = 0;
parameter [511:0] INIT156 = 0;
parameter [ 63:0] INIT157 = 0;

wire [15:0] dout_156, dout_157;
wire [ 2:1] addr_157       = addr[2:1];
wire [ 2:0] ioctl_addr_157 = ioctl_addr[2:0];
wire [ 7:0] glob_ctrl, flip_en, attr_ctrl, irq_attr, addr_ctrl, lnscr_ctrl;
wire [ 5:0] vram_ctrl, a_vgrid, b_vgrid, c_vgrid, d_vgrid;
wire [ 5:0] a_hgrid, b_hgrid, c_hgrid, d_hgrid;
wire [10:0] a_scry, b_scry, c_scry, d_scry;
wire [11:0] a_scrx, b_scrx, c_scrx, d_scrx;
wire [ 5:0] lnscr_bank, cpu_bank;
wire [ 7:0] rom_bank, rom_col;
wire [ 1:0] rom_vrc;
wire [15:0] tile_lut;
wire [11:0] hflip_corr;
wire [10:0] vflip_corr;
wire        hofs_phase, clk_fanout, ram_clkph;
wire        a_hofs_flip, b_hofs_flip, c_hofs_flip, d_hofs_flip;
wire        ramout_mux, dbout_mux, vc_dir, crom_decode;
wire        db_lane, col_src0, col_src1;

reg dout_sel_157;

assign dout = dout_sel_157 ? dout_157 : dout_156;

always @(posedge clk) begin
    if( rst ) begin
        dout_sel_157 <= 0;
    end else if( cs_156 | cs_157 ) begin
        dout_sel_157 <= cs_157;
    end
end

jt054156_mmr #(
    .SIMFILE ( SIMFILE156 ),
    .SEEK    ( SEEK156    ),
    .INIT    ( INIT156    )
) u_054156_mmr(
    .rst        ( rst           ),
    .clk        ( clk           ),

    .cs         ( cs_156        ),
    .addr       ( addr          ),
    .rnw        ( rnw           ),
    .din        ( din           ),
    .dout       ( dout_156      ),
    .dsn        ( dsn           ),

    .glob_ctrl  ( glob_ctrl     ),
    .flip_en    ( flip_en       ),
    .attr_ctrl  ( attr_ctrl     ),
    .irq_attr   ( irq_attr      ),
    .addr_ctrl  ( addr_ctrl     ),
    .lnscr_ctrl ( lnscr_ctrl    ),
    .vram_ctrl  ( vram_ctrl     ),
    .a_vgrid    ( a_vgrid       ),
    .b_vgrid    ( b_vgrid       ),
    .c_vgrid    ( c_vgrid       ),
    .d_vgrid    ( d_vgrid       ),
    .a_hgrid    ( a_hgrid       ),
    .b_hgrid    ( b_hgrid       ),
    .c_hgrid    ( c_hgrid       ),
    .d_hgrid    ( d_hgrid       ),
    .a_scry     ( a_scry        ),
    .b_scry     ( b_scry        ),
    .c_scry     ( c_scry        ),
    .d_scry     ( d_scry        ),
    .a_scrx     ( a_scrx        ),
    .b_scrx     ( b_scrx        ),
    .c_scrx     ( c_scrx        ),
    .d_scrx     ( d_scrx        ),
    .lnscr_bank ( lnscr_bank    ),
    .cpu_bank   ( cpu_bank      ),
    .rom_bank   ( rom_bank      ),
    .rom_col    ( rom_col       ),
    .rom_vrc    ( rom_vrc       ),
    .tile_lut   ( tile_lut      ),
    .hflip_corr ( hflip_corr    ),
    .vflip_corr ( vflip_corr    ),

    // IOCTL dump
    .ioctl_addr ( ioctl_addr    ),
    .ioctl_din  ( ioctl_156_din ),
    // Debug
    .debug_bus  ( debug_bus     ),
    .st_dout    ( st_156_dout   )
);

jt054157_mmr #(
    .SIMFILE ( SIMFILE157 ),
    .SEEK    ( SEEK157    ),
    .INIT    ( INIT157    )
) u_054157_mmr(
    .rst         ( rst            ),
    .clk         ( clk            ),

    .cs          ( cs_157         ),
    .addr        ( addr_157       ),
    .rnw         ( rnw            ),
    .din         ( din            ),
    .dout        ( dout_157       ),
    .dsn         ( dsn            ),

    .hofs_phase  ( hofs_phase     ),
    .clk_fanout  ( clk_fanout     ),
    .ram_clkph   ( ram_clkph      ),
    .a_hofs_flip ( a_hofs_flip    ),
    .b_hofs_flip ( b_hofs_flip    ),
    .c_hofs_flip ( c_hofs_flip    ),
    .d_hofs_flip ( d_hofs_flip    ),
    .ramout_mux  ( ramout_mux     ),
    .dbout_mux   ( dbout_mux      ),
    .vc_dir      ( vc_dir         ),
    .crom_decode ( crom_decode    ),
    .db_lane     ( db_lane        ),
    .col_src0    ( col_src0       ),
    .col_src1    ( col_src1       ),

    // IOCTL dump
    .ioctl_addr  ( ioctl_addr_157 ),
    .ioctl_din   ( ioctl_157_din  ),
    // Debug
    .debug_bus   ( debug_bus      ),
    .st_dout     ( st_157_dout    )
);

endmodule
