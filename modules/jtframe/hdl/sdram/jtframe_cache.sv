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

module jtframe_cache #(parameter
    BLOCKS  =    8,
    BLKSIZE = 1024,
    AW      =   24,
    DW      =    8,
    ENDIAN  =    0,
    EW      =   24,
    AW0     = DW==128 ? 4 : DW==64 ? 3 : DW==32 ? 2 : DW==16 ? 1 : 0,
    MW      = DW >> 3
)(
    input                   rst,
    input                   clk,

    input      [AW-1:AW0]   addr,
    output     [DW-1:0]     dout,
    input      [DW-1:0]     din,
    input                   rd,
    input                   wr,
    input      [MW-1:0]     wdsn,
    output                  ok,

    output     [EW-1:1]     ext_addr,
    input      [15:0]       ext_din,
    output     [15:0]       ext_dout,
    output                  ext_rd,
    output                  ext_wr,
    input                   ext_ack,
    input                   ext_dst,
    input                   ext_dok,
    input                   ext_rdy
);

localparam integer BW        = BLOCKS < 2 ? 1 : $clog2(BLOCKS);
localparam integer WAYS      = BLOCKS < 4 ? BLOCKS : 4;
localparam integer SETS      = BLOCKS / WAYS;
localparam integer WAY_BITS  = WAYS < 2 ? 0 : $clog2(WAYS);
localparam integer WAYW      = WAY_BITS < 1 ? 1 : WAY_BITS;
localparam integer SET_BITS  = SETS < 2 ? 0 : $clog2(SETS);
localparam integer SETW      = SET_BITS < 1 ? 1 : SET_BITS;
localparam integer UBYTES    = DW >> 3;
localparam integer DEPTH     = BLKSIZE / UBYTES;
localparam integer OFFW      = DEPTH < 2 ? 1 : $clog2(DEPTH);
localparam integer UW        = AW - AW0;
localparam integer TAG_BITS  = UW - OFFW - SET_BITS;
localparam integer TAGW      = TAG_BITS < 1 ? 1 : TAG_BITS;
localparam integer WORDS     = BLKSIZE >> 1;
localparam integer WW        = WORDS < 2 ? 1 : $clog2(WORDS);
localparam integer BLKBYTEW  = BLKSIZE < 2 ? 1 : $clog2(BLKSIZE);
localparam integer RAM_BYTEW = BW + BLKBYTEW;

wire [4:0]               st;
wire                     fill_tail_seen;
wire [BW-1:0]            blk_l;
wire [OFFW-1:0]          req_off_l;
wire [WW-1:0]            stream_word, fill_word;
wire [127:0]             req_q, stream_q, wb_q;
wire [RAM_BYTEW-1:0]     req_ram_addr_l, stream_ram_addr_l;
wire                     miss_busy, fill_done;
wire [RAM_BYTEW-1:0]     req_addr_mux, stream_addr_mux;
wire [15:0]              req_we, stream_we;
wire [127:0]             req_wdata, stream_wdata;
wire [SETW-1:0]          tag_rd_set, lookup_set, clr_set;
wire [SETW-1:0]          tag_write_set_n, tag_advance_set_n;
wire [WAYW-1:0]          hit_way_now, victim_way_now;
wire [WAYW-1:0]          tag_update_way_n, tag_advance_way_n;
wire [TAGW-1:0]          lookup_tag, victim_tag_now, tag_update_tag_n;
wire [BW-1:0]            hit_blk_now, victim_blk_now;
wire                     hit_now, victim_invalid_now, victim_dirty_now;
wire                     tag_clear_en, tag_update_en, tag_update_valid_n;
wire                     tag_update_dirty_n, tag_advance_en;

jtframe_cache_data #(
    .DW     ( DW         ),
    .ENDIAN ( ENDIAN     ),
    .AW0    ( AW0        ),
    .ADDRW  ( RAM_BYTEW  )
) u_data_ram (
    .clk         ( clk             ),
    .req_addr    ( req_addr_mux    ),
    .req_we      ( req_we          ),
    .req_wdata   ( req_wdata       ),
    .req_q       ( req_q           ),
    .stream_addr ( stream_addr_mux ),
    .stream_we   ( stream_we       ),
    .stream_wdata( stream_wdata    ),
    .stream_q    ( stream_q        )
);

jtframe_cache_tags #(
    .BLOCKS ( BLOCKS ),
    .WAYS   ( WAYS   ),
    .SETS   ( SETS   ),
    .BW     ( BW     ),
    .WAYW   ( WAYW   ),
    .SETW   ( SETW   ),
    .TAGW   ( TAGW   )
) u_tags (
    .rst           ( rst               ),
    .clk           ( clk               ),
    .rd_set        ( tag_rd_set        ),
    .lookup_set    ( lookup_set        ),
    .lookup_tag    ( lookup_tag        ),
    .clear_en      ( tag_clear_en      ),
    .clear_set     ( clr_set           ),
    .update_en     ( tag_update_en     ),
    .update_set    ( tag_write_set_n   ),
    .update_way    ( tag_update_way_n  ),
    .update_valid  ( tag_update_valid_n),
    .update_dirty  ( tag_update_dirty_n),
    .update_tag    ( tag_update_tag_n  ),
    .advance_en    ( tag_advance_en    ),
    .advance_set   ( tag_advance_set_n ),
    .advance_way   ( tag_advance_way_n ),
    .hit           ( hit_now           ),
    .hit_way       ( hit_way_now       ),
    .hit_blk       ( hit_blk_now       ),
    .victim_way    ( victim_way_now    ),
    .victim_blk    ( victim_blk_now    ),
    .victim_invalid( victim_invalid_now),
    .victim_dirty  ( victim_dirty_now  ),
    .victim_tag    ( victim_tag_now    )
);

jtframe_cache_ctrl #(
    .BLOCKS ( BLOCKS  ),
    .BLKSIZE( BLKSIZE ),
    .AW     ( AW      ),
    .DW     ( DW      ),
    .ENDIAN ( ENDIAN  ),
    .EW     ( EW      ),
    .AW0    ( AW0     ),
    .MW     ( MW      )
) u_ctrl (
    .rst             ( rst               ),
    .clk             ( clk               ),
    .addr            ( addr              ),
    .dout            ( dout              ),
    .din             ( din               ),
    .rd              ( rd                ),
    .wr              ( wr                ),
    .wdsn            ( wdsn              ),
    .ok              ( ok                ),
    .ext_addr        ( ext_addr          ),
    .ext_din         ( ext_din           ),
    .ext_dout        ( ext_dout          ),
    .ext_rd          ( ext_rd            ),
    .ext_wr          ( ext_wr            ),
    .ext_ack         ( ext_ack           ),
    .ext_dst         ( ext_dst           ),
    .ext_dok         ( ext_dok           ),
    .ext_rdy         ( ext_rdy           ),
    .req_q           ( req_q             ),
    .stream_q        ( stream_q          ),
    .req_addr        ( req_addr_mux      ),
    .req_we          ( req_we            ),
    .req_wdata       ( req_wdata         ),
    .stream_addr     ( stream_addr_mux   ),
    .stream_we       ( stream_we         ),
    .stream_wdata    ( stream_wdata      ),
    .tag_rd_set      ( tag_rd_set        ),
    .lookup_set      ( lookup_set        ),
    .lookup_tag      ( lookup_tag        ),
    .tag_clear_en    ( tag_clear_en      ),
    .clr_set         ( clr_set           ),
    .tag_update_en   ( tag_update_en     ),
    .tag_write_set_n ( tag_write_set_n   ),
    .tag_update_way_n( tag_update_way_n  ),
    .tag_update_valid_n( tag_update_valid_n ),
    .tag_update_dirty_n( tag_update_dirty_n ),
    .tag_update_tag_n( tag_update_tag_n  ),
    .tag_advance_en  ( tag_advance_en    ),
    .tag_advance_set_n( tag_advance_set_n ),
    .tag_advance_way_n( tag_advance_way_n ),
    .hit_now         ( hit_now           ),
    .hit_way_now     ( hit_way_now       ),
    .hit_blk_now     ( hit_blk_now       ),
    .victim_way_now  ( victim_way_now    ),
    .victim_blk_now  ( victim_blk_now    ),
    .victim_dirty_now( victim_dirty_now  ),
    .victim_tag_now  ( victim_tag_now    ),
    .st              ( st                ),
    .fill_tail_seen  ( fill_tail_seen    ),
    .blk_l           ( blk_l             ),
    .req_off_l       ( req_off_l         ),
    .stream_word     ( stream_word       ),
    .wb_q            ( wb_q              ),
    .req_ram_addr_l  ( req_ram_addr_l    ),
    .stream_ram_addr_l( stream_ram_addr_l ),
    .miss_busy       ( miss_busy         ),
    .fill_done       ( fill_done         ),
    .fill_word       ( fill_word         )
);

endmodule
