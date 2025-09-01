/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 25-1-2025 */

module jtframe_video_counter(
    input        rst,
    input        clk,
    input        pxl_cen,

    input        lhbl, lvbl,
    input        vs,
    input        flip,

    output       rdy,      // v*_len ready after two frames

    output     [8:0] h,
    output reg [8:0] v,
    output reg [5:0] vbs_len,  // V blank start to VS start
                     vsy_len,  // VS length
                     vsa_len   // VS end to active video start
);

reg  [8:0] vcnt, hcnt;
reg  [5:0] vaux;
reg  [2:0] rdy_sh;
reg        lvbl_l, lhbl_l, vs_l;
wire       hbl_neg, vbl_neg;

assign h       = hcnt ^ { 1'b0, {8{flip}}};
assign hbl_neg = !lhbl && lhbl_l;
assign vbl_neg = !lvbl && lvbl_l;
assign rdy     = rdy_sh[1];

always @(posedge clk) begin : blank_edges
    if( rst ) begin
        vs_l   <= 0;
        lvbl_l <= 0;
        lhbl_l <= 0;
    end else if(pxl_cen) begin
        lhbl_l <= lhbl;
        if( hbl_neg ) begin
            vs_l   <= vs;
            lvbl_l <= lvbl;
        end
    end
end

always @(posedge clk) begin : frames_to_ready
    if( rst ) begin
        rdy_sh <= 0;
    end else if(pxl_cen) begin
        if( vbl_neg & hbl_neg ) rdy_sh <= {rdy_sh[1:0],1'b1};
    end
end

always @(posedge clk) begin : horizontal_counter
    if( rst ) begin
        hcnt    <= 0;
    end else if(pxl_cen) begin
        if (!lhbl) begin
            hcnt <= 0;
        end else begin
            hcnt <= hcnt + 9'd1;
        end
    end
end

always @(posedge clk) begin : vertical_counter
    if( rst ) begin
        vcnt    <= 0;
        vaux    <= 0;
        vbs_len <= 0;
        vsy_len <= 0;
        vsa_len <= 0;
    end else if(pxl_cen) begin
        if (!lvbl) begin
            if( hbl_neg ) begin
                vaux <= vaux + 1'd1;
                if( vs && !vs_l) begin vbs_len <= vaux; vaux <= 0; end
                if(!vs &&  vs_l) begin vsy_len <= vaux; vaux <= 0; end
            end
        end else if( hbl_neg ) begin
            vcnt <= vcnt + 9'd1;
            if(!lvbl_l) begin
                vaux    <= 0;
                vsa_len <= vaux;
                vcnt    <= 0;
                v       <= vcnt ^ { 1'b0, {8{flip}}};
            end
        end
    end
end

endmodule
