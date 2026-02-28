/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a dma_bsy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 18-09-2022 */

// There is bus contention to access the memories
// in this module, based. When H4 is high, the
// GPU is in control. When H4 is low, it's the CPU

// SETAX1-001, the die shot available shows what it seems to
// be an internal dual-line buffer and another larger memory

module jtkiwi_gfx #(
    parameter CPUW=8
)(
    input               rst,
    input               clk,
    input               clk_cpu,

    input               pxl2_cen,
    input               pxl_cen,

    input               LHBL,
    input               LVBL,
    input               hs,
    input               vs,
    output              flip,
    input               drtoppel,

    input      [ 8:0]   vdump,
    input      [ 8:0]   vrender,
    input      [ 8:0]   hdump,

    input               cpu_rnw,
    input      [ 1:0]   cpu_dsn,    // ignored for CPUW==8
    input      [12:0]   cpu_addr,
    input  [CPUW-1:0]   cpu_dout,
    input               vram_cs,
    input               vctrl_cs,
    input               vflag_cs,
    output [CPUW-1:0]   cpu_din,

    // Internal RAM (defined in mem.yaml)
    output reg [ 9:0]   col_addr,
    input      [ 7:0]   col_data, yram_dout,
    output              yram_we,
    // External VRAM (defined in mem.yaml)
    output     [12:1]   dma_addr,
    output     [15:0]   dma_din,
    output     [ 1:0]   dma_we,
    input      [15:0]   dma_dout, code_dout,
    output reg [12:1]   code_addr,
    // SDRAM interface
    output     [20:2]   scr_addr,
    input      [31:0]   scr_data,
    input               scr_ok,
    output              scr_cs,

    output     [20:2]   obj_addr,
    input      [31:0]   obj_data,
    input               obj_ok,
    output              obj_cs,

    output      [ 8:0]  scr_pxl,
    output      [ 8:0]  obj_pxl,
    input       [ 7:0]  debug_bus,
    output reg  [ 7:0]  st_dout
);

wire        video_en;
wire [ 1:0] vram_we;
wire [11:0] tm_addr, lut_addr;
wire [ 7:0] scol_addr;
reg  [ 7:0] attr, xpos, ypos;
reg  [ 7:0] cfg[0:3], flag;
reg         scan_cen, done, dr_start, dr_busy,
            match, xflip, yflip, cfg_cs, yram_cs;
reg  [ 2:0] st;
reg  [13:0] code;
reg  [ 1:0] cen_cnt;
wire        tm_page, obj_bufb, obj_page, obj_pg_en;
wire [15:0] col_xmsb;
wire [ 3:0] col_cfg;
wire [ 1:0] col0;
reg         tm_cen, lut_cen;
// Objects
wire [ 8:0] y_addr;

`ifdef SIMULATION
wire [7:0] cfg0 = cfg[0], cfg1 = cfg[1], cfg2 = cfg[2], cfg3 = cfg[3];
`endif

assign vram_we  = {2{vram_cs  & ~cpu_rnw}} & (
                    CPUW==8 ? { cpu_addr[12], ~cpu_addr[12] } : ~cpu_dsn );
assign yram_we  = yram_cs && !cpu_rnw && (CPUW==8 || !cpu_dsn[0]);
assign flip     =~cfg[0][6]; // only flip y?
assign video_en = cfg[0][4]; // uncertain
assign col0     = cfg[0][1:0]; // start column in the tilemap VRAM
assign obj_pg_en= cfg[0][3]; // uncertain
assign tm_page  = cfg[1][6];
assign obj_bufb = cfg[1][5];
assign obj_page = tm_page ^ ~obj_bufb;
assign col_cfg  = cfg[1][3:0];
assign col_xmsb = { cfg[3], cfg[2] };
assign dma_din  = dma_bsy ? dma_data   : vram_d16;
assign dma_we   = dma_bsy ? dma_bsy_we : vram_we;

generate
    if(CPUW==8) begin
        assign cpu_din  = yram_cs ? yram_dout :
                          vram_cs ? (cpu_addr[12] ? dma_dout[15:8] : dma_dout[7:0]) : 8'h00;
    end else begin
        assign cpu_din  = yram_cs ? {8'd0,yram_dout} :
                          vram_cs ? dma_dout : 16'h00;

    end
endgenerate

always @* begin
    yram_cs = 0;
    cfg_cs  = 0;
    if( vctrl_cs ) case( cpu_addr[9:8] )
        0,1,2: yram_cs = 1;
        3:     cfg_cs  = 1;
        default:;
    endcase
end

always @(posedge clk) begin
    case(debug_bus[2:0])
        0: st_dout <= cfg[0];
        1: st_dout <= cfg[1];
        2: st_dout <= cfg[2];
        3: st_dout <= cfg[3];
        4: st_dout <= flag;
        5: st_dout <= { flip, video_en, col0, col_cfg };
        default: st_dout <= 0;
    endcase
end

always @(posedge clk) begin
    if( rst ) begin
        cen_cnt <= 0;
        tm_cen  <= 0;
        lut_cen <= 0;
    end else begin
        cen_cnt <= cen_cnt + 1'd1;
        tm_cen  <= cen_cnt==0;
        lut_cen <= cen_cnt==2;
    end
end

`ifdef NOMAIN
initial $readmemh("seta_cfg.hex",cfg);
`endif

always @(posedge clk, posedge rst) begin
`ifndef NOMAIN
    if( rst ) begin
        cfg[0]  <= 0;
        cfg[1]  <= 9;
        cfg[2]  <= 0;
        cfg[3]  <= 0;
    end else
`endif
    begin
        if( cfg_we   ) cfg[ cpu_addr[1:0] ] <= cpu_dout[7:0];
        if( vflag_cs ) flag <=  cpu_dout[(CPUW==16?8:0)+:8];
    end
end

always @* begin
    case( cen_cnt )
        0,1: begin
            col_addr  = { 2'b10, scol_addr };
            code_addr = tm_addr;
        end
        2,3: begin // objects
            col_addr  = { 1'b0, y_addr };
            code_addr = lut_addr;
        end
    endcase
end

jtkiwi_tilemap u_tilemap(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .tm_cen     ( tm_cen    ),

    .hs         ( hs        ),
    .flip       ( flip      ),
    .page       ( tm_page   ),
    .drtoppel   ( drtoppel  ),

    .col_xmsb   ( col_xmsb  ),
    .col_cfg    ( col_cfg   ),
    .col0       ( col0      ),

    .tm_addr    ( tm_addr   ),
    .tm_data    ( code_dout ),

    // Column scroll
    .col_addr   ( scol_addr ),
    .col_data   ( col_data  ),

    .rom_addr   ( scr_addr  ),
    .rom_cs     ( scr_cs    ),
    .rom_ok     ( scr_ok    ),
    .rom_data   ( scr_data  ),

    .vrender    ( vdump     ),
    .hdump      ( hdump     ),
    .pxl        ( scr_pxl   ),
    .debug_bus  ( debug_bus )
);

jtkiwi_obj u_obj(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .lut_cen    ( lut_cen   ),
    .pxl_cen    ( pxl_cen   ),

    .hs         ( hs        ),
    .flip       ( flip      ),
    .page       ( obj_page  ),

    .lut_addr   ( lut_addr  ),
    .lut_data   ( code_dout ),

    // Column scroll
    .y_addr     ( y_addr    ),
    .y_data     ( col_data  ),

    .rom_addr   ( obj_addr  ),
    .rom_cs     ( obj_cs    ),
    .rom_ok     ( obj_ok    ),
    .rom_data   ( obj_data  ),

    .vdump      ( vdump     ),
    .hdump      ( hdump     ),
    .pxl        ( obj_pxl   ),
    .debug_bus  ( debug_bus )
);

// This is an external memory chip. The original
// one is an 8-bit memory. Changed to 16-bit access
// to ease the drawing logic
// the upper byte refers to the upper half of the
// memory for the CPU
// In MAME the lower half is called spritecodelow
// and the upper spritecodehigh

reg  [9:0] dma_cnt;
reg        LVBL_l;
reg        dma_st;
reg        dma_obj = 0;
reg        dma_tm = 0;
reg        dma_start = 0;
wire       dma_bsy = dma_obj | dma_tm;

// DMA when cfg[1][5] == 0
// Sprite DMA starts with VBLANK
// Tilemap DMA starts with writing to cfg[1]
wire cfg_we = cfg_cs && !cpu_rnw && (CPUW==8 || !cpu_dsn[0]);
wire auto_dma = (!obj_bufb || !obj_pg_en) && pg_change;
reg  [15:0] dma_data;
wire [12:1] dma_txa  = {dma_tm ^ tm_page ^ dma_st, dma_tm, dma_cnt};

assign      dma_addr =  dma_bsy ? dma_txa : cpu_addr[11:0];
wire [ 1:0] dma_bsy_we = {2{dma_st}};
wire        vb_starts = !LVBL && LVBL_l;
reg         tm_page_l;
wire        pg_change = tm_page != tm_page_l;

always @(posedge clk) begin
    if (cfg_we && cpu_addr[1:0] == 1 && !cpu_dout[5]) dma_start <= 1;
    LVBL_l <= LVBL;
    if(vb_starts) tm_page_l <= tm_page;
    if (auto_dma && vb_starts) begin
        // Start sprite dma_bsy
        dma_cnt <= 0;
        dma_obj <= 1;
        dma_st  <= 0;
    end else if (dma_start && !dma_bsy) begin
        // Start tilemap dma_bsy
        dma_start <= 0;
        dma_cnt   <= 0;
        dma_tm    <= 1;
        dma_st    <= 0;
    end else if (dma_bsy && pxl_cen ) begin // executed at 6MHz. Needs confirmation from PCB measurements
        dma_st <= ~dma_st;
        if (!dma_st) begin
            // read phase
            dma_data <= dma_dout;
        end else begin
            // write phase
            dma_cnt <= dma_cnt + 1'd1;
            if (&dma_cnt) begin
                dma_cnt <= 0;
                dma_obj <= 0;
                dma_tm  <= 0;
            end
        end
    end
end

wire [15:0] vram_d16 = {cpu_dout[CPUW-1-:8], cpu_dout[7:0]};

// jtframe_dual_ram16 #(.AW(12),
//     .SIMFILE_LO("vram_lo.bin"),
//     .SIMFILE_HI("vram_hi.bin")
// ) u_vram(
//     .clk0   ( clk_cpu    ),
//     .clk1   ( clk        ),
//     // Main CPU
//     // probably the CPU should be WAIT-ed during DMA access, but it's
//     // very fast, thus there's no overlap with CPU VRAM access
//     .addr0  ( dma_bsy ? dma_addr : cpu_addr[11:0] ),
//     .data0  ( dma_bsy ? dma_data      : vram_d16       ),
//     .we0    ( dma_bsy ? dma_bsy_we        : vram_we        ),
//     .q0     ( dma_dout  ),
//     // GFX
//     .addr1  ( code_addr  ),
//     .data1  ( 16'd0      ),
//     .we1    ( 2'd0       ),
//     .q1     ( code_dout  )
// );

endmodule