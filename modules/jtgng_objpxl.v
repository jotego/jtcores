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

// Object Line Buffer

module jtgng_objpxl #(parameter dw=4,obj_dly = 5'hc,palw=0)(
    input              rst,
    input              clk,     // 24 MHz
    input              cen6,    //  6 MHz
    // screen
    input              DISPTM_b,
    input              LHBL,
    input              flip,
    input       [4:0]  objcnt,
    input       [3:0]  pxlcnt,
    input       [8:0]  posx,
    input              line,
    // pixel data
    input       [dw-1:0]  new_pxl,
    output reg  [dw-1:0]  obj_pxl
);

localparam lineA=1'b0, lineB=1'b1;

// Line colour buffer

reg [7:0] addrA, addrB;
reg [7:0] Hcnt;

wire [dw-1:0] lineA_q, lineB_q;
reg  [dw-1:0] dataA, dataB;
reg weA, weB;

reg pxlbuf_line;

always @(posedge clk)
    if( rst )
        pxlbuf_line <= lineA;
    else if(cen6) begin
        if( {objcnt[0],pxlcnt}== obj_dly ) pxlbuf_line<=line; // to account for latency drawing the object
    end

always @(posedge clk) if(cen6) begin
    if( !LHBL ) Hcnt <= 8'd0;
    else Hcnt <= Hcnt+1'd1;
end

wire [dw-1:0] blank = {dw{1'b1}};

reg [7:0]    addr_wr;
reg [dw-1:0] data_wr;
reg we_pxl, we0;

//wire we_pxl = !posx[8] && (new_pxl[dw-palw-1:0]!=blank[dw-palw-1:0]); // && !DISPTM_b && LHBL;

always @(posedge clk) if(cen6) begin
    data_wr <= new_pxl;
    addr_wr <= {8{flip}} ^ posx[7:0];
    we_pxl  <= !posx[8] && (new_pxl[dw-palw-1:0]!=blank[dw-palw-1:0]); // && !DISPTM_b && LHBL;
    //we_pxl  <= we0;
end

always @(*)
    if( pxlbuf_line == lineA ) begin
        obj_pxl = !DISPTM_b ? lineA_q : blank;
        // lineA readout
        addrA = Hcnt;
        weA   = 1'b1;
        dataA = blank;
        // lineB writein
        addrB = addr_wr;
        weB   = we_pxl;
        dataB = data_wr;
    end else begin
        obj_pxl = !DISPTM_b ? lineB_q : blank;
        // lineA writein
        addrA = addr_wr;
        weA   = we_pxl;
        dataA = data_wr;
        // lineB readout
        addrB = Hcnt;
        weB   = 1'b1;
        dataB = blank;
    end

jtgng_ram #(.aw(8),.dw(dw),.cen_rd(0)) lineA_buf(
    .clk     ( clk             ),
    .cen     ( cen6            ),
    .addr    ( addrA           ),
    .data    ( dataA           ),
    .we      ( weA             ),
    .q       ( lineA_q         )
);

jtgng_ram #(.aw(8),.dw(dw),.cen_rd(0)) lineB_buf(
    .clk     ( clk             ),
    .cen     ( cen6            ),
    .addr    ( addrB           ),
    .data    ( dataB           ),
    .we      ( weB             ),
    .q       ( lineB_q         )
);

endmodule // jtgng_objpxl