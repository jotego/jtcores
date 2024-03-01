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

module jtkiwi_gfx(
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

    input      [ 8:0]   vdump,
    input      [ 8:0]   vrender,
    input      [ 8:0]   hdump,

    input               cpu_rnw,
    input      [12:0]   cpu_addr,
    input      [ 7:0]   cpu_dout,
    input               vram_cs,
    input               vctrl_cs,
    input               vflag_cs,
    output     [ 7:0]   cpu_din,

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
    output      [ 7:0]  st_dout
);

wire        yram_we, video_en;
wire [ 1:0] vram_we;
wire [11:0] tm_addr, lut_addr;
reg  [11:0] code_addr;
reg  [ 9:0] col_addr;
wire [ 7:0] yram_dout, col_data;
wire [ 7:0] scol_addr;
reg  [ 7:0] attr, xpos, ypos;
reg  [ 7:0] cfg[0:3], flag;
reg         scan_cen, done, dr_start, dr_busy,
            match, xflip, yflip,
            yram_cs, cfg_cs;
reg  [ 2:0] st;
reg  [13:0] code;
reg  [ 1:0] cen_cnt;
wire        tm_page, obj_bufb;
wire [15:0] vram_dout, code_dout, col_xmsb;
wire [ 3:0] col_cfg;
wire [ 1:0] col0;
reg         tm_cen, lut_cen;
// Objects
wire [ 8:0] y_addr;

`ifdef SIMULATION
wire [7:0] cfg0 = cfg[0], cfg1 = cfg[1], cfg2 = cfg[2], cfg3 = cfg[3];
`endif

assign vram_we  = {2{vram_cs  & ~cpu_rnw}} & { cpu_addr[12], ~cpu_addr[12] };
assign yram_we  = yram_cs & ~cpu_rnw;
assign flip     = ~cfg[0][6]; // only flip y?
assign video_en = cfg[0][4]; // uncertain
assign col0     = cfg[0][1:0]; // start column in the tilemap VRAM
assign tm_page  = cfg[1][6];
assign obj_bufb = cfg[1][5];
assign col_cfg  = cfg[1][3:0];
assign col_xmsb = { cfg[3], cfg[2] };
assign cpu_din  = yram_cs ? yram_dout :
                  vram_cs ? (cpu_addr[12] ? vram_dout[15:8] : vram_dout[7:0]) : 8'h00;
assign st_dout  = { flip, video_en, col0, col_cfg };

always @* begin
    yram_cs = 0;
    cfg_cs  = 0;
    if( vctrl_cs ) case( cpu_addr[9:8] )
        0,1,2: yram_cs = 1;
        3: cfg_cs  = 1;
        default:;
    endcase
end

always @(posedge clk, posedge rst) begin
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
        if( cfg_cs  ) cfg[ cpu_addr[1:0] ] <= cpu_dout;
        if( vflag_cs ) flag <= cpu_dout;
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
    .page       ( tm_page ^ ~obj_bufb),

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

reg  [9:0] dma_addr;
reg        LVBLl;
reg        dma_st;
reg        dma_obj = 0;
reg        dma_tm = 0;
reg        dma_start = 0;
wire       dma_bsy = dma_obj | dma_tm;

// DMA when cfg[1][5] == 0
// Sprite DMA starts with VBLANK
// Tilemap DMA starts with writing to cfg[1]
always @(posedge clk) begin
    if (cfg_cs && cpu_addr[1:0] == 1 && !cpu_rnw && !cpu_dout[5]) dma_start <= 1;
    LVBLl <= LVBL;

    if (~obj_bufb && LVBLl && !LVBL) begin
        // Start sprite dma_bsy
        dma_addr <= 0;
        dma_obj <= 1;
        dma_st <= 0;
    end else if (dma_start && !dma_bsy) begin
        // Start tilemap dma_bsy
        dma_start <= 0;
        dma_addr <= 0;
        dma_tm <= 1;
        dma_st <= 0;
    end else if (dma_bsy && pxl_cen ) begin // executed at 6MHz. Needs confirmation from PCB measurements
        dma_st <= ~dma_st;
        if (!dma_st) begin
            // read phase
            ;
        end else begin
            // write phase
            dma_addr <= dma_addr + 1'd1;
            if (&dma_addr) begin
                dma_addr <= 0;
                dma_obj <= 0;
                dma_tm <= 0;
            end
        end
    end
end

jtframe_dual_ram16 #(.AW(12),
    .SIMFILE_LO("vram_lo.bin"),
    .SIMFILE_HI("vram_hi.bin")
) u_vram(
    .clk0   ( clk_cpu    ),
    .clk1   ( clk        ),
    // Main CPU
    // probably the CPU should be WAIT-ed during DMA access, but it's
    // very fast, thus there's no overlap with CPU VRAM access
    .addr0  ( dma_bsy ? {dma_tm ^ tm_page ^ dma_st, dma_tm, dma_addr} : cpu_addr[11:0] ),
    .data0  ( dma_bsy ? vram_dout : {2{cpu_dout}}  ),
    .we0    ( dma_bsy ? {2{dma_st}} : vram_we ),
    .q0     ( vram_dout  ),
    // GFX
    .addr1  ( code_addr  ),
    .data1  ( 16'd0      ),
    .we1    ( 2'd0       ),
    .q1     ( code_dout  )
);

// This memory is internal to the SETA-X1-001 chip
// this is called spriteylow by MAME
jtframe_dual_ram #(.AW(10),.SIMFILE("col.bin")) u_yram(
    .clk0   ( clk_cpu    ),
    .clk1   ( clk        ),
    // Main CPU
    .addr0  (cpu_addr[9:0]),
    .data0  ( cpu_dout   ),
    .we0    ( yram_we    ),
    .q0     ( yram_dout  ),
    // GFX
    .addr1  ( col_addr   ),
    .data1  ( 8'd0       ),
    .we1    ( 1'd0       ),
    .q1     ( col_data   )
);

endmodule