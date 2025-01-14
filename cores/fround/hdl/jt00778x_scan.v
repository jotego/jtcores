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
    Date: 30-12-2024 */

module jt00778x_scan#(parameter CW=17,PW=10)(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             hs,
    input      [ 8:0] vdump,

    input             gvflip,

    output     [10:1] scan_addr,
    input      [15:0] scan_dout,

    // draw module
    output reg [CW-1:0] code,
    output reg [   3:0] attr,
    output reg          hflip,
    output reg [PW-1:0] hpos,
    output reg [   1:0] hsize,
    output reg        dr_start,
    input             dr_busy
);

reg         vflip;
reg  [ 1:0] vsize;
reg  [15:0] y;
reg  [ 8:0] ydiff, vlatch;
reg         inzone, hs_l, done, busy_l, skip;
wire        busy_g, valid_y;
reg  [ 6:0] ydf;
reg  [ 2:0] st;
reg  [ 7:0] objcnt;

assign scan_addr = {objcnt,st[1:0]};
assign busy_g    = busy_l | dr_busy;
assign valid_y   = y<16'h180 || y>=16'hff00;

(* direct_enable *) reg cen2=0;
always @(negedge clk) cen2 <= ~cen2;

// Table scan
always @* begin
    ydiff = vlatch - y[8:0];
    case( vsize )
        0: inzone = ydiff[8:4]==0; //  16
        1: inzone = ydiff[8:5]==0; //  32
        2: inzone = ydiff[8:6]==0; //  64
        3: inzone = ydiff[8:7]==0; // 128
    endcase
end

// code
// EDCBEA9876543210VVVV   16 pixel wide
// EDCBEA987654321VVVVH   32 pixel wide
// EDCBEA98765432VVVVHH   64 pixel wide
// EDCBEA9876543VVVVHHH   64 pixel wide
// EDCBEA987654321VVVVH   32x16
// EDCBEA98765432VVVVVH   32x32
// EDCBEA987654VVVVVVHH   64x64

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        hs_l     <= 0;
        objcnt <= 0;
        st <= 0;
        code     <= 0;
        attr     <= 0;
        vflip    <= 0;
        hflip    <= 0;
        busy_l   <= 0;
    end else if( cen2 ) begin
        hs_l <= hs;
        busy_l <= dr_busy;
        dr_start <= 0;
        if( hs && !hs_l && vdump>9'h10D && vdump<9'h1f1) begin
            done     <= 0;
            objcnt <= 0;
            st <= 0;
            vlatch   <= (vdump^{1'b1,{8{gvflip}}});
        end else if( !done ) begin
            st <= st + 1'd1;
            case( st )
                1: hpos <= scan_dout[PW-1:0]+ {{PW-9{1'b0}},9'h69};
                2: begin
                    y <= 0;
                    y[PW-1:0] <=  scan_dout[PW-1:0] + {{PW-9{1'b0}},9'h1f-9'h20};
                end
                3: begin
                    skip <= ~scan_dout[15] && valid_y;
                    if( scan_dout[14] ) begin
                        done <= 1;
                    end
                    { vflip, hflip, vsize, hsize, attr } <= scan_dout[9:0];
                end
                4: begin
                    code[CW-1:4] <= scan_dout[0+:CW-4];
                    code[3:0] <= 0;
                    ydf <= ydiff[6:0]^{7{vflip}};
                end
                5: begin
                    // Add the vertical offset to the code
                    case( vsize )
                        0: code[ {3'd0,hsize} +: 4 ] <= ydf[3:0];
                        1: code[ {3'd0,hsize} +: 5 ] <= ydf[4:0];
                        2: code[ {3'd0,hsize} +: 6 ] <= ydf[5:0];
                        3: code[ {3'd0,hsize} +: 7 ] <= ydf[6:0];
                    endcase
                    if( !inzone || skip ) begin
                        st <= 1;
                        objcnt <= objcnt + 1'd1;
                        if( &objcnt ) done <= 1;
                    end
                end
                6: begin
                    st <= 6;
                    if( !busy_g || !inzone ) begin
                        dr_start <= inzone;
                        st <= 1;
                        objcnt <= objcnt + 1'd1;
                        if( &objcnt ) done <= 1;
                    end
                end
            endcase
        end
    end
end

endmodule