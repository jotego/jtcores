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
    Date: 1-3-2019 */

`timescale 1ns/1ps

module jt1943_objdraw(
    input              rst,
    input              clk,     // 24 MHz
    input              cen6,    //  6 MHz
    input              OBJON,
    // screen
    input       [7:0]  VF,
    input       [3:0]  pxlcnt,
    output reg  [8:0]  posx,
    input              pause,
    // per-line sprite data
    input       [4:0]  objcnt,
    input       [7:0]  objbuf_data,
    // SDRAM interface
    output  reg [16:0] obj_addr,
    input       [15:0] objrom_data,
    // Palette PROM
    input   [7:0]      prog_addr,
    input              prom_7c_we,
    input              prom_8c_we,
    input   [3:0]      prog_din,
    // pixel data
    output reg  [7:0]  new_pxl
);

// No HFLIP or VFLIP on this game

reg [7:0] ADlow;
reg [3:0] objpal0, objpal;
reg [2:0] ADhigh;
reg [7:0] objy;
reg [8:0] objx, posx1, posx2;
reg [7:0] VB;
wire [7:0] posy;
reg  hover;
reg vinzone;

always @(*) begin
    VB = VF-objy;
    vinzone = (VF>=objy) && (VF<(objy+8'd16));
end

always @(posedge clk) if(cen6) begin
    case( pxlcnt[3:0] )
        4'd0: ADlow   <= objbuf_data;
        4'd1: begin
            ADhigh    <= objbuf_data[7:5];
            hover     <= objbuf_data[4];
            objpal0   <= objbuf_data[3:0];
        end
        4'd2: begin
            objy <= (objbuf_data-8'd2);
        end
        4'd3: begin
            objx <= { hover, objbuf_data };
        end
        default:;
    endcase
    if( pxlcnt[1:0]==2'd3 ) begin
        obj_addr <= (!vinzone || objcnt==5'd0) ? 17'd0 :
            { ADhigh, ADlow, VB[3:0],  pxlcnt[3:2] };
    end
end


// ROM data depacking
// new ROM data is expected at pxlcnt 7, so there is an 8-pixel latency

reg [3:0] z,y,x,w;

wire [3:0] new_col;
assign new_col = { w[3],x[3],y[3],z[3] };

wire [7:0] pal_addr = { objpal, new_col };
wire [7:0] prom_dout;

wire [15:0] avatar_data;
reg  [ 7:0] avatar_pxl;

always @(posedge clk ) if(cen6) begin
    posx2 <= posx1; // 1-clk delay to match the PROM data
    if( OBJON ) begin
        new_pxl <= pause ? avatar_pxl : prom_dout;
        posx    <= posx2;
    end else begin
        new_pxl <= 4'hf;
        posx    <= 9'h100;
    end
end

`ifdef AVATARS
// Alternative Objects during pause
jtgng_ram #(.dw(16), .aw(12), .synfile("avatar.hex"),.cen_rd(1))u_avatars(
    .clk    ( clk            ),
    .cen    ( pause          ),  // tiny power saving when not in pause
    .data   ( 16'd0          ),
    .addr   ( obj_addr[11:0] ),
    .we     ( 1'b0           ),
    .q      ( avatar_data    )
);

// avatar image does not use the PROMs here
always @(posedge clk) if(cen6)
    avatar_pxl <= { objpal, z[3], y[3], x[3], w[3] };
`else
assign avatar_data=16'd0;
`endif


always @(posedge clk) if(cen6) begin
    if( pxlcnt[3:0]==4'h7 ) begin
        objpal <= objpal0;
        posx1  <= objx;
    end else begin
        posx1  <= posx1 + 9'b1;
    end
    case( pxlcnt[1:0] )
        2'd3:  // new data starts at count 7
                {z,y,x,w} <= pause ? avatar_data : objrom_data;
        default: begin
                z <= z << 1;
                y <= y << 1;
                x <= x << 1;
                w <= w << 1;
            end
    endcase
end


jtgng_prom #(.aw(8),.dw(4),
    .simfile("../../../rom/1943/bm7.7c")
) u_prom_msb(
    .clk    ( clk            ),
    .cen    ( cen6           ),
    .data   ( prog_din       ),
    .rd_addr( pal_addr       ),
    .wr_addr( prog_addr      ),
    .we     ( prom_7c_we     ),
    .q      ( prom_dout[7:4] )
);

jtgng_prom #(.aw(8),.dw(4),
    .simfile("../../../rom/1943/bm8.8c")
) u_prom_lsb(
    .clk    ( clk            ),
    .cen    ( cen6           ),
    .data   ( prog_din       ),
    .rd_addr( pal_addr       ),
    .wr_addr( prog_addr      ),
    .we     ( prom_8c_we     ),
    .q      ( prom_dout[3:0] )
);


endmodule // jtgng_objdraw