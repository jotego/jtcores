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
    Date: 5-9-2025 */

module jtframe_blank_length(
    input        rst,
    input        clk,
    input        pxl_cen,

    input        lhbl, lvbl,
    input        hs, vs,
    input        flip,

    output       rdy,      // v*_len ready after two frames

    output     [8:0] h_len,
    output     [8:0] v_len,
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

        .total      ( h_len         ),

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

        .total      ( v_len         ),

        .bs_len     ( vbs_len       ),
        .sy_len     ( vsy_len       ),
        .sa_len     ( vsa_len       )
    );

endmodule

//////////////////////////////////////////////////////////
module jtframe_sync_blank_counter(
    input       rst, clk,
                flip, s, lbl,
                pxl_cen,
                cnt_cen,

    output reg [8:0] total,

    output reg [5:0] bs_len,  // blank start to S start
                     sy_len,  // S length
                     sa_len   // S end to active video start
);

    reg  [8:0] cnt;
    reg  [5:0] aux;
    reg        s_l, lbl_l;

    always @(posedge clk) begin : blank_edges
        if( rst ) begin
            s_l   <= 0;
            lbl_l <= 0;
        end else if(pxl_cen) begin
            if( cnt_cen ) begin
                s_l   <= s;
                lbl_l <= lbl;
            end
        end
    end

    always @(posedge clk) begin : vertical_counter
        if( rst ) begin
            cnt    <= 0;
            aux    <= 0;
            bs_len <= 0;
            sy_len <= 0;
            sa_len <= 0;
            total  <= 0;
        end else if(pxl_cen) begin
            if (!lbl) begin
                if( cnt_cen ) begin
                    aux <= aux + 1'd1;
                    if( s && !s_l) begin bs_len <= aux; aux <= 0; end
                    if(!s &&  s_l) begin sy_len <= aux; aux <= 0; end
                end
            end else if( cnt_cen ) begin
                cnt <= cnt + 9'd1;
                if(!lbl_l) begin
                    aux    <= 0;
                    sa_len <= aux;
                    cnt    <= 0;
                    total  <= cnt ^ { 1'b0, {8{flip}}};
                end
            end
        end
    end

endmodule