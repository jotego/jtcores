/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 2-9-2026 */

module jtmoo_scroll(
    input             rst,
    input             clk,
    input             pxl_cen,

    // Base Video
    input             lhbl,
    input             lvbl,
    input             hs,
    input             vs,
    output reg [ 8:0] hdump,
    output reg [ 8:0] vdump,

    // CPU interface
    input             reg_cs,   // K054156 register bank, 0x0C0000
    input             gfx_cs,   // K054157 register bank, 0x0D8000
    input             vram_cs,  // tile RAM,               0x1A0000
    input             rmrd_cs,  // tile ROM read-back,     0x1B0000
    input             cpu_we,
    input      [12:1] cpu_addr,
    input      [ 1:0] cpu_dsn,
    input      [15:0] cpu_dout,
    output     [15:0] tile_dout,

    // control
    output            flip,

    // Tile ROMs
    output     [20:2] lyrf_addr, lyra_addr, lyrb_addr, lyrc_addr,
    output            lyrf_cs,   lyra_cs,   lyrb_cs,   lyrc_cs,
    input      [31:0] lyrf_data, lyra_data, lyrb_data, lyrc_data,
    input             lyrf_ok,   lyra_ok,   lyrb_ok,   lyrc_ok,

    // Final pixels, {palette, colour}
    output     [11:0] lyrf_pxl, lyra_pxl, lyrb_pxl, lyrc_pxl,

    // Debug
    input      [14:0] ioctl_addr,
    input             ioctl_ram,
    output     [ 7:0] ioctl_din,
    output     [ 7:0] mmr_dump,

    input      [ 3:0] gfx_en,
    input      [ 7:0] debug_bus,
    output     [ 7:0] st_dout
);

wire [7:0] st_156, st_157;
wire       rnw, blankn;

assign rnw     = ~cpu_we;
// tile fetch runs through HBLANK so the first group of each line is primed
assign blankn  = lvbl;
assign st_dout = debug_bus[0] ? st_157 : st_156;

jt05415x #(.SIMFILE156("scr_mmr.bin"),.SIMFILE157("gfx_mmr.bin")) u_05415x(
    .rst          ( rst            ),
    .clk          ( clk            ),
    .pxl_cen      ( pxl_cen        ),

    .cs_156       ( reg_cs         ),
    .cs_157       ( gfx_cs         ),
    .cram_cs      ( vram_cs        ),
    .rmrd_cs      ( rmrd_cs        ),
    .addr         ( cpu_addr[5:1]  ),
    .cpu_addr     ( cpu_addr       ),
    .rnw          ( rnw            ),
    .din          ( cpu_dout       ),
    .dout         ( tile_dout      ),
    .dsn          ( cpu_dsn        ),

    .hdump        ( hdump          ),
    .vdump        ( vdump          ),
    .blankn       ( blankn         ),
    .flip         ( flip           ),

    .lyrf_addr    ( lyrf_addr      ),
    .lyra_addr    ( lyra_addr      ),
    .lyrb_addr    ( lyrb_addr      ),
    .lyrc_addr    ( lyrc_addr      ),
    .lyrf_cs      ( lyrf_cs        ),
    .lyra_cs      ( lyra_cs        ),
    .lyrb_cs      ( lyrb_cs        ),
    .lyrc_cs      ( lyrc_cs        ),
    .lyrf_data    ( lyrf_data      ),
    .lyra_data    ( lyra_data      ),
    .lyrb_data    ( lyrb_data      ),
    .lyrc_data    ( lyrc_data      ),
    .lyrf_ok      ( lyrf_ok        ),
    .lyra_ok      ( lyra_ok        ),
    .lyrb_ok      ( lyrb_ok        ),
    .lyrc_ok      ( lyrc_ok        ),
    .lyrf_pxl     ( lyrf_pxl       ),
    .lyra_pxl     ( lyra_pxl       ),
    .lyrb_pxl     ( lyrb_pxl       ),
    .lyrc_pxl     ( lyrc_pxl       ),

    .ioctl_addr   ( ioctl_addr     ),
    .ioctl_ram    ( ioctl_ram      ),
    .ioctl_din    ( ioctl_din      ),
    .mmr_dump     ( mmr_dump       ),

    .gfx_en       ( gfx_en         ),
    .debug_bus    ( debug_bus      ),
    .st_156_dout  ( st_156         ),
    .st_157_dout  ( st_157         )
);

// HS is a level from the CCU, so vdump steps once per HS edge. 264 lines over
// 0x0F8-0x1FF, visible from 0x110 (jt053246_scan.sv), LVBL edge = frame origin
reg hs_l, lvbl_l, vfirst;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        hdump  <= 0;
        vdump  <= 9'h110;
        hs_l   <= 0;
        lvbl_l <= 0;
        vfirst <= 0;
    end else if( pxl_cen ) begin
        hs_l   <= hs;
        lvbl_l <= lvbl;
        hdump  <= hs ? 9'd0 : hdump + 9'd1;
        if( lvbl & ~lvbl_l ) vfirst <= 1;
        if( hs & ~hs_l ) begin
            vfirst <= 0;
            vdump  <= vfirst ? 9'h110 : vdump==9'h1FF ? 9'h0F8 : vdump + 9'd1;
        end
    end
end

`ifdef SIMULATION
/* verilator tracing_off */
wire unused_scroll = &{ 1'b0, vs };
`endif

endmodule
