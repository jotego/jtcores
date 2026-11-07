/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 30-12-2024 */

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
wire        busy_g;
reg  [ 6:0] ydf;
reg  [ 2:0] st;
reg  [ 7:0] objcnt;
reg         in_hwindow=0;

assign scan_addr = {objcnt,st[1:0]};
assign busy_g    = busy_l | dr_busy;

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

function apply_hwindow(input [15:0]x); begin
    reg j81, j78;
    j81 = ~|{~&x[15:8],~|x[7:6]};
    j78 =  &{~|x[15:9],~&x[8:7]};
    apply_hwindow=j78|j81;
end endfunction

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
                1: begin
                    hpos <= scan_dout[PW-1:0]+ {{PW-9{1'b0}},9'h69};
                    in_hwindow <= apply_hwindow({{16-PW{scan_dout[PW-1]}},scan_dout[PW-1:0]});
                end
                2: begin
                    y <= 0;
                    y[PW-1:0] <=  scan_dout[PW-1:0] + {{PW-9{1'b0}},9'h1f-9'h20};
                end
                3: begin
                    skip <= ~scan_dout[15];
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
                        dr_start <= inzone && in_hwindow;
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
