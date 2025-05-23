/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 21-5-2025 */

module jtpaclan_objscan(
    input             clk, hs, blankn,
    input             flip,
    input      [ 8:0] vrender,

    output reg [ 8:0] code,
    output reg        hsize, vsize, hmsb,
    output reg [ 4:0] ysub,
    output reg [ 5:0] pal,
    output reg [ 8:0] hpos,
    output reg        hflip, vflip,

    // Look-up table
    output     [12:1] ram_addr,
    input      [15:0] ram_dout,

    input             dr_busy,
    output            dr_draw,

    input      [ 7:0] debug_bus
);

localparam [8:0] XOS=9'h1f7+9'd4;
localparam [7:0] YOS=8'd24;
localparam    HLARGE=1'b1;

reg  [7:0] y, vos_dr;
reg  [8:0] ydiff;
wire [5:0] objcnt;
wire [8:0] vlatch;
wire [7:0] raw_addr;
wire [1:0] st;
reg  [1:0] hos, vos, hmsb_nx;
reg  [4:0] nx_ysub;
reg        inzone;
wire       draw_step, hsub, cen, hcnt_nx;

assign draw_step = st==3;
assign objcnt    = raw_addr[2+:6];

assign ram_addr[12:11] = st[1:0];
assign ram_addr[10: 7] = 4'b1110;
assign ram_addr[ 6: 1] = objcnt;

always @* begin
    ydiff = vlatch[8:0] + y;
    case( vsize )
        0: inzone = ydiff[8:4]==0; //  16
        1: inzone = ydiff[8:5]==0; //  32
    endcase
    nx_ysub = ydiff[4:0];
end

always @(posedge clk) if(cen) begin
    case(st)
        0: { pal, code[7:0] } <= ram_dout[13:0]; // read from A[12:11]=0
        1: { hpos[7:0], y }   <= ram_dout;       // read from A[12:11]=1
        2: begin
            { code[8], vsize, hsize, vflip, hflip} <= {ram_dout[7],ram_dout[3:1],~ram_dout[0]}; // A[12:11]=2
            y <= y + YOS + (ram_dout[3] ? 8'd16 : 8'd0);
            hpos <= {ram_dout[8],hpos[7:0]}+XOS+{debug_bus[7],debug_bus};
        end
        3: if(!dr_busy && !dr_draw && inzone) begin
            ysub <= nx_ysub;
            hmsb <= 0;
            if( hsize && !hcnt_nx ) begin // half of 32-pxl object
                hpos <= hpos + 9'h10;
                hmsb <= ~hmsb;
            end
        end
    endcase
end

jtframe_objscan #(.OBJW(6),.STW(2),.HREPW(1),.HOLD_WHILE_DRBUSY(1))
u_scan(
    .clk        ( clk       ),
    .cen        ( cen       ),
    .hs         ( hs        ),
    .blankn     ( blankn    ),
    .vrender    ( vrender   ),
    .vlatch     ( vlatch    ),

    .draw_step  ( draw_step ),
    .skip       ( 1'b0      ),
    .inzone     ( inzone    ),

    .hsize      ( hsize     ),
    .hsub       ( hsub      ),
    .haddr      (           ),
    .hflip      ( hflip     ),
    .hcnt_nx    ( hcnt_nx   ),

    .dr_busy    ( dr_busy   ),
    .dr_draw    ( dr_draw   ),

    .addr       ( raw_addr  ),
    .step       ( st        )
);

endmodule