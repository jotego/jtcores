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
    Version: 2.2
    Date: 16-4-2026 */

module jtframe_cache_tags #(parameter
    BLOCKS = 8,
    WAYS   = 4,
    SETS   = 2,
    BW     = 3,
    WAYW   = 2,
    SETW   = 1,
    TAGW   = 8
)(
    input                   rst,
    input                   clk,
    input      [SETW-1:0]   rd_set,
    input      [SETW-1:0]   lookup_set,
    input      [TAGW-1:0]   lookup_tag,
    input                   clear_en,
    input      [SETW-1:0]   clear_set,
    input                   update_en,
    input      [SETW-1:0]   update_set,
    input      [WAYW-1:0]   update_way,
    input                   update_valid,
    input                   update_dirty,
    input      [TAGW-1:0]   update_tag,
    input                   advance_en,
    input      [SETW-1:0]   advance_set,
    input      [WAYW-1:0]   advance_way,
    output reg              hit,
    output reg [WAYW-1:0]   hit_way,
    output     [BW-1:0]     hit_blk,
    output reg [WAYW-1:0]   victim_way,
    output     [BW-1:0]     victim_blk,
    output reg              victim_invalid,
    output reg              victim_dirty,
    output reg [TAGW-1:0]   victim_tag
);

localparam integer TAGMETAW = TAGW + 2;

reg [WAYW-1:0]   repl_ptr[0:SETS-1];
reg [SETW-1:0]   tag_wr_set;
reg [WAYS-1:0]   tag_wr_en;
reg [TAGMETAW-1:0] tag_wr_data[0:WAYS-1];

wire [TAGMETAW-1:0] tag_q[0:WAYS-1];
wire [WAYS-1:0]     tag_valid_q;
wire [WAYS-1:0]     tag_dirty_q;
wire [TAGW-1:0]     tag_tag_q[0:WAYS-1];

integer i;

generate
genvar way_idx;
for( way_idx=0; way_idx<WAYS; way_idx=way_idx+1 ) begin : g_tag_ram
    wire [TAGMETAW-1:0] tag_q1_unused;
    assign tag_tag_q[way_idx]   = tag_q[way_idx][TAGW-1:0];
    assign tag_valid_q[way_idx] = tag_q[way_idx][TAGW];
    assign tag_dirty_q[way_idx] = tag_q[way_idx][TAGW+1];
    jtframe_dual_ram #(
        .DW( TAGMETAW ),
        .AW( SETW     )
    ) u_tag_ram (
        .clk0 ( clk                 ),
        .data0( {TAGMETAW{1'b0}}    ),
        .addr0( rd_set              ),
        .we0  ( 1'b0                ),
        .q0   ( tag_q[way_idx]      ),
        .clk1 ( clk                 ),
        .data1( tag_wr_data[way_idx]),
        .addr1( tag_wr_set          ),
        .we1  ( tag_wr_en[way_idx]  ),
        .q1   ( tag_q1_unused       )
    );
end
endgenerate

function automatic [BW-1:0] blk_index(
    input [SETW-1:0] set,
    input [WAYW-1:0] way
);
    integer idx;
    begin
        idx = integer'(way) * SETS + integer'(set);
        blk_index = BW'(idx);
    end
endfunction

function automatic [WAYW-1:0] next_way(input [WAYW-1:0] way);
    integer idx;
    begin
        idx = integer'(way) + 1;
        if( idx >= WAYS ) idx = 0;
        next_way = WAYW'(idx);
    end
endfunction

assign hit_blk    = blk_index(lookup_set, hit_way);
assign victim_blk = blk_index(lookup_set, victim_way);

always @* begin
    hit = 1'b0;
    hit_way = {WAYW{1'b0}};
    for( i=0; i<WAYS; i=i+1 ) begin
        if( tag_valid_q[i] && lookup_tag == tag_tag_q[i] ) begin
            hit = 1'b1;
            hit_way = WAYW'(i);
        end
    end
end

always @* begin
    victim_way     = {WAYW{1'b0}};
    victim_invalid = 1'b0;
    victim_dirty   = 1'b0;
    victim_tag     = {TAGW{1'b0}};
    for( i=0; i<WAYS; i=i+1 ) begin
        if( !tag_valid_q[i] && !victim_invalid ) begin
            victim_way     = WAYW'(i);
            victim_invalid = 1'b1;
        end
    end
    if( !victim_invalid ) begin
        victim_way   = repl_ptr[lookup_set];
        victim_dirty = tag_valid_q[victim_way] & tag_dirty_q[victim_way];
        victim_tag   = tag_tag_q[victim_way];
    end
end

always @* begin
    tag_wr_set = update_set;
    tag_wr_en  = {WAYS{1'b0}};
    for( i=0; i<WAYS; i=i+1 ) begin
        tag_wr_data[i] = {TAGMETAW{1'b0}};
    end
    if( clear_en ) begin
        tag_wr_set = clear_set;
        tag_wr_en  = {WAYS{1'b1}};
    end else if( update_en ) begin
        tag_wr_en[update_way]   = 1'b1;
        tag_wr_data[update_way] = { update_dirty, update_valid, update_tag };
    end
end

always @(posedge clk) begin
    if( rst ) begin
        for( i=0; i<SETS; i=i+1 ) begin
            repl_ptr[i] <= {WAYW{1'b0}};
        end
    end else if( advance_en ) begin
        repl_ptr[advance_set] <= next_way(advance_way);
    end
end

endmodule
