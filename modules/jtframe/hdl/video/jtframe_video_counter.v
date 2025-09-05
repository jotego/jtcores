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
    input        hs, vs,
    input        flip,

    output       rdy,      // v*_len ready after two frames

    output     [8:0] h,
    output     [8:0] v,
    output     [5:0] hbs_len,  // H blank start to HS start
                     hsy_len,  // HS length
                     hsa_len,  // HS end to active video start
                     vbs_len,  // V blank start to HS start
                     vsy_len,  // VS length
                     vsa_len   // VS end to active video start
);

    reg  [2:0] rdy_sh;
    reg        lvbl_l, lhbl_l;
    wire       hbl_neg, vbl_neg;

    assign hbl_neg = !lhbl && lhbl_l;
    assign vbl_neg = !lvbl && lvbl_l;
    assign rdy     = rdy_sh[1];

    always @(posedge clk) begin : blank_edges
        if( rst ) begin
            lvbl_l <= 0;
            lhbl_l <= 0;
        end else if(pxl_cen) begin
            lhbl_l <= lhbl;
            if( hbl_neg ) begin
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

     jtframe_sync_blank_counter u_hcnt(
        .rst        ( rst           ),
        .clk        ( clk           ),
        .pxl_cen    ( pxl_cen       ),
        .cnt_cen    ( 1'b1          ),

        .flip       ( flip          ),
        .s          ( hs            ),
        .lbl        ( lhbl          ),

        .total      ( h             ),

        .bs_len     ( hbs_len       ),
        .sy_len     ( hsy_len       ),
        .sa_len     ( hsa_len       )
    );

     jtframe_sync_blank_counter u_vcnt(
        .rst        ( rst           ),
        .clk        ( clk           ),
        .pxl_cen    ( pxl_cen       ),
        .cnt_cen    ( hbl_neg       ),

        .flip       ( flip          ),
        .s          ( vs            ),
        .lbl        ( lvbl          ),

        .total      ( v             ),

        .bs_len     ( vbs_len       ),
        .sy_len     ( vsy_len       ),
        .sa_len     ( vsa_len       )
    );

endmodule
