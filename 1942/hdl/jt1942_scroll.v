/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 20-1-2019 */

// 1942 Scroll Generation
// Schematics pages 02A-1/8, 2/8, 3/8

`timescale 1ns/1ps

module jt1942_scroll(
    input              clk,     // 24 MHz
    input              cen6  /* synthesis direct_enable = 1 */,    //  6 MHz
    input              cen3,
    input       [ 9:0] AB,
    input       [ 7:0] V128, // V128-V1
    input       [ 8:0] H, // H256-H1
    input              scr_cs,
    input       [ 1:0] scrpos_cs,
    output             busy,
    input              flip,
    input       [ 7:0] din,
    output      [ 7:0] dout,
    input              rd_n,
    input              wr_n,

    // Palette PROMs D1, D2
    input   [2:0]      scr_br,
    input   [7:0]      prog_addr,
    input              prom_d1_we,
    input              prom_d2_we,
    input              prom_d6_we,
    input   [3:0]      prom_din,

    // ROM
    output reg  [13:0] scr_addr,
    input       [23:0] scrom_data,
    output      [ 5:0] scr_pxl
);

reg [2:0] scr_col0;
reg [4:0] scr_pal0;

parameter HOFFSET=9'd5;

wire [8:0] Hfix = H + HOFFSET; // Corrects pixel output offset
reg  [ 8:0] HS;
wire [ 7:0] VF = {8{flip}}^V128;
wire [ 7:0] HF = {8{flip}}^Hfix[7:0];
reg  [ 8:0] hpos=9'd0;

wire H7 = (~Hfix[8] & (~flip ^ HF[6])) ^HF[7];

reg [2:0] HSaux;

always @(*) begin
    { HS[8:3], HSaux } = hpos + { ~Hfix[8], H7, HF[6:0]};
    HS[2:0] = HSaux ^ {3{flip}};
end

wire [8:0] scan = { HS[8:4], VF[7:4] };
reg sel_scan;
always @(posedge clk)
    if(cen6) begin
        if( HS[2:0] == 3'b111 )
            sel_scan <= 1'b1;
        if( HS[2:0] == 3'b011 )
            sel_scan <= 1'b0;
    end
assign busy = sel_scan;
wire [8:0]  addr = sel_scan ? scan : { AB[9:5], AB[3:0]}; // AB[4] selects between low and high RAM
wire we = !sel_scan && scr_cs && !wr_n;

always @(posedge clk) if(cen3) begin
    if( scrpos_cs[1] ) hpos[8]   <= din[0];
    if( scrpos_cs[0] ) hpos[7:0] <= din;
end

wire [7:0] dout_low, dout_high;
wire we_low  = we && !AB[4];
wire we_high = we &&  AB[4];
assign dout = AB[4] ? dout_high : dout_low;

jtgng_ram #(.aw(9),.simfile("zeros512.bin")) u_ram_tile(
    .clk    ( clk      ),
    .cen    ( cen3     ),
    .data   ( din      ),
    .addr   ( addr     ),
    .we     ( we_low   ),
    .q      ( dout_low )
);

jtgng_ram #(.aw(9),.simfile("zeros512.bin")) u_ram_att(
    .clk    ( clk      ),
    .cen    ( cen3     ),
    .data   ( din      ),
    .addr   ( addr     ),
    .we     ( we_high  ),
    .q      ( dout_high)
);

reg scr_hflip;
reg [7:0] addr_lsb;

reg [5:0] scr_attr0, scr_attr1;

// Set input for ROM reading
always @(posedge clk) if(cen6) begin
    if( HS[2:0]==3'd1 ) begin // dout_high/low data corresponds to this tile
            // from HS[2:0] = 1,2,3...0. because RAM output is latched
        scr_attr1 <= scr_attr0;
        scr_attr0 <= dout_high[5:0];
        scr_addr  <= {   dout_high[7], dout_low, // AS
                        HS[3]^dout_high[5] /*scr_hflip*/,
                        {4{dout_high[6] /*vflip*/}}^VF[3:0] /*vert_addr*/ };
    end
end

// Draw pixel on screen
reg [7:0] x,y,z;
reg [4:0] scr_attr2;

always @(posedge clk) if(cen6) begin
    // new tile starts 8+5=13 pixels off
    // 8 pixels from delay in ROM reading
    // 4 pixels from processing the x,y,z and attr info.
    if( HS[2:0]==3'd2 ) begin
            { z,y,x } <= scrom_data;
            scr_hflip <= scr_attr1[5] ^ flip; // must be ready when z,y,x are.
            scr_attr2 <= scr_attr1[4:0];
        end
    else
        begin
            if( scr_hflip ) begin
                x <= {1'b0, x[7:1]};
                y <= {1'b0, y[7:1]};
                z <= {1'b0, z[7:1]};
            end
            else  begin
                x <= {x[6:0], 1'b0};
                y <= {y[6:0], 1'b0};
                z <= {z[6:0], 1'b0};
            end
        end
    scr_col0  <= scr_hflip ? { x[0], y[0], z[0] } : { x[7], y[7], z[7] };
    scr_pal0  <= scr_attr2;
end

wire [7:0] pal_addr;
assign pal_addr[7] = 1'b0;
assign pal_addr[6:4] = scr_br[2:0];

// Palette
jtgng_prom #(.aw(8),.dw(2),.simfile("../../../rom/1942/sb-2.d1")) u_prom_d1(
    .clk    ( clk            ),
    .cen    ( cen6           ),
    .data   ( prom_din[1:0]  ),
    .rd_addr( pal_addr       ),
    .wr_addr( prog_addr      ),
    .we     ( prom_d1_we     ),
    .q      ( scr_pxl[5:4]   )
);

jtgng_prom #(.aw(8),.dw(4),.simfile("../../../rom/1942/sb-3.d2")) u_prom_d2(
    .clk    ( clk            ),
    .cen    ( cen6           ),
    .data   ( prom_din       ),
    .rd_addr( pal_addr       ),
    .wr_addr( prog_addr      ),
    .we     ( prom_d2_we     ),
    .q      ( scr_pxl[3:0]   )
);

jtgng_prom #(.aw(8),.dw(4),.simfile("../../../rom/1942/sb-4.d6")) u_prom_d6(
    .clk    ( clk            ),
    .cen    ( cen6           ),
    .data   ( prom_din       ),
    .rd_addr( {scr_pal0, scr_col0} ),
    .wr_addr( prog_addr      ),
    .we     ( prom_d6_we     ),
    .q      ( pal_addr[3:0]  )
);


endmodule // jtgng_scroll