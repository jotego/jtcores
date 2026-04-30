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

module jtframe_cache_ctrl #(parameter
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
    output reg [DW-1:0]     dout,
    input      [DW-1:0]     din,
    input                   rd,
    input                   wr,
    input      [MW-1:0]     wdsn,
    output reg              ok,

    output     [EW-1:1]     ext_addr,
    input      [15:0]       ext_din,
    output     [15:0]       ext_dout,
    output                  ext_rd,
    output                  ext_wr,
    input                   ext_ack,
    input                   ext_dst,
    input                   ext_dok,
    input                   ext_rdy,

    input      [127:0]      req_q,
    input      [127:0]      stream_q,
    output     [RAM_BYTEW-1:0] req_addr,
    output reg [15:0]       req_we,
    output reg [127:0]      req_wdata,
    output     [RAM_BYTEW-1:0] stream_addr,
    output reg [15:0]       stream_we,
    output reg [127:0]      stream_wdata,
    output     [SETW-1:0]   tag_rd_set,
    output     [SETW-1:0]   lookup_set,
    output     [TAGW-1:0]   lookup_tag,
    output reg              tag_clear_en,
    output reg [SETW-1:0]   clr_set,
    output reg              tag_update_en,
    output reg [SETW-1:0]   tag_write_set_n,
    output reg [WAYW-1:0]   tag_update_way_n,
    output reg              tag_update_valid_n,
    output reg              tag_update_dirty_n,
    output reg [TAGW-1:0]   tag_update_tag_n,
    output reg              tag_advance_en,
    output reg [SETW-1:0]   tag_advance_set_n,
    output reg [WAYW-1:0]   tag_advance_way_n,
    input                   hit_now,
    input      [WAYW-1:0]   hit_way_now,
    input      [BW-1:0]     hit_blk_now,
    input      [WAYW-1:0]   victim_way_now,
    input      [BW-1:0]     victim_blk_now,
    input                   victim_dirty_now,
    input      [TAGW-1:0]   victim_tag_now,

    output reg [4:0]        st,
    output reg              fill_tail_seen,
    output reg [BW-1:0]     blk_l,
    output reg [OFFW-1:0]   req_off_l,
    output reg [WW-1:0]     stream_word,
    output reg [127:0]      wb_q,
    output reg [RAM_BYTEW-1:0] req_ram_addr_l,
    output reg [RAM_BYTEW-1:0] stream_ram_addr_l,
    output                  miss_busy,
    output                  fill_done,
    output     [WW-1:0]     fill_word
);

localparam integer WAYS      = BLOCKS < 4 ? BLOCKS : 4;
localparam integer SETS      = BLOCKS / WAYS;
localparam integer BW        = BLOCKS < 2 ? 1 : $clog2(BLOCKS);
localparam integer UBYTES    = DW >> 3;
localparam integer DEPTH     = BLKSIZE / UBYTES;
localparam integer OFFW      = DEPTH < 2 ? 1 : $clog2(DEPTH);
localparam integer UW        = AW - AW0;
localparam integer WAY_BITS  = WAYS < 2 ? 0 : $clog2(WAYS);
localparam integer WAYW      = WAY_BITS < 1 ? 1 : WAY_BITS;
localparam integer SET_BITS  = SETS < 2 ? 0 : $clog2(SETS);
localparam integer SETW      = SET_BITS < 1 ? 1 : SET_BITS;
localparam integer TAG_BITS  = UW - OFFW - SET_BITS;
localparam integer TAGW      = TAG_BITS < 1 ? 1 : TAG_BITS;
localparam integer WORDS     = BLKSIZE >> 1;
localparam integer WW        = WORDS < 2 ? 1 : $clog2(WORDS);
localparam integer BLKBYTEW  = BLKSIZE < 2 ? 1 : $clog2(BLKSIZE);
localparam integer RAM_BYTEW = BW + BLKBYTEW;
localparam integer HALF_PER_WORD = DW < 16 ? 1 : DW >> 4;
localparam integer HALF_SHIFT    = HALF_PER_WORD < 2 ? 0 : $clog2(HALF_PER_WORD);
localparam integer STREAM_AW0    = DW == 8 ? 1 : AW0;

localparam [WW-1:0] LAST_WORD = WW'(WORDS-1);
localparam [SETW-1:0] LAST_SET = SETW'(SETS-1);

localparam [4:0] S_INIT_CLEAR    = 5'd0,
                 S_IDLE          = 5'd1,
                 S_LOOKUP        = 5'd2,
                 S_RD_RESP       = 5'd3,
                 S_WR_COMMIT     = 5'd4,
                 S_WB_PRIME      = 5'd5,
                 S_WB_REQ        = 5'd6,
                 S_WB_STREAM     = 5'd7,
                 S_WB_GAP        = 5'd8,
                 S_FILL_REQ      = 5'd9,
                 S_FILL_STREAM   = 5'd10,
                 S_POSTFILL_WAIT = 5'd11,
                 S_FILL_WB_WAIT  = 5'd12,
                 S_FILL_WB_PRIME = 5'd13;

reg              fill_after_wb, fill_wb_prime_wait;
reg              init_req_pending;
reg              rd_l, wr_l;
reg              req_wr_l;
reg [AW-1:AW0]   req_addr_l;
reg [TAGW-1:0]   req_tag_l;
reg [SETW-1:0]   req_set_l;
reg [DW-1:0]     req_din_l;
reg [MW-1:0]     req_wdsn_l;
reg [WAYW-1:0]   way_l;
reg [TAGW-1:0]   victim_tag_l;

reg              req_load_addr, stream_load_addr;
reg [RAM_BYTEW-1:0] req_addr_n, stream_addr_n;
`ifdef SIMULATION
real             ext_total_read_kb;
`endif

wire            rd_rise = rd & ~rd_l;
wire            wr_rise = wr & ~wr_l;
wire            new_rd  = rd_rise;
wire            new_wr  = wr_rise & ~rd_rise;
wire            new_req = new_rd | new_wr;
wire            fill_stream_dok = ext_dok;

wire [UW-1:0]   req_uaddr_now = addr;
wire [TAGW-1:0] req_tag_now   = addr_tag(req_uaddr_now);
wire [SETW-1:0] req_set_now   = addr_set(req_uaddr_now);
wire [OFFW-1:0] req_off_now   = req_uaddr_now[OFFW-1:0];
wire [RAM_BYTEW-1:0] req_wr_addr     = req_baddr(blk_l, req_off_l);
wire [RAM_BYTEW-1:0] stream_wr_addr  = stream_baddr(blk_l, stream_word);

wire [AW-1:0]   fill_base_byte   = { line_base_uaddr(req_tag_l, req_set_l),    {AW0{1'b0}} };
wire [AW-1:0]   victim_base_byte = { line_base_uaddr(victim_tag_l, req_set_l), {AW0{1'b0}} };
wire [AW-1:0]   ext_base_byte    = st==S_WB_REQ || st==S_WB_STREAM ?
                                   victim_base_byte : fill_base_byte;
wire [WW-1:0]   wb_half_idx      = DW >= 32 && st == S_WB_STREAM && stream_word != LAST_WORD ?
                                   stream_word + WW'(1) : stream_word;
wire [127:0]    rd_resp_word     = pack_data(req_q, req_off_l);

assign miss_busy = st != S_IDLE;
assign fill_done = fill_tail_seen;
assign fill_word = stream_word;
assign req_addr  = |req_we ? req_wr_addr :
                   req_load_addr ? req_addr_n : req_ram_addr_l;
assign stream_addr = |stream_we ? stream_wr_addr :
                     stream_load_addr ? stream_addr_n : stream_ram_addr_l;
assign tag_rd_set = st == S_IDLE && new_req ? req_set_now : req_set_l;
assign lookup_set = req_set_l;
assign lookup_tag = req_tag_l;

assign ext_addr = { {(EW-AW){1'b0}}, ext_base_byte[AW-1:1] };
assign ext_dout = wb_ext_word(wb_q, wb_half_idx);
assign ext_rd   = st==S_FILL_REQ ||
                  st==S_FILL_WB_WAIT ||
                  st==S_FILL_WB_PRIME ||
                  (st==S_FILL_STREAM && stream_word != LAST_WORD);
assign ext_wr   = st==S_WB_REQ || (st==S_WB_STREAM && stream_word != LAST_WORD);

function automatic [SETW-1:0] addr_set(input [UW-1:0] uaddr);
    reg [UW-1:0] shifted;
    begin
        if( SET_BITS == 0 ) begin
            addr_set = {SETW{1'b0}};
        end else begin
            shifted  = uaddr >> OFFW;
            addr_set = SETW'(shifted);
        end
    end
endfunction

function automatic [TAGW-1:0] addr_tag(input [UW-1:0] uaddr);
    begin
        if( TAG_BITS == 0 )
            addr_tag = {TAGW{1'b0}};
        else
            addr_tag = TAGW'(uaddr >> (OFFW + SET_BITS));
    end
endfunction

function automatic [UW-1:0] line_base_uaddr(
    input [TAGW-1:0] tag,
    input [SETW-1:0] set
);
    reg [UW-1:0] tmp;
    begin
        tmp = UW'(tag) << (OFFW + SET_BITS);
        if( SET_BITS != 0 )
            tmp = tmp | (UW'(set) << OFFW);
        line_base_uaddr = tmp;
    end
endfunction

function automatic [RAM_BYTEW-1:0] req_baddr(
    input [BW-1:0]   blk,
    input [OFFW-1:0] off
);
    begin
        req_baddr = { blk, off, {AW0{1'b0}} };
    end
endfunction

function automatic [RAM_BYTEW-1:0] stream_baddr(
    input [BW-1:0] blk,
    input [WW-1:0] half_idx
);
    reg [OFFW-1:0] word_off;
    begin
        if( DW < 32 ) begin
            stream_baddr = { blk, half_idx, 1'b0 };
        end else begin
            word_off = OFFW'(half_idx >> HALF_SHIFT);
            stream_baddr = RAM_BYTEW'({ blk, word_off, {STREAM_AW0{1'b0}} });
        end
    end
endfunction

function automatic [127:0] pack_data(
    input [127:0]        data_in,
    input [OFFW-1:0]     off
);
    begin
        if( DW == 8 ) begin
            pack_data = off[0] ? { 120'd0, data_in[15:8] } : { 120'd0, data_in[7:0] };
        end else if( DW == 16 ) begin
            pack_data = { 112'd0, data_in[15:0] };
        end else begin
            pack_data = data_in;
        end
    end
endfunction

function automatic [127:0] req_write_data(
    input [DW-1:0]       din_in,
    input [OFFW-1:0]     off
);
    begin
        req_write_data = 128'd0;
        if( DW == 8 ) begin
            req_write_data = off[0] ? { 112'd0, din_in[7:0], 8'd0 } :
                                      { 112'd0, 8'd0,       din_in[7:0] };
        end else begin
            req_write_data[DW-1:0] = din_in;
        end
    end
endfunction

function automatic [15:0] req_write_mask(
    input [MW-1:0]       dsn_in,
    input [OFFW-1:0]     off
);
    begin
        req_write_mask = 16'd0;
        if( DW == 8 ) begin
            req_write_mask = off[0] ? 16'h0002 : 16'h0001;
        end else begin
            req_write_mask[MW-1:0] = ~dsn_in;
        end
    end
endfunction

function automatic [127:0] fill_write_data(
    input [15:0]         ext_word,
    input [WW-1:0]       half_idx
);
    integer pos;
    begin
        fill_write_data = 128'd0;
        if( DW < 32 ) begin
            fill_write_data[15:0] = ext_word;
        end else begin
            if( DW == 32 && ENDIAN )
                pos = half_idx[0] ? 0 : 1;
            else
                pos = integer'(half_idx) % HALF_PER_WORD;
            fill_write_data[pos*16 +: 16] = ext_word;
        end
    end
endfunction

function automatic [15:0] fill_write_mask(input [WW-1:0] half_idx);
    integer pos;
    begin
        fill_write_mask = 16'd0;
        if( DW < 32 ) begin
            fill_write_mask[1:0] = 2'b11;
        end else begin
            if( DW == 32 && ENDIAN )
                pos = half_idx[0] ? 0 : 1;
            else
                pos = integer'(half_idx) % HALF_PER_WORD;
            fill_write_mask[pos*2 +: 2] = 2'b11;
        end
    end
endfunction

function automatic [15:0] wb_ext_word(
    input [127:0]        data_in,
    input [WW-1:0]       half_idx
);
    integer pos;
    begin
        if( DW < 32 ) begin
            wb_ext_word = data_in[15:0];
        end else begin
            if( DW == 32 && ENDIAN )
                pos = half_idx[0] ? 0 : 1;
            else
                pos = integer'(half_idx) % HALF_PER_WORD;
            wb_ext_word = data_in[pos*16 +: 16];
        end
    end
endfunction

initial begin
    if( ENDIAN && DW != 32 ) begin
        $display("jtframe_cache parameter error: ENDIAN=1 requires DW=32");
        $finish;
    end
    if( BLOCKS < 1 || (BLOCKS & (BLOCKS-1)) != 0 ) begin
        $display("jtframe_cache parameter error: BLOCKS must be a power of 2 and non-zero");
        $finish;
    end
    if( WAYS < 1 || (WAYS & (WAYS-1)) != 0 || (BLOCKS % WAYS) != 0 ) begin
        $display("jtframe_cache parameter error: derived WAYS must divide BLOCKS and be a power of 2");
        $finish;
    end
    if( BLKSIZE < 16 ) begin
        $display("jtframe_cache parameter error: BLKSIZE must be at least 16 bytes");
        $finish;
    end
    if( TAG_BITS < 1 ) begin
        $display("jtframe_cache parameter error: tag width must be at least 1 bit");
        $finish;
    end
end

always @* begin
    req_load_addr      = 1'b0;
    req_we             = 16'd0;
    req_wdata          = 128'd0;
    req_addr_n         = req_ram_addr_l;
    stream_load_addr   = 1'b0;
    stream_we          = 16'd0;
    stream_wdata       = 128'd0;
    stream_addr_n      = stream_ram_addr_l;
    tag_clear_en       = 1'b0;
    tag_update_en      = 1'b0;
    tag_advance_en     = 1'b0;
    tag_write_set_n    = req_set_l;
    tag_update_way_n   = {WAYW{1'b0}};
    tag_update_valid_n = 1'b0;
    tag_update_dirty_n = 1'b0;
    tag_update_tag_n   = {TAGW{1'b0}};
    tag_advance_set_n  = req_set_l;
    tag_advance_way_n  = victim_way_now;
    case( st )
        S_INIT_CLEAR: begin
            tag_clear_en = 1'b1;
        end
        S_LOOKUP: begin
            if( !hit_now ) begin
                tag_advance_en = 1'b1;
            end
            if( hit_now && !req_wr_l ) begin
                req_load_addr = 1'b1;
                req_addr_n    = req_baddr(hit_blk_now, req_off_l);
            end else if( !hit_now && victim_dirty_now ) begin
                stream_load_addr = 1'b1;
                stream_addr_n    = stream_baddr(victim_blk_now, {WW{1'b0}});
            end
        end
        S_WB_PRIME: begin
            if( DW >= 32 ) begin
                if( WORDS > HALF_PER_WORD ) begin
                    stream_load_addr = 1'b1;
                    stream_addr_n    = stream_baddr(blk_l, WW'(HALF_PER_WORD));
                end
            end else begin
                if( WORDS > 1 ) begin
                    stream_load_addr = 1'b1;
                    stream_addr_n    = stream_baddr(blk_l, WW'(1));
                end
            end
        end
        S_WB_REQ: begin
            if( DW < 32 && ext_ack && WORDS > 2 ) begin
                stream_load_addr = 1'b1;
                stream_addr_n    = stream_baddr(blk_l, WW'(2));
            end
        end
        S_WB_STREAM: begin
            if( DW >= 32 ) begin
                if( WORDS > (2*HALF_PER_WORD) &&
                    (integer'(stream_word) % HALF_PER_WORD) == HALF_PER_WORD-1 &&
                    stream_word < LAST_WORD-WW'(HALF_PER_WORD) ) begin
                    stream_load_addr = 1'b1;
                    stream_addr_n    = stream_baddr(blk_l, stream_word + WW'(HALF_PER_WORD+1));
                end
            end else begin
                if( WORDS > 3 && stream_word < LAST_WORD-WW'(2) ) begin
                    stream_load_addr = 1'b1;
                    stream_addr_n    = stream_baddr(blk_l, stream_word + WW'(3));
                end
            end
        end
        S_FILL_WB_PRIME: begin
            if( !fill_wb_prime_wait ) begin
                stream_we    = fill_write_mask({WW{1'b0}});
                stream_wdata = fill_write_data(ext_din, {WW{1'b0}});
            end
            if( !fill_wb_prime_wait && (ext_rdy || LAST_WORD == {WW{1'b0}}) ) begin
                tag_update_en      = 1'b1;
                tag_update_way_n   = way_l;
                tag_update_valid_n = 1'b1;
                tag_update_dirty_n = 1'b0;
                tag_update_tag_n   = req_tag_l;
            end
        end
        S_POSTFILL_WAIT: begin
            req_load_addr = 1'b1;
            req_addr_n    = req_baddr(blk_l, req_off_l);
        end
        S_WR_COMMIT: begin
            req_we    = req_write_mask(req_wdsn_l, req_off_l);
            req_wdata = req_write_data(req_din_l, req_off_l);
            tag_update_en      = 1'b1;
            tag_update_way_n   = way_l;
            tag_update_valid_n = 1'b1;
            tag_update_dirty_n = 1'b1;
            tag_update_tag_n   = req_tag_l;
        end
        S_FILL_STREAM: begin
            if( fill_stream_dok && !fill_tail_seen ) begin
                stream_we    = fill_write_mask(stream_word);
                stream_wdata = fill_write_data(ext_din, stream_word);
            end
            if( fill_stream_dok && ext_rdy ) begin
                tag_update_en      = 1'b1;
                tag_update_way_n   = way_l;
                tag_update_valid_n = 1'b1;
                tag_update_dirty_n = 1'b0;
                tag_update_tag_n   = req_tag_l;
            end
        end
        default: begin
        end
    endcase
end

always @(posedge clk) begin
    if( rst ) begin
        st                <= S_INIT_CLEAR;
        fill_tail_seen    <= 1'b0;
        fill_after_wb     <= 1'b0;
        fill_wb_prime_wait<= 1'b0;
        init_req_pending  <= 1'b0;
        rd_l              <= 1'b0;
        wr_l              <= 1'b0;
        req_wr_l          <= 1'b0;
        req_addr_l        <= {AW-AW0{1'b0}};
        req_tag_l         <= {TAGW{1'b0}};
        req_set_l         <= {SETW{1'b0}};
        req_off_l         <= {OFFW{1'b0}};
        req_din_l         <= {DW{1'b0}};
        req_wdsn_l        <= {MW{1'b1}};
        blk_l             <= {BW{1'b0}};
        way_l             <= {WAYW{1'b0}};
        clr_set           <= {SETW{1'b0}};
        victim_tag_l      <= {TAGW{1'b0}};
        stream_word       <= {WW{1'b0}};
        wb_q              <= 128'd0;
        req_ram_addr_l    <= {RAM_BYTEW{1'b0}};
        stream_ram_addr_l <= {RAM_BYTEW{1'b0}};
        dout              <= {DW{1'b0}};
        ok                <= 1'b0;
`ifdef SIMULATION
        ext_total_read_kb = 0.0;
`endif
    end else begin
        if( req_load_addr )    req_ram_addr_l    <= req_addr_n;
        if( stream_load_addr ) stream_ram_addr_l <= stream_addr_n;

        // Keep edge tracking low while tag RAMs are being cleared so a
        // requester that raises rd/wr during init still triggers once ready.
        if( st != S_INIT_CLEAR ) begin
            rd_l <= rd;
            wr_l <= wr;
        end
        ok <= 1'b0;
`ifdef SIMULATION
        if( st == S_FILL_REQ && ext_ack )
            ext_total_read_kb = ext_total_read_kb + (BLKSIZE / 1024.0);
`endif

        case( st )
            S_INIT_CLEAR: begin
                if( new_req && !init_req_pending ) begin
                    init_req_pending <= 1'b1;
                    req_wr_l         <= new_wr;
                    req_addr_l       <= addr;
                    req_tag_l        <= req_tag_now;
                    req_set_l        <= req_set_now;
                    req_off_l        <= req_off_now;
                    req_din_l        <= din;
                    req_wdsn_l       <= wdsn;
                end
                if( clr_set == LAST_SET ) begin
                    st <= S_IDLE;
                end else begin
                    clr_set <= clr_set + 1'd1;
                end
            end
            S_IDLE: begin
                if( init_req_pending ) begin
                    init_req_pending <= 1'b0;
                    fill_after_wb    <= 1'b0;
                    st               <= S_LOOKUP;
                end else if( new_req ) begin
                    fill_after_wb <= 1'b0;
                    req_wr_l      <= new_wr;
                    req_addr_l    <= addr;
                    req_tag_l     <= req_tag_now;
                    req_set_l     <= req_set_now;
                    req_off_l     <= req_off_now;
                    req_din_l     <= din;
                    req_wdsn_l    <= wdsn;
                    st            <= S_LOOKUP;
                end
            end
            S_LOOKUP: begin
                if( hit_now ) begin
                    blk_l <= hit_blk_now;
                    way_l <= hit_way_now;
                    if( req_wr_l ) st <= S_WR_COMMIT;
                    else           st <= S_RD_RESP;
                end else begin
                    blk_l          <= victim_blk_now;
                    way_l          <= victim_way_now;
                    victim_tag_l   <= victim_tag_now;
                    stream_word    <= {WW{1'b0}};
                    fill_tail_seen <= 1'b0;
                    if( victim_dirty_now ) st <= S_WB_PRIME;
                    else                   st <= S_FILL_REQ;
                end
            end
            S_RD_RESP: begin
                /* verilator lint_off WIDTHTRUNC */
                dout     <= rd_resp_word[DW-1:0];
                /* verilator lint_on WIDTHTRUNC */
                ok       <= 1'b1;
                st       <= S_IDLE;
            end
            S_WR_COMMIT: begin
                ok <= 1'b1;
                st <= S_IDLE;
            end
            S_WB_PRIME: begin
                wb_q <= stream_q;
                st   <= S_WB_REQ;
            end
            S_WB_REQ: begin
                if( ext_ack ) begin
                    if( DW >= 32 ) begin
                        stream_word <= {WW{1'b0}};
                    end else begin
                        wb_q        <= stream_q;
                        stream_word <= {WW{1'b0}};
                    end
                    st <= S_WB_STREAM;
                end
            end
            S_WB_STREAM: begin
                if( ext_rdy ) begin
                    stream_word    <= {WW{1'b0}};
                    fill_tail_seen <= 1'b0;
                    st             <= S_WB_GAP;
                end else if( stream_word != LAST_WORD ) begin
                    if( DW >= 32 ) begin
                        if( (integer'(stream_word) % HALF_PER_WORD) == HALF_PER_WORD-2 )
                            wb_q <= stream_q;
                    end else begin
                        wb_q <= stream_q;
                    end
                    stream_word <= stream_word + 1'd1;
                end
            end
            S_WB_GAP: begin
                fill_after_wb <= 1'b1;
                st <= S_FILL_REQ;
            end
            S_FILL_REQ: begin
                if( ext_ack ) begin
                    stream_word    <= {WW{1'b0}};
                    fill_tail_seen <= 1'b0;
                    st             <= fill_after_wb ? S_FILL_WB_WAIT : S_FILL_STREAM;
                end
            end
            S_FILL_WB_WAIT: begin
                fill_wb_prime_wait <= 1'b1;
                st <= S_FILL_WB_PRIME;
            end
            S_FILL_WB_PRIME: begin
                if( fill_wb_prime_wait ) begin
                    fill_wb_prime_wait <= 1'b0;
                end else begin
                    fill_after_wb <= 1'b0;
                    if( ext_rdy || LAST_WORD == {WW{1'b0}} ) begin
                        stream_word       <= {WW{1'b0}};
                        fill_tail_seen    <= 1'b0;
                        st                <= S_POSTFILL_WAIT;
                    end else begin
                        stream_word <= WW'(1);
                        st          <= S_FILL_STREAM;
                    end
                end
            end
            S_FILL_STREAM: begin
                if( fill_stream_dok ) begin
                    if( ext_rdy ) begin
                        stream_word       <= {WW{1'b0}};
                        fill_tail_seen    <= 1'b0;
                        fill_after_wb     <= 1'b0;
                        st                <= S_POSTFILL_WAIT;
                    end else if( stream_word != LAST_WORD ) begin
                        stream_word <= stream_word + 1'd1;
                    end else begin
                        fill_tail_seen <= 1'b1;
                    end
                end
            end
            S_POSTFILL_WAIT: begin
                if( req_wr_l ) st <= S_WR_COMMIT;
                else           st <= S_RD_RESP;
            end
            default: begin
                st <= S_IDLE;
            end
        endcase
    end
end

endmodule
