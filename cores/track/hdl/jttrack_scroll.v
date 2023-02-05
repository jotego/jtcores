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
    Date: 19-3-2022 */

module jttrack_scroll(
    input               rst,
    input               clk,        // 48 MHz
    input               clk24,      // 24 MHz

    input               pxl_cen,

    // CPU interface
    input        [11:0] cpu_addr,
    input         [7:0] cpu_dout,
    input               cpu_rnw,
    input               vram_cs,
    output        [7:0] vram_dout,

    // Row scroll
    input         [8:0] hpos,

    // video inputs
    input               LHBL,
    input         [7:0] vdump,
    input         [8:0] hdump,
    input               flip,

    // PROMs
    input         [3:0] prog_data,
    input         [7:0] prog_addr,
    input               prog_en,

    // SDRAM
    output reg   [12:0] rom_addr,
    input        [31:0] rom_data,
    input               rom_ok,

    output        [3:0] pxl,
    input         [7:0] debug_bus
);

wire [ 7:0] code, attr, vram_high, vram_low, pal_addr;
reg  [ 3:0] pal_msb;
reg  [ 3:0] cur_pal;
reg  [ 1:0] code_msb;
reg  [31:0] pxl_data;
reg  [10:0] rd_addr;
reg  [ 7:0] vf;
reg  [ 8:0] hsum, heff;
reg         cur_hf;
wire        vram_we_low, vram_we_high;
reg         vflip, hflip;
wire        vram_we;
wire [10:0] eff_addr;

assign vram_we      = vram_cs & ~cpu_rnw;
assign vram_we_low  = vram_we & ~cpu_addr[11];
assign vram_we_high = vram_we &  cpu_addr[11];
assign vram_dout    = cpu_addr[11] ? vram_high : vram_low;
assign eff_addr     = cpu_addr[10:0];

always @* begin
    hsum = hpos + ( LHBL ? hdump : { ~6'h0, hdump[2:0]} ) - {8'd0,flip} + 9'd8;
    heff = hsum ^ {1'b0,{8{flip}}};
    code_msb = attr[7:6];
    vflip    = attr[5];
end


assign pal_addr =
    { cur_pal, cur_hf ? pxl_data[3:0] : pxl_data[31:28] };

// scroll register in custom chip 085
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        vf   <= 0;
        rd_addr <= 0;
    end else begin
        if( pxl_cen && heff[2:0]==7 ) begin
            rd_addr <= { vf[7:3], heff[8:3] }; // 5+6 = 11
        end
        vf <= {8{flip}} ^ vdump;
    end
end

always @(posedge clk) if(pxl_cen) begin
    if( heff[2:0]==0 ) begin
        rom_addr <= { code_msb, code, vf[2:0]^{3{vflip}} }; // 2+8+3=13 bits
        pal_msb  <= attr[3:0];
        hflip    <= attr[4]^flip;
    end
    if( heff[2:0]==4 ) begin // 2 pixel delay to grab data
        pxl_data <= rom_data;
        cur_hf   <= hflip;
        cur_pal  <= pal_msb;
    end else begin
        pxl_data <= cur_hf ? pxl_data>>4 : pxl_data<<4;
    end
end

jtframe_dual_ram #(.simfile("vram_lo.bin"),.aw(11)) u_low(
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
    .q1     ( code          )
);

jtframe_dual_ram #(.simfile("vram_hi.bin"),.aw(11)) u_high(
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
    .q1     ( attr          )
);

jtframe_prom #(
    .dw ( 4     ),
    .aw ( 8     )
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