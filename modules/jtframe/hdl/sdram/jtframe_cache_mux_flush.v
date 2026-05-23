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
    Date: 23-5-2026 */

module jtframe_cache_mux_flush #(
    parameter INVAL_MASK0 = 8'd0,
              INVAL_MASK1 = 8'd0,
              INVAL_MASK2 = 8'd0,
              INVAL_MASK3 = 8'd0
)(
    input            rst,
    input            clk,

    input      [3:0] cache_flush_done,
    input      [7:0] cache_invalidate_done,
    output reg [7:0] cache_invalidate,
    output     [3:0] flush_done_out,
    output     [3:0] flush_inval_active
);

reg [3:0] flush_inval_pending, delayed_flush_done;
reg [7:0] inval_mask_l, inval_done_seen;
reg [1:0] inval_sel, inval_next_sel;
reg       inval_active, inval_next_valid;
reg [7:0] inval_next_mask;
reg [3:0] nx_flush_inval_pending;

wire [3:0] flush_masked = {
    cache_flush_done[3] & |INVAL_MASK3,
    cache_flush_done[2] & |INVAL_MASK2,
    cache_flush_done[1] & |INVAL_MASK1,
    cache_flush_done[0] & |INVAL_MASK0
};
wire [3:0] flush_direct = cache_flush_done & ~{
    |INVAL_MASK3, |INVAL_MASK2, |INVAL_MASK1, |INVAL_MASK0
};
wire [7:0] inval_done_acc = inval_done_seen | cache_invalidate_done | ~inval_mask_l;
wire       inval_complete = inval_active && &inval_done_acc;

assign flush_done_out = flush_direct | delayed_flush_done;
assign flush_inval_active = {
    inval_active && inval_sel==2'd3,
    inval_active && inval_sel==2'd2,
    inval_active && inval_sel==2'd1,
    inval_active && inval_sel==2'd0
};

always @(*) begin
    nx_flush_inval_pending = flush_inval_pending | flush_masked;
    inval_next_valid = 1'b0;
    inval_next_sel   = 2'd0;
    inval_next_mask  = 8'd0;
    if( !inval_active ) begin
        if( nx_flush_inval_pending[0] ) begin
            inval_next_valid = 1'b1;
            inval_next_sel   = 2'd0;
            inval_next_mask  = INVAL_MASK0;
        end else if( nx_flush_inval_pending[1] ) begin
            inval_next_valid = 1'b1;
            inval_next_sel   = 2'd1;
            inval_next_mask  = INVAL_MASK1;
        end else if( nx_flush_inval_pending[2] ) begin
            inval_next_valid = 1'b1;
            inval_next_sel   = 2'd2;
            inval_next_mask  = INVAL_MASK2;
        end else if( nx_flush_inval_pending[3] ) begin
            inval_next_valid = 1'b1;
            inval_next_sel   = 2'd3;
            inval_next_mask  = INVAL_MASK3;
        end
    end
    if( inval_next_valid )
        nx_flush_inval_pending[inval_next_sel] = 1'b0;
end

always @(posedge clk) begin
    if( rst ) begin
        cache_invalidate     <= 8'd0;
        flush_inval_pending <= 4'd0;
        delayed_flush_done  <= 4'd0;
        inval_mask_l        <= 8'd0;
        inval_done_seen     <= 8'hff;
        inval_sel           <= 2'd0;
        inval_active        <= 1'b0;
    end else begin
        cache_invalidate <= 8'd0;
        delayed_flush_done <= 4'd0;
        flush_inval_pending <= nx_flush_inval_pending;
        if( inval_active ) begin
            if( inval_complete ) begin
                delayed_flush_done[inval_sel] <= 1'b1;
                inval_active                  <= 1'b0;
                inval_done_seen               <= 8'hff;
            end else begin
                inval_done_seen <= inval_done_acc;
            end
        end else if( inval_next_valid ) begin
            inval_active      <= 1'b1;
            inval_sel         <= inval_next_sel;
            inval_mask_l      <= inval_next_mask;
            inval_done_seen   <= ~inval_next_mask;
            cache_invalidate  <= inval_next_mask;
        end
    end
end

endmodule
