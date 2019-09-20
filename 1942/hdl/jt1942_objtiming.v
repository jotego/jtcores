
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

// 1942 Object Generation

`timescale 1ns/1ps

module jt1942_objtiming(
    input              rst,
    input              clk,
    input              cen6,    //  6 MHz
    // screen
    input   [7:0]      V,
    input   [8:0]      H,
    input              HINIT,
    output reg [3:0]   pxlcnt,
    output reg [4:0]   objcnt,
    output reg         line,
    output             SEATM_b,
    output             DISPTM_b,
    // Timing PROM
    input   [7:0]      prog_addr,
    input              prom_m11_we,
    input   [1:0]      prog_din
);

always @(posedge clk) if(cen6) begin
    if( HINIT ) begin
        pxlcnt <= 4'd0;
    end else begin
        pxlcnt <= pxlcnt+4'd1;
    end
end
//assign pxlcnt = H[3:0];

`ifdef VULGUS
reg [1:0] vulgus_cnt;
always @(posedge clk, posedge rst) 
    if( rst )
        vulgus_cnt <= 2'b0;
    else if(cen6) begin
        if( &H[6:4]==1'b1 && pxlcnt==4'd7 ) vulgus_cnt <= vulgus_cnt==2'b10 ? 2'b00 : (vulgus_cnt+2'b1);
    end
`endif

always @(*) begin
    // This is the original scan sequence of each game, that counts objects
    `ifdef VULGUS
        // scan sequence measured on real PCB. Region objcnt[4:3]==2'b11 is not scanned.
        case( vulgus_cnt )
            2'b00: objcnt[4:3] = 2'b01;
            default: objcnt[4:3] = 2'b00;
            2'b10: objcnt[4:3] = 2'b10;
        endcase // vulgus_cnt
        objcnt[2:0] = H[6:4];
    `else 
        // 1942 scan sequence from schematics
        objcnt[4] = H[8]^~H[7];
        objcnt[3] = (V[7] & objcnt[4]) ^ ~H[7];
        objcnt[2:0] = H[6:4];
    `endif
end


always @(posedge clk)
    if( rst )
        line <= 1'b0;
    else if(cen6) begin
        if( HINIT ) line <= ~line;
    end

wire pre_SEATM;

jtgng_sh #(.width(1), .stages(8)) u_sh(
    .clk            ( clk           ),
    .clk_en         ( cen6          ),
    .din            ( pre_SEATM     ),
    .drop           ( SEATM_b       )
);

jtgng_prom #(.aw(8),.dw(2),
    .simfile("../../../rom/1942/sb-9.m11")
    ) u_prom_m11(
    .clk    ( clk            ),
    .cen    ( cen6           ),
    .data   ( prog_din       ),
    .rd_addr( V[7:0]         ),
    .wr_addr( prog_addr      ),
    .we     ( prom_m11_we    ),
    .q      ( {DISPTM_b, pre_SEATM} )
);

endmodule // jt1942_obj