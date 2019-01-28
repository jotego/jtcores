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
    Date: 21-1-2019 */

module jtgng_objdraw(
    input              rst,
    input              clk,     // 24 MHz
    input              cen6,    //  6 MHz
    // screen
    input              flip,
    input       [7:0]  V,
    input       [8:0]  H,
    input       [3:0]  pxlcnt,
    // per-line sprite data
    input       [7:0]  objbuf_data,
    // SDRAM interface
    output reg  [13:0] obj_addr,
    input       [15:0] objrom_data,
    // Palette PROM
    input   [7:0]      prog_addr,
    input              prom_k3_we,
    input   [3:0]      prog_din,
    // pixel data
    output reg  [8:0]  posx,
    output      [3:0]  new_pxl
);

reg [7:0] AD;
reg [3:0] CD; // colour data
reg [7:0] objy, objx;
reg [7:0] V2C;
wire [7:0] VF = {8{flip}} ^V;
wire [8:0] objx2;
reg vover, hover;
wire posvflip, poshflip;
reg vinzone;
wire vinzone2;

reg [1:0] vlen;
wire [7:0] LVBETA = objbuf_data + V2C;
wire [7:0] VBETA = ~LVBETA;
reg VINcmp, VINlen, Vgt, Veq, Vlt;
reg [3:0] preCD;

always @(*) begin
    V2C = ~VF + { {7{~flip}}, 1'b1 }; // V 2's complement
    // comparison side of VINZONE
    Vgt = VBETA  > ~objbuf_data;
    Veq = VBETA == ~objbuf_data;
    Vlt = VBETA  < ~objbuf_data;
    VINcmp = ((Vlt|Veq) & ~vover) | (Vgt&vover);
    VINlen = (|{vlen, LVBETA[4]}) & (vlen[1]|LVBETA[5]) & ((&vlen[1:0]) | LVBETA[6]) & ((&vlen[1:0]) | LVBETA[7] );
end

always @(posedge clk)
    if( cen6 ) begin
        case( pxlcnt[3:0] )
            4'd0: AD <= objbuf_data;
            4'd1: begin
                vlen  <= objbuf_data[7:6];
                vover <= objbuf_data[5];
                hover <= objbuf_data[4];
                preCD <= objbuf_data[3:0];
            end
            4'd3: begin
                obj_addr[13:10] <= AD[7:4];
                case( vlen )
                    2'd0: obj_addr[9:6] <= AD[3:0];
                    2'd1: obj_addr[9:6] <= { AD[3:1], VBETA[4] };
                    2'd2: obj_addr[9:6] <= { AD[3:2], VBETA[5:4] };
                    2'd3: obj_addr[9:6] <= VBETA[7:4];
                endcase
                obj_addr[4:1] <= VBETA[3:0];
                vinzone <= ~(VINcmp & VINlen);
                { obj_addr[5], obj_addr[0] } <= 2'd0;
            end
            4'd7:  { obj_addr[5], obj_addr[0] } <= 2'd1;
            4'd11: { obj_addr[5], obj_addr[0] } <= 2'd2;
            4'd15: { obj_addr[5], obj_addr[0] } <= 2'd3;
        endcase
    end

jtgng_sh #(.width(1), .stages(4)) sh_objz (.clk(clk), .clk_en(cen6), .din(vinzone), .drop(vinzone2));

// ROM data depacking

reg  [3:0] z,y,x,w;
reg  [3:0] obj_wxyz;
wire [7:0] pal_addr = { CD, obj_wxyz};

always @(posedge clk) if(cen6) begin
    obj_wxyz <= {w[3],x[3],y[3],z[3]};   
    posx     <= pxlcnt[3:0]==4'h8 ? objbuf_data : posx + 1'b1;
    if( pxlcnt==4'd8 ) CD <= vinzone2 ? preCD : 4'hf;
    case( pxlcnt[3:0] )        
        4'd3,4'd7,4'd11,4'd15:  begin // new data
            {z,y,x,w} <= vinzone2 ? objrom_data[15:0] : 16'hffff;
        end
        default: 
            if( poshflip ) begin
                z <= z >> 1;
                y <= y >> 1;
                x <= x >> 1;
                w <= w >> 1;
            end else begin
                z <= z << 1;
                y <= y << 1;
                x <= x << 1;
                w <= w << 1;
            end
    endcase
end

jtgng_prom #(.aw(8),.dw(4),.simfile("../../../rom/1942/sb-8.k3")) u_prom_k3(
    .clk    ( clk            ),
    .cen    ( cen6           ),
    .data   ( prog_din       ),
    .rd_addr( pal_addr       ),
    .wr_addr( prog_addr      ),
    .we     ( prom_k3_we     ),
    .q      ( new_pxl        )
);


endmodule // jtgng_objdraw