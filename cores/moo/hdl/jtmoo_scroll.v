/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoo_scroll(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             pxl2_cen,

    // Base Video
    input             lhbl,
    input             lvbl,
    input             hs,
    input             vs,
    output reg [ 8:0] hdump,
    output reg [ 8:0] vdump,
    output     [ 8:0] vrender,
    output     [ 8:0] vrender1,

    // CPU interface
    input             reg_cs,
    input             gfx_cs,
    input             vram_cs,
    input             cpu_we,
    input      [15:0] cpu_addr,
    input      [ 1:0] cpu_dsn,
    input      [15:0] cpu_dout,
    output     [15:0] tile_dout,
    output            cpu_rom_dtack,
    output reg        rst8,

    // control
    input             rmrd,
    output            irq_n,
    output            firq_n,
    output            nmi_n,
    output            flip,
    output            e,
    output            q,

    // color byte connection
    output     [ 7:0] lyrf_extra,
    output     [ 7:0] lyra_extra,
    output     [ 7:0] lyrb_extra,

    output     [ 7:0] lyrf_col,
    output     [ 7:0] lyra_col,
    output     [ 7:0] lyrb_col,

    input      [ 7:0] lyrf_cg,
    input      [ 7:0] lyra_cg,
    input      [ 7:0] lyrb_cg,

    // Tile ROMs
    output     [12:0] lyrf_addr,
    output     [12:0] lyra_addr,
    output     [12:0] lyrb_addr,

    output            lyrf_cs,
    output            lyra_cs,
    output            lyrb_cs,

    input      [31:0] lyrf_data,
    input      [31:0] lyra_data,
    input      [31:0] lyrb_data,

    input             lyra_ok,

    // Final pixels
    output            lyrf_blnk_n,
    output            lyra_blnk_n,
    output            lyrb_blnk_n,
    output     [ 7:0] lyrf_pxl,
    output     [11:0] lyra_pxl,
    output     [11:0] lyrb_pxl,

    // Debug
    input      [14:0] ioctl_addr,
    input             ioctl_ram,
    output     [ 7:0] ioctl_din,
    output     [ 7:0] mmr_dump,

    input      [ 3:0] gfx_en,
    input      [ 7:0] debug_bus,
    output     [ 7:0] st_dout
);

reg [2:0] frame_cnt;
reg       reg_wr_seen, vram_wr_seen;
wire [12:0] lyrc_addr;
wire [15:0] scroll_dout;
wire [ 7:0] lyrc_col, lyrc_extra, st_156, st_157, st_pix;
reg  [ 3:0] lyrf_dot, lyra_dot, lyrb_dot;
wire        rnw, unused;

assign rnw           = ~cpu_we;
assign unused        = &{ 1'b0, pxl2_cen, lhbl, lvbl, rmrd, lyrf_cg, lyra_cg,
                          lyrb_cg, lyra_ok, lyrc_addr, lyrc_col, lyrc_extra };

assign vrender       = vdump;
assign vrender1      = vdump + 9'd1;
assign tile_dout     = scroll_dout;
assign cpu_rom_dtack = 1'b1;

assign irq_n         = 1'b1;
assign firq_n        = 1'b1;
assign nmi_n         = 1'b1;
assign flip          = 1'b0;
assign e             = 1'b0;
assign q             = 1'b0;

assign lyrf_blnk_n   = gfx_en[0] & lyrf_cs & |lyrf_dot;
assign lyra_blnk_n   = gfx_en[1] & lyra_cs & |lyra_dot;
assign lyrb_blnk_n   = gfx_en[2] & lyrb_cs & |lyrb_dot;
assign lyrf_pxl      = { lyrf_col[7:4], lyrf_dot };
assign lyra_pxl      = { 4'd0, lyra_col[3:0], lyra_dot };
assign lyrb_pxl      = { 4'd0, lyrb_col[3:0], lyrb_dot };
assign st_pix        = { vram_wr_seen, reg_wr_seen, lyrf_cs, lyra_cs,
                         lyrb_cs, |lyrf_dot, |lyra_dot, |lyrb_dot };
assign st_dout       = debug_bus[1] ? st_pix : debug_bus[0] ? st_157 : st_156;

always @* begin
    case( hdump[2:0] )
        3'd0: begin
            lyrf_dot = lyrf_data[15:12];
            lyra_dot = lyra_data[15:12];
            lyrb_dot = lyrb_data[15:12];
        end
        3'd1: begin
            lyrf_dot = lyrf_data[11: 8];
            lyra_dot = lyra_data[11: 8];
            lyrb_dot = lyrb_data[11: 8];
        end
        3'd2: begin
            lyrf_dot = lyrf_data[ 7: 4];
            lyra_dot = lyra_data[ 7: 4];
            lyrb_dot = lyrb_data[ 7: 4];
        end
        3'd3: begin
            lyrf_dot = lyrf_data[ 3: 0];
            lyra_dot = lyra_data[ 3: 0];
            lyrb_dot = lyrb_data[ 3: 0];
        end
        3'd4: begin
            lyrf_dot = lyrf_data[31:28];
            lyra_dot = lyra_data[31:28];
            lyrb_dot = lyrb_data[31:28];
        end
        3'd5: begin
            lyrf_dot = lyrf_data[27:24];
            lyra_dot = lyra_data[27:24];
            lyrb_dot = lyrb_data[27:24];
        end
        3'd6: begin
            lyrf_dot = lyrf_data[23:20];
            lyra_dot = lyra_data[23:20];
            lyrb_dot = lyrb_data[23:20];
        end
        default: begin
            lyrf_dot = lyrf_data[19:16];
            lyra_dot = lyra_data[19:16];
            lyrb_dot = lyrb_data[19:16];
        end
    endcase
end

jt05415x u_05415x(
    .rst          ( rst            ),
    .clk          ( clk            ),
    .pxl_cen      ( pxl_cen        ),

    .cs_156       ( reg_cs         ),
    .cs_157       ( gfx_cs         ),
    .cram_cs      ( vram_cs        ),
    .nv_cs        ( vram_cs        ),
    .addr         ( cpu_addr[5:1]  ),
    .cpu_addr     ( cpu_addr[13:1] ),
    .rnw          ( rnw            ),
    .din          ( cpu_dout       ),
    .dout         ( scroll_dout    ),
    .dsn          ( cpu_dsn        ),

    .hdump        ( hdump          ),
    .vdump        ( vdump          ),

    .lyrf_addr    ( lyrf_addr      ),
    .lyra_addr    ( lyra_addr      ),
    .lyrb_addr    ( lyrb_addr      ),
    .lyrc_addr    ( lyrc_addr      ),
    .lyrf_cs      ( lyrf_cs        ),
    .lyra_cs      ( lyra_cs        ),
    .lyrb_cs      ( lyrb_cs        ),
    .lyrc_cs      (                ),
    .lyrf_data    ( lyrf_data      ),
    .lyra_data    ( lyra_data      ),
    .lyrb_data    ( lyrb_data      ),
    .lyrc_data    ( 32'd0          ),
    .lyrf_col     ( lyrf_col       ),
    .lyra_col     ( lyra_col       ),
    .lyrb_col     ( lyrb_col       ),
    .lyrc_col     ( lyrc_col       ),
    .lyrf_extra   ( lyrf_extra     ),
    .lyra_extra   ( lyra_extra     ),
    .lyrb_extra   ( lyrb_extra     ),
    .lyrc_extra   ( lyrc_extra     ),

    .vram_dout    (                ),

    .ioctl_addr   ( ioctl_addr     ),
    .ioctl_ram    ( ioctl_ram      ),
    .ioctl_din    ( ioctl_din      ),
    .mmr_dump     ( mmr_dump       ),

    .debug_bus    ( debug_bus      ),
    .st_156_dout  ( st_156         ),
    .st_157_dout  ( st_157         )
);

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        hdump        <= 0;
        vdump        <= 0;
        frame_cnt    <= 0;
        rst8         <= 0;
        reg_wr_seen  <= 0;
        vram_wr_seen <= 0;
    end else if( pxl_cen ) begin
        reg_wr_seen  <= reg_wr_seen  | (cpu_we & (reg_cs | gfx_cs));
        vram_wr_seen <= vram_wr_seen | (cpu_we & vram_cs);
        hdump <= hs ? 9'd0 : hdump + 9'd1;
        if( hs ) begin
            vdump <= vs ? 9'd0 : vdump + 9'd1;
            if( vs ) begin
                frame_cnt <= frame_cnt + 3'd1;
                rst8      <= &frame_cnt;
            end
        end
    end
end

endmodule
