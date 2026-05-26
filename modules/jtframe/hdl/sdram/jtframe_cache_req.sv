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

module jtframe_cache_req #(parameter
    AW       = 24,
    DW       =  8,
    AW0      = DW==128 ? 4 : DW==64 ? 3 : DW==32 ? 2 : DW==16 ? 1 : 0,
    MW       = DW >> 3,
    SET_BITS =  0,
    TAG_BITS =  1,
    OFFW     =  1,
    SETW     =  1,
    TAGW     =  1,
    UW       = AW - AW0
)(
    input                   rst,
    input                   clk,

    input      [AW-1:AW0]   addr,
    input      [DW-1:0]     din,
    input                   rd,
    input                   wr,
    input      [MW-1:0]     wdsn,

    input                   flush,
    input                   flushing,
    output                  flush_start,
    input                   flush_take,
    input                   invalidate,
    input                   invalidating,
    output                  invalidate_start,
    input                   invalidate_take,
    input                   cache_init_busy,

    output                  block_normal_req,
    output                  req_valid,
    output reg              req_pending,
    input                   req_take,
    output                  req_wr,
    output     [AW-1:AW0]   req_addr,
    output     [TAGW-1:0]   req_tag,
    output     [SETW-1:0]   req_set,
    output     [OFFW-1:0]   req_off,
    output     [DW-1:0]     req_din,
    output     [MW-1:0]     req_wdsn,

    output reg              flush_rd_pending,
    output reg              flush_rd_lookup,
    output reg              flush_rd_resp,
    output reg [TAGW-1:0]   flush_rd_tag,
    output reg [SETW-1:0]   flush_rd_set,
    output reg [OFFW-1:0]   flush_rd_off,
    input                   flush_rd_can_lookup,
    input                   flush_rd_hit
);

reg              flush_l, flush_pending;
reg              invalidate_l, invalidate_pending;
reg              rd_l, wr_l;
reg              req_wr_l;
reg              flush_rd_wait_drop;
reg [AW-1:AW0]   req_addr_l, flush_rd_addr_l;
reg [TAGW-1:0]   req_tag_l;
reg [SETW-1:0]   req_set_l;
reg [OFFW-1:0]   req_off_l;
reg [DW-1:0]     req_din_l;
reg [MW-1:0]     req_wdsn_l;

wire            rd_rise = rd & ~rd_l;
wire            wr_rise = wr & ~wr_l;
wire            flush_rise = flush & ~flush_l;
wire            invalidate_rise = invalidate & ~invalidate_l;
wire            new_rd = rd_rise & ~block_normal_req;
wire            new_wr = wr_rise & ~rd_rise & ~block_normal_req;
wire            new_req = new_rd | new_wr;
wire            flush_rd_busy = flush_rd_pending | flush_rd_lookup | flush_rd_resp;
wire            flush_rd_accept = flushing & rd & ~flush_rd_busy &
                                  ~flush_rd_wait_drop & ~req_pending;
wire [UW-1:0]   req_uaddr_now = addr;
wire [UW-1:0]   req_tag_shift = req_uaddr_now >> (OFFW + SET_BITS);
wire [UW-1:0]   req_set_shift = req_uaddr_now >> OFFW;
wire [TAGW-1:0] req_tag_now   = TAG_BITS == 0 ? {TAGW{1'b0}} : TAGW'(req_tag_shift);
wire [SETW-1:0] req_set_now   = SET_BITS == 0 ? {SETW{1'b0}} : SETW'(req_set_shift);
wire [OFFW-1:0] req_off_now   = req_uaddr_now[OFFW-1:0];

assign flush_start      = flush_rise | flush_pending;
assign invalidate_start = invalidate_rise | invalidate_pending;
assign block_normal_req = flushing | flush_start | invalidating | invalidate_start;
assign req_valid        = req_pending | new_req;
assign req_wr           = req_pending ? req_wr_l   : new_wr;
assign req_addr         = req_pending ? req_addr_l : addr;
assign req_tag          = req_pending ? req_tag_l  : req_tag_now;
assign req_set          = req_pending ? req_set_l  : req_set_now;
assign req_off          = req_pending ? req_off_l  : req_off_now;
assign req_din          = req_pending ? req_din_l  : din;
assign req_wdsn         = req_pending ? req_wdsn_l : wdsn;

always @(posedge clk) begin
    if( rst ) begin
        flush_l             <= 1'b0;
        flush_pending       <= 1'b0;
        invalidate_l        <= 1'b0;
        invalidate_pending  <= 1'b0;
        rd_l                <= 1'b0;
        wr_l                <= 1'b0;
        req_pending         <= 1'b0;
        req_wr_l            <= 1'b0;
        req_addr_l          <= {AW-AW0{1'b0}};
        req_tag_l           <= {TAGW{1'b0}};
        req_set_l           <= {SETW{1'b0}};
        req_off_l           <= {OFFW{1'b0}};
        req_din_l           <= {DW{1'b0}};
        req_wdsn_l          <= {MW{1'b1}};
        flush_rd_pending    <= 1'b0;
        flush_rd_lookup     <= 1'b0;
        flush_rd_resp       <= 1'b0;
        flush_rd_wait_drop  <= 1'b0;
        flush_rd_addr_l     <= {AW-AW0{1'b0}};
        flush_rd_tag        <= {TAGW{1'b0}};
        flush_rd_set        <= {SETW{1'b0}};
        flush_rd_off        <= {OFFW{1'b0}};
    end else begin
        flush_l      <= flush;
        invalidate_l <= invalidate;

        if( flush_rise && !flushing ) flush_pending <= 1'b1;
        if( flush_take )              flush_pending <= 1'b0;
        if( invalidate_rise && !invalidating ) invalidate_pending <= 1'b1;
        if( invalidate_take )                 invalidate_pending <= 1'b0;

        if( req_take && req_pending ) req_pending <= 1'b0;
        if( !rd )                       flush_rd_wait_drop <= 1'b0;

        if( flush_rd_accept ) begin
            flush_rd_pending <= 1'b1;
            flush_rd_addr_l    <= addr;
            flush_rd_tag       <= req_tag_now;
            flush_rd_set       <= req_set_now;
            flush_rd_off       <= req_off_now;
        end
        if( flush_rd_can_lookup && flush_rd_pending ) begin
            flush_rd_pending <= 1'b0;
            flush_rd_lookup  <= 1'b1;
        end else if( flush_rd_lookup ) begin
            flush_rd_lookup <= 1'b0;
            if( flush_rd_hit ) begin
                flush_rd_resp <= 1'b1;
            end else begin
                req_pending        <= 1'b1;
                req_wr_l           <= 1'b0;
                req_addr_l         <= flush_rd_addr_l;
                req_tag_l          <= flush_rd_tag;
                req_set_l          <= flush_rd_set;
                req_off_l          <= flush_rd_off;
                req_din_l          <= {DW{1'b0}};
                req_wdsn_l         <= {MW{1'b1}};
                flush_rd_wait_drop <= 1'b1;
            end
        end
        if( flush_rd_resp ) begin
            flush_rd_resp      <= 1'b0;
            flush_rd_wait_drop <= 1'b1;
        end
        if( !flushing && flush_rd_pending && !req_pending ) begin
            req_pending        <= 1'b1;
            req_wr_l           <= 1'b0;
            req_addr_l         <= flush_rd_addr_l;
            req_tag_l          <= flush_rd_tag;
            req_set_l          <= flush_rd_set;
            req_off_l          <= flush_rd_off;
            req_din_l          <= {DW{1'b0}};
            req_wdsn_l         <= {MW{1'b1}};
            flush_rd_pending   <= 1'b0;
            flush_rd_wait_drop <= 1'b1;
        end
        if( (cache_init_busy && new_req && !req_pending) ||
            (block_normal_req && !req_pending && (rd | wr) && !(flushing && rd)) ) begin
            req_pending   <= 1'b1;
            req_wr_l      <= wr & ~rd;
            req_addr_l    <= addr;
            req_tag_l     <= req_tag_now;
            req_set_l     <= req_set_now;
            req_off_l     <= req_off_now;
            req_din_l     <= din;
            req_wdsn_l    <= wdsn;
        end

        // Keep edge tracking low while tag RAMs are being cleared or a flush
        // is pending/active so a requester that holds rd/wr still triggers
        // once the cache can accept normal requests again.
        if( !cache_init_busy && !block_normal_req ) begin
            rd_l <= rd;
            wr_l <= wr;
        end else begin
            rd_l <= 1'b0;
            wr_l <= 1'b0;
        end
    end
end

endmodule
