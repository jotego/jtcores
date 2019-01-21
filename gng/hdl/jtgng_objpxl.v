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
    Date: 11-1-2019 */

module jtgng_objpxl(
    input              rst,
    input              clk,     // 24 MHz
    input              cen6,    //  6 MHz
    // screen
    input              LHBL,    
    input              flip,
    input       [3:0]  pxlcnt,
    input       [8:0]  posx,
    input              line,
    // pixel data
    input       [1:0]  pospal,
    input       [3:0]  new_pxl,
    output reg  [5:0]  obj_pxl
);

localparam lineA=1'b0, lineB=1'b1;

// Line colour buffer

reg [7:0] lineA_address_a, lineA_address_b;
reg [7:0] lineB_address_a, lineB_address_b;
reg [7:0] Hcnt;

wire [7:0] lineA_q_a, lineA_q_b;
wire [7:0] lineB_q_a, lineB_q_b;
wire [7:0] lineX_data = { 2'b11, pospal, new_pxl };

reg lineA_we_a, lineB_we_a, lineA_we_b, lineB_we_b;

reg pxlbuf_line;

always @(posedge clk)
    if( rst )
        pxlbuf_line <= lineA;
    else if(cen6) begin
        if( pxlcnt== 4'hf ) pxlbuf_line<=line; // to account for latency drawing the object
    end

always @(posedge clk) if(cen6) begin
    if( !LHBL ) Hcnt <= 8'd0;
    else Hcnt <= Hcnt+1'd1;
end

always @(*)
    if( pxlbuf_line == lineA ) begin 
        // lineA readout
        lineA_address_a = Hcnt;
        lineA_we_a = 1'b0;
        obj_pxl = lineA_q_a[5:0];
        // lineB writein
        lineB_address_a = {8{flip}} ^ posx[7:0];
        lineB_we_a = !posx[8] && (lineX_data[3:0]!=4'hf);
    end else begin
        // lineA writein
        lineA_address_a = {8{flip}} ^ posx[7:0];
        lineA_we_a = !posx[8] && (lineX_data[3:0]!=4'hf);
        // lineB readout
        lineB_address_a = Hcnt;
        lineB_we_a = 1'b0;
        obj_pxl = lineB_q_a[5:0];
    end

always @(posedge clk) if(cen6) begin
    if( pxlbuf_line == lineA ) begin
        // lineA clear after each pixel is readout
        lineA_address_b <= lineA_address_a;
        lineA_we_b <= 1'b1;
        // lineB port B unused
        lineB_we_b <= 1'b0;
    end
    else begin
        // lineA port A unused
        lineA_we_b <= 1'b0;
        // lineB clear after each pixel is readout
        lineB_address_b <= lineB_address_a;
        lineB_we_b <= 1'b1;
    end
end

jtgng_true_dual_ram #(.aw(8)) lineA_buf(
    .clk     ( clk             ),
    .clk_en  ( cen6            ),
    .addr_a  ( lineA_address_a ),
    .addr_b  ( lineA_address_b ),
    .data_a  ( lineX_data      ),
    .data_b  ( 8'hFF           ), // delete only
    .we_a    ( lineA_we_a      ),
    .we_b    ( lineA_we_b      ),
    .q_a     ( lineA_q_a       ),
    .q_b     (                 )
);

jtgng_true_dual_ram #(.aw(8)) lineB_buf(
    .clk     ( clk             ),
    .clk_en  ( cen6            ),
    .addr_a  ( lineB_address_a ),
    .addr_b  ( lineB_address_b ),
    .data_a  ( lineX_data      ),
    .data_b  ( 8'hFF           ), // delete only
    .we_a    ( lineB_we_a      ),
    .we_b    ( lineB_we_b      ),
    .q_a     ( lineB_q_a       ),
    .q_b     (                 )
);

endmodule // jtgng_objpxl