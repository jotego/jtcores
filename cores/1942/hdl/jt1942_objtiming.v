
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
    input              LHBL,
    input              HINIT,
    input              obj_ok,    
    output reg [3:0]   pxlcnt,
    output reg [4:0]   objcnt,
    output reg [3:0]   bufcnt,
    output reg         line,
    output reg         pxlcnt_lsb,
    output reg         over,
    // Timing PROM
    input   [7:0]      prog_addr,
    input              prom_m11_we,
    input   [1:0]      prog_din
);

`ifdef VULGUS
localparam VULGUS=1;
`else
localparam VULGUS=0;
`endif

reg last_LHBL, okdly;
wire rom_good = obj_ok & okdly;
wire posedge_LHBL = LHBL && !last_LHBL;

always @(posedge clk) begin
    last_LHBL <= LHBL;
    okdly     <= obj_ok;
    if( posedge_LHBL ) begin
        pxlcnt    <= 4'd0;
        objcnt    <= 5'd0;
        over      <= 1'b0;
        bufcnt    <= 3'b0;
        pxlcnt_lsb       <= 1'b0;
    end else begin // image scan
        if(bufcnt!=4'b1010) 
            bufcnt <= bufcnt+4'd1;
        else if(rom_good && !over ) begin
            {pxlcnt, pxlcnt_lsb} <= {pxlcnt,pxlcnt_lsb}+5'd1;
            if( &{pxlcnt,pxlcnt_lsb} ) begin
                bufcnt <= 4'd0;
                if( VULGUS ) begin
                    over   <= objcnt == 5'h17;
                    objcnt <= objcnt + 5'h1;
                end else begin // 1942
                    objcnt <= (objcnt == 5'h0f && V[7]) ? 5'h18 : objcnt+5'h1;
                    over   <= objcnt == 5'h1f || (objcnt==5'h17 && !V[7]);
                end
            end
        end
        else if(!rom_good) pxlcnt_lsb <= 1'b0;
    end
end

always @(posedge clk) begin
    if( rst )
        line <= 1'b0;
    else if(cen6) begin
        if( HINIT ) line <= ~line;
    end
end

// Not the whole RAM is read for producing objects
// 1942: left part of the vertical screen (V[7]==1) objects 18-1F
//       right part                                 objects 10-17
//       whole screen                               objects 0-0F
// Vulgus: objects 0 to 17 only

/* Original sequence
`ifdef VULGUS
reg vulgus_sr;
always @(posedge clk, posedge rst) 
    if( rst ) begin
        vulgus_sr  <= 1'b1;
        objcnt[4:3] <= 2'b0;
    end else if(cen6) begin
        if( &H[6:4]==1'b1 && pxlcnt==4'd7 ) begin
            { vulgus_sr, objcnt[4:3] } <= { objcnt[4:3], vulgus_sr };
        end
    end
`endif
always @(*) begin
    // This is the original scan sequence of each game, that counts objects
    `ifdef VULGUS
        // scan sequence measured on real PCB. Region objcnt[4:3]==2'b11 is not scanned.
        objcnt[2:0] = H[6:4];
    `else 
        // 1942 scan sequence from schematics
        objcnt[4] = H[8]^~H[7];
        objcnt[3] = (V[7] & objcnt[4]) ^ ~H[7];
        objcnt[2:0] = H[6:4];
    `endif
end
*/

endmodule // jt1942_obj