/*  This file is part of JTKICKER.
    JTKICKER program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTKICKER program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTKICKER.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 27-3-2022 */

module jtpinpon_char(
    input               rst,
    input               clk,        // 48 MHz
    input               clk24,      // 24 MHz

    input               pxl_cen,

    // CPU interface
    input        [10:0] cpu_addr,
    input         [7:0] cpu_dout,
    input               cpu_rnw,
    input               vram_cs,
    output        [7:0] vram_dout,

    // video inputs
    input               LHBL,
    input         [7:0] vdump,
    input         [8:0] hdump,

    // PROMs
    input         [3:0] prog_data,
    input         [7:0] prog_addr,
    input               prog_en,

    // SDRAM
    output reg   [11:0] rom_addr,
    input        [15:0] rom_data,
    input               rom_ok,

    output        [3:0] pxl
);

localparam BSEL = 10;

wire [ 7:0] code, attr, vram_high, vram_low, pal_addr;
reg  [ 8:0] heff;
reg  [ 4:0] pre_pal, cur_pal;
reg         code_msb;
reg  [15:0] pxl_data;
wire [ 9:0] rd_addr;
reg         cur_hf;
wire        vram_we_low, vram_we_high;
reg         vflip, hflip;
wire        vram_we;
reg  [ 9:0] eff_addr;

assign vram_we      = vram_cs & ~cpu_rnw;
assign vram_we_low  = vram_we & ~cpu_addr[BSEL];
assign vram_we_high = vram_we &  cpu_addr[BSEL];
assign vram_dout    = cpu_addr[BSEL] ? vram_high : vram_low;

always @* begin
    heff = hdump+9'd4;
    if( !LHBL ) heff[8:4]=0;
    eff_addr = cpu_addr[9:0];
    vflip    = attr[7];
    code_msb = attr[5];
end

assign rd_addr  = { vdump[7:3], heff[7:3] }; // 5+5 = 10
assign pal_addr = { 1'b0, cur_pal,
    cur_hf ? { pxl_data[15], pxl_data[7]} : { pxl_data[8], pxl_data[0] }};

always @(posedge clk) if(pxl_cen) begin
    if( heff[2:0]==0 ) begin
        // request new data
        rom_addr <= { code_msb, code, vdump[2:0]^{3{vflip}} }; // 1+8+3=12 bits
        hflip    <= attr[6];
        pre_pal  <= attr[4:0];
        // collects previously requested data
        pxl_data <= { rom_data[11:8], rom_data[3:0], rom_data[15:12], rom_data[7:4] };
        cur_hf   <= hflip;
        cur_pal  <= pre_pal;
    end else begin
        pxl_data <= cur_hf ? pxl_data<<1 : pxl_data>>1;
    end
end

jtframe_dual_ram #(.simfile("vram_lo.bin")) u_low(
    // Port 0, CPU
    .clk0   ( clk24         ),
    .data0  ( cpu_dout      ),
    .addr0  ( eff_addr      ),
    .we0    ( vram_we_low   ),
    .q0     ( vram_low      ),
    // Port 1
    .clk1   ( clk           ),
    .data1  (               ),
    .addr1  ( rd_addr       ),
    .we1    ( 1'b0          ),
    .q1     ( attr          )
);

jtframe_dual_ram #(.simfile("vram_hi.bin")) u_high(
    // Port 0, CPU
    .clk0   ( clk24         ),
    .data0  ( cpu_dout      ),
    .addr0  ( eff_addr      ),
    .we0    ( vram_we_high  ),
    .q0     ( vram_high     ),
    // Port 1
    .clk1   ( clk           ),
    .data1  (               ),
    .addr1  ( rd_addr       ),
    .we1    ( 1'b0          ),
    .q1     ( code          )
);

jtframe_prom #(
    .dw ( 4     ),
    .aw ( 8     )
//    simfile = "477j09.b8",
) u_palette(
    .clk    ( clk       ),
    .cen    ( pxl_cen   ),
    .data   ( prog_data ),
    .wr_addr( prog_addr ),
    .we     ( prog_en   ),

    .rd_addr( pal_addr  ),
    .q      ( pxl       )
);

endmodule