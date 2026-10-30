module jt05415x(
    input             rst,
    input             clk,
    input             pxl_cen,

    input             cs_156,
    input             cs_157,
    input             cram_cs,
    input             nv_cs, // NVCS | LYR_PRIO
    input       [5:1] addr,
    input      [13:1] cpu_addr,
    input             rnw,
    input      [15:0] din,
    output     [15:0] dout,
    input       [1:0] dsn,

    // Scan side
    input       [8:0] hdump,
    input       [8:0] vdump,

    output reg [12:0] lyrf_addr,
    output reg [12:0] lyra_addr,
    output reg [12:0] lyrb_addr,
    output reg [12:0] lyrc_addr,
    output reg        lyrf_cs,
    output reg        lyra_cs,
    output reg        lyrb_cs,
    output reg        lyrc_cs,
    input      [31:0] lyrf_data,
    input      [31:0] lyra_data,
    input      [31:0] lyrb_data,
    input      [31:0] lyrc_data,
    output reg [ 7:0] lyrf_col,
    output reg [ 7:0] lyra_col,
    output reg [ 7:0] lyrb_col,
    output reg [ 7:0] lyrc_col,
    output reg [ 7:0] lyrf_extra,
    output reg [ 7:0] lyra_extra,
    output reg [ 7:0] lyrb_extra,
    output reg [ 7:0] lyrc_extra,

    output     [15:0] vram_dout,

    // IOCTL dump
    input      [14:0] ioctl_addr,
    input             ioctl_ram,
    output      [7:0] ioctl_din,
    output      [7:0] mmr_dump,
    // Debug
    input       [7:0] debug_bus,
    output      [7:0] st_156_dout,
    output      [7:0] st_157_dout
);

parameter SIMFILE156 = "rest.bin",
          SIMFILE157 = "rest.bin";

wire [15:0] dout_156, dout_157, dout_mmr;
wire [ 7:0] ioctl_156_din, ioctl_157_din;
wire [ 7:0] vram0_scan, vram1_scan, vram2_scan;
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

reg dout_sel_157, dout_sel_vram;

assign dout_mmr  = dout_sel_157  ? dout_157  : dout_156;
assign dout      = dout_sel_vram ? vram_dout : dout_mmr;
assign mmr_dump  = ioctl_addr[6]  ? ioctl_157_din : ioctl_156_din;
assign ioctl_din = ioctl_addr[14] ? vram2_scan :
                   ioctl_addr[13] ? vram1_scan : vram0_scan;

always @(posedge clk) begin
    if( rst ) begin
        dout_sel_157  <= 0;
        dout_sel_vram <= 0;
    end else if( cs_156 | cs_157 | cram_cs ) begin
        dout_sel_157  <= cs_157;
        dout_sel_vram <= cram_cs;
    end
end

jt054156_mmr #(
    .SIMFILE ( SIMFILE156 )
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
    .ioctl_addr ( ioctl_addr[5:0] ),
    .ioctl_din  ( ioctl_156_din ),
    // Debug
    .debug_bus  ( debug_bus     ),
    .st_dout    ( st_156_dout   )
);

jt054157_mmr #(
    .SIMFILE ( SIMFILE157 )
) u_054157_mmr(
    .rst         ( rst            ),
    .clk         ( clk            ),

    .cs          ( cs_157         ),
    .addr        ( addr[2:1]      ),
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
    .ioctl_addr  ( ioctl_addr[2:0]),
    .ioctl_din   ( ioctl_157_din  ),
    // Debug
    .debug_bus   ( debug_bus      ),
    .st_dout     ( st_157_dout    )
);

// Moo Mesa wires the tile RAM as three 8-bit SRAMs with 13 address lines.
// This mirrors jt052109 FULLRAM=1 more closely than the MAME word-array model:
// RAM0 carries the extra/attribute byte, while RAM1/RAM2 form a 16-bit code word.
wire [12:0] vaddr;
wire [ 7:0] cpu_ram0, cpu_ram1, cpu_ram2;
wire [ 2:0] cs, ram_we;

jt05415x_vram_mapper u_vram_mapper(
    .cram_cs    ( cram_cs       ),
    .nv_cs      ( nv_cs         ),
    .rnw        ( rnw           ),
    .dsn        ( dsn           ),
    .addr       ( cpu_addr      ),
    .glob_ctrl  ( glob_ctrl     ),
    .irq_attr   ( irq_attr      ),
    .vram_ctrl  ( vram_ctrl     ),
    .ram_cs     ( cs            ),
    .ram_we     ( ram_we        )
);

assign vram_dout = cs[2] ? { 8'd0,     cpu_ram2 } :
                   cs[1] ? { cpu_ram1, cpu_ram2 } :
                   cs[0] ? { 8'd0,     cpu_ram0 } : 16'd0;

jtframe_dual_nvram #(
    .AW      ( 13         ),
    .SIMFILE ( "scr0.bin" )
) u_vram0(
    // Port 0: CPU
    .clk0   ( clk             ),
    .data0  ( din[7:0]        ),
    .addr0  ( cpu_addr[13:1]  ),
    .we0    ( ram_we[0]       ),
    .q0     ( cpu_ram0        ),
    // Port 1: scan or IOCTL
    .clk1   ( clk             ),
    .addr1a ( vaddr           ),
    .addr1b ( ioctl_addr[12:0]),
    .sel_b  ( ioctl_ram       ),
    .we_b   ( 1'b0            ),
    .data1  ( 8'd0            ),
    .q1     ( vram0_scan      )
);

jtframe_dual_nvram #(
    .AW      ( 13         ),
    .SIMFILE ( "scr1.bin" )
) u_vram1(
    // Port 0: CPU
    .clk0   ( clk             ),
    .data0  ( din[15:8]       ),
    .addr0  ( cpu_addr[13:1]  ),
    .we0    ( ram_we[1]       ),
    .q0     ( cpu_ram1        ),
    // Port 1: scan or IOCTL
    .clk1   ( clk             ),
    .addr1a ( vaddr           ),
    .addr1b ( ioctl_addr[12:0]),
    .sel_b  ( ioctl_ram       ),
    .we_b   ( 1'b0            ),
    .data1  ( 8'd0            ),
    .q1     ( vram1_scan      )
);

jtframe_dual_nvram #(
    .AW      ( 13         ),
    .SIMFILE ( "scr2.bin" )
) u_vram2(
    // Port 0: CPU
    .clk0   ( clk             ),
    .data0  ( din[7:0]        ),
    .addr0  ( cpu_addr[13:1]  ),
    .we0    ( ram_we[2]       ),
    .q0     ( cpu_ram2        ),
    // Port 1: scan or IOCTL
    .clk1   ( clk             ),
    .addr1a ( vaddr           ),
    .addr1b ( ioctl_addr[12:0]),
    .sel_b  ( ioctl_ram       ),
    .we_b   ( 1'b0            ),
    .data1  ( 8'd0            ),
    .q1     ( vram2_scan      )
);

wire [ 5:0] layer_vgrid, layer_hgrid;
wire [10:0] layer_scry;
wire [11:0] layer_scrx, line_scroll_x;
wire [ 1:0] layer_scroll;
wire [ 1:0] layer_x, layer_y, layer_w, layer_h;
wire [ 2:0] layer_span_x, layer_span_y;
wire [ 1:0] src_page_x, src_page_y;
wire [ 5:0] tile_x;
wire [ 4:0] tile_y;
wire [10:0] tile_addr, line_pair_off;
wire [11:0] layer_height, y_sum;
wire [12:0] hflip_corr_ext, layer_rom_addr, layer_width, x_sum, x_scroll;
wire [12:0] tile_ram_addr, line_ram_addr;
wire [11:0] vflip_corr_ext;
wire [ 1:0] a_x, b_x, c_x, d_x,
            a_y, b_y, c_y, d_y,
            a_w, b_w, c_w, d_w,
            a_h, b_h, c_h, d_h;
wire        line_fetch;
wire        a_covers, b_covers, c_covers, d_covers;
wire        assoc_disable, active_nx;
reg  [11:0] lyrf_line_scroll, lyra_line_scroll, lyrb_line_scroll, lyrc_line_scroll;
reg  [12:0] x_mod, x_nx;
reg  [11:0] y_mod;
reg  [10:0] y_nx;
reg  [ 1:0] scan_phase, scan_phase_l;
reg         line_fetch_l;
integer     mod_i;

assign layer_vgrid  = scan_phase==2'd0 ? a_vgrid       :
                      scan_phase==2'd1 ? b_vgrid       :
                      scan_phase==2'd2 ? c_vgrid       : d_vgrid;
assign layer_hgrid  = scan_phase==2'd0 ? a_hgrid       :
                      scan_phase==2'd1 ? b_hgrid       :
                      scan_phase==2'd2 ? c_hgrid       : d_hgrid;
assign layer_scry   = scan_phase==2'd0 ? a_scry        :
                      scan_phase==2'd1 ? b_scry        :
                      scan_phase==2'd2 ? c_scry        : d_scry;
assign layer_scrx   = scan_phase==2'd0 ? a_scrx        :
                      scan_phase==2'd1 ? b_scrx        :
                      scan_phase==2'd2 ? c_scrx        : d_scrx;
assign layer_scroll = scan_phase==2'd0 ? lnscr_ctrl[1:0] :
                      scan_phase==2'd1 ? lnscr_ctrl[3:2] :
                      scan_phase==2'd2 ? lnscr_ctrl[5:4] : lnscr_ctrl[7:6];
assign line_scroll_x = scan_phase==2'd0 ? lyrf_line_scroll :
                       scan_phase==2'd1 ? lyra_line_scroll :
                       scan_phase==2'd2 ? lyrb_line_scroll : lyrc_line_scroll;

assign a_x = a_hgrid[4:3];
assign b_x = b_hgrid[4:3];
assign c_x = c_hgrid[4:3];
assign d_x = d_hgrid[4:3];
assign a_y = a_vgrid[4:3];
assign b_y = b_vgrid[4:3];
assign c_y = c_vgrid[4:3];
assign d_y = d_vgrid[4:3];
assign a_w = a_hgrid[1:0];
assign b_w = b_hgrid[1:0];
assign c_w = c_hgrid[1:0];
assign d_w = d_hgrid[1:0];
assign a_h = a_vgrid[1:0];
assign b_h = b_vgrid[1:0];
assign c_h = c_vgrid[1:0];
assign d_h = d_vgrid[1:0];

assign layer_x      = layer_hgrid[4:3];
assign layer_y      = layer_vgrid[4:3];
assign layer_w      = layer_hgrid[1:0];
assign layer_h      = layer_vgrid[1:0];
assign layer_span_x = { 1'b0, layer_w } + 3'd1;
assign layer_span_y = { 1'b0, layer_h } + 3'd1;
assign layer_width  = { 1'b0, layer_span_x, 9'd0 };
assign layer_height = { 1'b0, layer_span_y, 8'd0 };
assign hflip_corr_ext = { hflip_corr[11], hflip_corr };
assign vflip_corr_ext = { vflip_corr[10], vflip_corr };
assign y_sum = { 3'd0, vdump } + { 1'b0, layer_scry } + (glob_ctrl[5] ? vflip_corr_ext : 12'd0);
assign x_scroll = layer_scroll[0]==1'd0 ? { 1'b0, line_scroll_x } : { 1'b0, layer_scrx };
assign x_sum = { 4'd0, hdump } + x_scroll + (glob_ctrl[4] ? hflip_corr_ext : 13'd0);
assign src_page_x = layer_x + x_nx[10:9];
assign src_page_y = layer_y + y_nx[9:8];
assign tile_x     = x_nx[8:3];
assign tile_y     = y_nx[7:3];
assign tile_addr  = { tile_y, tile_x };
assign line_pair_off = layer_scroll==2'd2 ? { scan_phase, y_nx[8:3], 3'd0 } :
                                            { scan_phase, y_nx[8:0]       };
assign line_ram_addr = { lnscr_bank[0], line_pair_off, 1'b0 };
assign tile_ram_addr = { src_page_y[0], src_page_x[0], tile_addr };
assign line_fetch    = pxl_cen && layer_scroll[0]==1'd0 && hdump[2:0]==3'd0;
assign assoc_disable = (a_x==0 && a_y==0 && a_w==3 && a_h==3) ||
                       (b_x==0 && b_y==0 && b_w==3 && b_h==3) ||
                       (c_x==0 && c_y==0 && c_w==3 && c_h==3) ||
                       (d_x==0 && d_y==0 && d_w==3 && d_h==3);
assign a_covers = (src_page_y - a_y) <= a_h && (src_page_x - a_x) <= a_w;
assign b_covers = (src_page_y - b_y) <= b_h && (src_page_x - b_x) <= b_w;
assign c_covers = (src_page_y - c_y) <= c_h && (src_page_x - c_x) <= c_w;
assign d_covers = (src_page_y - d_y) <= d_h && (src_page_x - d_x) <= d_w;
assign active_nx = scan_phase==2'd0 ? assoc_disable || !(b_covers || c_covers || d_covers) :
                   scan_phase==2'd1 ? assoc_disable || !(c_covers || d_covers)             :
                   scan_phase==2'd2 ? assoc_disable || !d_covers                           : 1'b1;
assign layer_rom_addr = { vram1_scan[4:0], vram2_scan };
assign vaddr = line_fetch ? line_ram_addr : tile_ram_addr;

always @* begin
    y_mod = y_sum;
    for( mod_i=0; mod_i<16; mod_i=mod_i+1 ) begin
        if( y_mod >= layer_height ) y_mod = y_mod - layer_height;
    end
    y_nx = glob_ctrl[5] ? layer_height[10:0] - 11'd1 - y_mod[10:0] : y_mod[10:0];

    x_mod = x_sum;
    for( mod_i=0; mod_i<16; mod_i=mod_i+1 ) begin
        if( x_mod >= layer_width ) x_mod = x_mod - layer_width;
    end
    x_nx = glob_ctrl[4] ? layer_width - 13'd1 - x_mod : x_mod;
end

always @(posedge clk) begin
    if( rst ) begin
        scan_phase       <= 0;
        scan_phase_l     <= 0;
        line_fetch_l     <= 0;
        lyrf_line_scroll <= 0;
        lyra_line_scroll <= 0;
        lyrb_line_scroll <= 0;
        lyrc_line_scroll <= 0;
        lyrf_addr        <= 0;
        lyra_addr        <= 0;
        lyrb_addr        <= 0;
        lyrc_addr        <= 0;
        lyrf_cs          <= 0;
        lyra_cs          <= 0;
        lyrb_cs          <= 0;
        lyrc_cs          <= 0;
        lyrf_col         <= 0;
        lyra_col         <= 0;
        lyrb_col         <= 0;
        lyrc_col         <= 0;
        lyrf_extra       <= 0;
        lyra_extra       <= 0;
        lyrb_extra       <= 0;
        lyrc_extra       <= 0;
    end else begin
        scan_phase_l <= scan_phase;
        line_fetch_l <= line_fetch;
        if( pxl_cen ) scan_phase <= scan_phase + 2'd1;

        if( line_fetch_l ) begin
            case( scan_phase_l )
                2'd0:    lyrf_line_scroll <= { vram1_scan[3:0], vram2_scan };
                2'd1:    lyra_line_scroll <= { vram1_scan[3:0], vram2_scan };
                2'd2:    lyrb_line_scroll <= { vram1_scan[3:0], vram2_scan };
                default: lyrc_line_scroll <= { vram1_scan[3:0], vram2_scan };
            endcase
        end

        if( pxl_cen ) begin
            case( scan_phase )
                2'd0: begin
                    lyrf_addr  <= layer_rom_addr;
                    lyrf_cs    <= active_nx;
                    lyrf_col   <= vram0_scan;
                    lyrf_extra <= vram0_scan;
                end
                2'd1: begin
                    lyra_addr  <= layer_rom_addr;
                    lyra_cs    <= active_nx;
                    lyra_col   <= vram0_scan;
                    lyra_extra <= vram0_scan;
                end
                2'd2: begin
                    lyrb_addr  <= layer_rom_addr;
                    lyrb_cs    <= active_nx;
                    lyrb_col   <= vram0_scan;
                    lyrb_extra <= vram0_scan;
                end
                default: begin
                    lyrc_addr  <= layer_rom_addr;
                    lyrc_cs    <= active_nx;
                    lyrc_col   <= vram0_scan;
                    lyrc_extra <= vram0_scan;
                end
            endcase
        end
    end
end

endmodule

module jt05415x_vram_mapper(
    input             nv_cs,
    input             cram_cs,
    input             rnw,
    input       [1:0] dsn,
    input      [13:1] addr,
    input       [7:0] glob_ctrl,
    input       [7:0] irq_attr,
    input       [5:0] vram_ctrl,
    output reg  [2:0] ram_cs,
    output      [2:0] ram_we
);

wire        write_cycle  = cram_cs & ~rnw & (dsn != 2'b11);
wire        l125a_y      = dsn[0] ^ irq_attr[5];
wire        p113b_y      = ~&{ vram_ctrl[1], ~vram_ctrl[0] };
wire        p170b_y      = p113b_y & l125a_y;

reg [2:0] mapped, pre_cs;
always @(*) begin
    case (addr[13:11])
        3'b001:  mapped = 3'b110; // 0
        3'b000:  mapped = 3'b101; // 1
        3'b010:  mapped = 3'b011; // 2
        default: mapped = 3'b111;
    endcase
    pre_cs = { addr[12], addr[12],~addr[12]};
    if(vram_ctrl[0])
        pre_cs = {~addr[1],~addr[1], addr[1]};
    if(vram_ctrl[1])
        pre_cs = mapped;


    ram_cs = ~pre_cs;
    if(~cram_cs | ~nv_cs)
                ram_cs    = 0;
    if(p113b_y) ram_cs[0] = 0;
    if(p170b_y) ram_cs[1] = 0;
    if(rnw    ) ram_cs[2] = 0;
end

assign ram_we = ram_cs & { 3{ write_cycle } };

`ifdef SIMULATION
wire unsupported_vram_timing = |{ glob_ctrl[7], glob_ctrl[1:0] };
`endif

endmodule
