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

// 1942 Object Line Buffer

module jt1942_objpxl(
    input              rst,
    input              clk,     // 24 MHz
    input              cen6,    //  6 MHz
    // screen
    input              DISPTM_b,
    input              LHBL,    
    input              flip,
    input       [3:0]  pxlcnt,
    input       [8:0]  posx,
    input              line,
    // pixel data
    input       [3:0]  new_pxl,
    output reg  [3:0]  obj_pxl
);
parameter obj_dly = 4'hc;
localparam lineA=1'b0, lineB=1'b1;

// Line colour buffer

reg [7:0] addrA, addrB;
reg [7:0] Hcnt;

wire [3:0] lineA_q, lineB_q;
reg [3:0] dataA, dataB;
reg weA, weB;

reg pxlbuf_line;

always @(posedge clk)
    if( rst )
        pxlbuf_line <= lineA;
    else if(cen6) begin
        if( pxlcnt== obj_dly ) pxlbuf_line<=line; // to account for latency drawing the object
    end

always @(posedge clk) if(cen6) begin
    if( !LHBL ) Hcnt <= 8'd0;
    else Hcnt <= Hcnt+1'd1;
end

wire we_pxl = !posx[8] && (new_pxl!=4'hf); // && !DISPTM_b && LHBL;

always @(*)
    if( pxlbuf_line == lineA ) begin 
        obj_pxl = !DISPTM_b ? lineA_q : 4'hf;
        // lineA readout
        addrA = Hcnt;
        weA   = 1'b1;
        dataA = 4'hF;
        // lineB writein
        addrB = {8{flip}} ^ posx[7:0];
        weB   = we_pxl;
        dataB = new_pxl;
    end else begin
        obj_pxl = !DISPTM_b ? lineB_q : 4'hf;
        // lineA writein
        addrA = {8{flip}} ^ posx[7:0];
        weA   = we_pxl;
        dataA = new_pxl;
        // lineB readout
        addrB = Hcnt;
        weB   = 1'b1;
        dataB = 4'hF;
    end

jtgng_ram #(.aw(8),.dw(4),.cen_rd(1)) lineA_buf(
    .clk     ( clk             ),
    .cen     ( cen6            ),
    .addr    ( addrA           ),
    .data    ( dataA           ),
    .we      ( weA             ),
    .q       ( lineA_q         )
);

jtgng_ram #(.aw(8),.dw(4),.cen_rd(1)) lineB_buf(
    .clk     ( clk             ),
    .cen     ( cen6            ),
    .addr    ( addrB           ),
    .data    ( dataB           ),
    .we      ( weB             ),
    .q       ( lineB_q         )
);

endmodule // jtgng_objpxl