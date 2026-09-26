/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 24-8-2026 */

// Direct-mapped ROM cache for the short-burst SDRAM controller.
// Cache lines are exactly one controller burst: 16, 32, 64, or 128 bits.
// Latency: 1 clock, or 2 with TAG_RAM, plus SDRAM service time on a miss.
module jtframe_romrq_lcache #(parameter
    SDRAMW   = 22,
    AW       = 18,
    DW       =  8,
    CACHE_SIZE=1024,
    BURSTLEN = 32,
    TAG_RAM  =  0 // set to 1 to use synchronous block RAM for cache tags
)(
    input               rst,
    input               clk,

    input               clr,
    input [SDRAMW-1:0]  offset,

    input [15:0]        din,
    input               din_ok,
    input               dst,
    input               we,
    output              req,
    output [SDRAMW-1:0] sdram_addr,

    input [AW-1:0]      addr,
    input               addr_ok,
    output              data_ok,
    output [DW-1:0]     dout
);

localparam CACHE_AW      = $clog2(CACHE_SIZE);
// sysfl: the sprite ROM slot (32-bit, 64-bit bursts) uses 16-byte lines so
// one miss brings a whole 16x16x8bpp tile row in two chained bursts
// the 4kB caches serve scattered minified sampling (roz): short single-burst
// lines halve the miss round trip there; 16-byte lines stay for the 1kB slots
localparam LINE2X        = (DW==32 && BURSTLEN==64 && CACHE_SIZE<4096) ? 1 : 0;
// LINE2X keeps combinational tags; the tag cone is short enough at 96 MHz
localparam TAG_EFF       = LINE2X==1 ? 0 : TAG_RAM;
localparam BURST_AW      = BURSTLEN == 128 ? 3 : BURSTLEN == 64 ? 2 : (BURSTLEN == 32 ? 1 : 0);
localparam LINE_AW       = BURST_AW + LINE2X;
localparam LINE_INDEX_AW = CACHE_AW-1-LINE_AW;
localparam CACHE_LINES   = 1<<LINE_INDEX_AW;
localparam LINEW         = BURSTLEN << LINE2X;
localparam BEATW         = BURSTLEN == 128 ? 3 : 2;

wire [SDRAMW-1:0] addr_word;
wire [SDRAMW-1:0] line_addr;
wire [LINE_INDEX_AW-1:0] line_index;
wire [SDRAMW-CACHE_AW:0] tag;
wire               hit, cache_data_match, fill_data_match;
wire               fill_write;
wire               fill_done;
wire               tag_hit, tag_data_ok;
reg                hit_l, fill_ok, filling, receiving, req_pending;
reg                addr_ok_l, valid_l;
reg [BEATW-1:0]    fill_beat;
reg [LINE_INDEX_AW-1:0] read_line_l;
reg [SDRAMW-CACHE_AW:0] read_tag_l;
reg [AW-1:0]       read_addr_l;
reg [LINE_INDEX_AW-1:0] req_line;
reg [SDRAMW-CACHE_AW:0] req_tag;
reg [LINE_INDEX_AW-1:0] fill_line;
reg [SDRAMW-CACHE_AW:0] fill_tag;
reg [CACHE_LINES-1:0] valid;
localparam FDW = (LINE2X==1 || BURSTLEN==128) ? 128 : 64; // staging width, range-safe for all slots
localparam FHI = LINE2X==1 ? 64 : 0;     // high-half base (dead when LINE2X==0)
localparam BAW = BURSTLEN==128 ? 128 : 64; // single-burst assembler width
reg [FDW-1:0]     fill_data;
reg [BAW-1:0]     nx_fill_data;
reg               fill_half;   // LINE2X: second burst of the line in flight
reg  [BAW-1:0]    burst_acc;   // current-burst word assembler (feeds nx_fill_data)
wire [LINEW-1:0]  cache_data;
wire [LINEW-1:0]  pre_dout;
wire [AW-1:0]       read_addr;

assign addr_word  = offset + (DW == 8 ? {{(SDRAMW-AW){1'b0}},addr}>>1 : {{(SDRAMW-AW){1'b0}},addr});
assign line_addr  = LINE_AW == 0 ? addr_word :
                    LINE_AW == 1 ? {addr_word[SDRAMW-1:1],1'b0} :
                    LINE_AW == 2 ? {addr_word[SDRAMW-1:2],2'b0} :
                                   {addr_word[SDRAMW-1:3],3'b0};
assign line_index = addr_word[CACHE_AW-2:LINE_AW];
assign tag        = addr_word[SDRAMW-1:CACHE_AW-1];
assign hit        = tag_hit;
assign cache_data_match = line_index == read_line_l && tag == read_tag_l;
assign fill_data_match = read_line_l == fill_line && read_tag_l == fill_tag;
wire fill2_req    = LINE2X==1 && filling && fill_half && !receiving && fill_beat==0;
assign req        = fill2_req ||
                    (TAG_EFF ? addr_ok_l && !hit && !(fill_ok && fill_data_match) && !filling :
                               addr_ok && !hit && !filling);
// A lower-priority slot can remain pending while the client advances to its
// next address. Keep the SDRAM address paired with the tag and line captured
// when req was first asserted, until that request starts filling.
wire [LINE_AW-1:0] line_lo = fill_half ? {1'b1,{BURST_AW{1'b0}}} : {LINE_AW{1'b0}};
assign sdram_addr = (LINE2X==1 && filling) ? { fill_tag, fill_line, line_lo } :
                    req_pending ? { req_tag, req_line, {LINE_AW{1'b0}} } :
                    TAG_EFF ? { read_tag_l, read_line_l, {LINE_AW{1'b0}} } : line_addr;
// the fill fast path must be address-exact: a client may move to another
// line while a fill completes (e.g. the shared scr tile+mask port)
wire fill_addr_match = line_index == fill_line && tag == fill_tag;
assign data_ok    = TAG_EFF ? addr_ok_l && !filling &&
                              (tag_data_ok ||
                               (fill_ok && fill_data_match)) :
                            addr_ok && hit && !filling &&
                              ((fill_ok && fill_addr_match) ||
                               (hit_l && cache_data_match));
assign fill_write = we && (dst || receiving);
assign fill_done  = fill_write && din_ok;
assign pre_dout   = fill_ok && (TAG_EFF ? fill_data_match : fill_addr_match)
                    ? fill_data[LINEW-1:0] : cache_data;
assign read_addr  = TAG_EFF ? read_addr_l : addr;

jtframe_rpwp_ram #(.DW(LINEW),.AW(LINE_INDEX_AW)) u_ram(
    .clk     ( clk        ),
    .rd_addr ( line_index ),
    .dout    ( cache_data ),
    .wr_addr ( fill_line  ),
    .din     ( fill_wdata ),
    .we      ( line_done  )
);
// LINE2X: the tag/valid/data commit waits for both bursts
wire line_done = LINE2X==0 ? fill_done : (fill_done && fill_half);
wire [LINEW-1:0] fill_wdata;
generate
    if( LINE2X==1 ) begin : g_wdata2x
        assign fill_wdata = { nx_fill_data, fill_data[63:0] };
    end else begin : g_wdata1x
        assign fill_wdata = nx_fill_data[LINEW-1:0]; // LINEW<=BAW here
    end
endgenerate

generate
    if( TAG_EFF ) begin : gen_tag_ram
        wire [SDRAMW-CACHE_AW:0] tag_q1_unused;
        wire [SDRAMW-CACHE_AW:0] tag_q;

        assign tag_hit = valid_l && tag_q == read_tag_l;
        // Fuse the stable-address hit checks into one mismatch tree. This is
        // equivalent to hit && hit_l && cache_data_match without duplicating
        // the read-tag comparison on the response path.
        assign tag_data_ok = ~|{~valid_l, ~hit_l,
                               line_index ^ read_line_l,
                               (tag_q ^ read_tag_l) | (tag ^ read_tag_l)};

        jtframe_dual_ram #(
            .DW( SDRAMW-CACHE_AW+1 ),
            .AW( LINE_INDEX_AW      )
        ) u_tag_ram (
            .clk0 ( clk        ),
            .data0( {SDRAMW-CACHE_AW+1{1'b0}} ),
            .addr0( line_index ),
            .we0  ( 1'b0       ),
            .q0   ( tag_q      ),
            .clk1 ( clk        ),
            .data1( fill_tag   ),
            .addr1( fill_line  ),
            .we1  ( fill_done  ),
            .q1   ( tag_q1_unused )
        );
    end else begin : gen_direct_tags
        (* ramstyle = "MLAB, no_rw_check" *) reg [SDRAMW-CACHE_AW:0] tags[0:CACHE_LINES-1];

        assign tag_hit = valid[line_index] && tags[line_index] == tag;
        assign tag_data_ok = 1'b0;

        always @(posedge clk) if( fill_done ) tags[fill_line] <= fill_tag;
    end
endgenerate

generate
    if( BURSTLEN == 128 ) begin : gen_asm128
        always @(*) begin
            nx_fill_data = burst_acc;
            if( fill_write ) begin
                case( filling ? fill_beat : 0 )
                    0: nx_fill_data[ 15:  0] = din;
                    1: nx_fill_data[ 31: 16] = din;
                    2: nx_fill_data[ 47: 32] = din;
                    3: nx_fill_data[ 63: 48] = din;
                    4: nx_fill_data[ 79: 64] = din;
                    5: nx_fill_data[ 95: 80] = din;
                    6: nx_fill_data[111: 96] = din;
                    7: nx_fill_data[127:112] = din;
                endcase
            end
        end
    end else begin : gen_asm64
        always @(*) begin
            nx_fill_data = burst_acc;
            if( fill_write ) begin
                case( filling ? fill_beat : 0 )
                    0: nx_fill_data[15: 0] = din;
                    1: nx_fill_data[31:16] = din;
                    2: nx_fill_data[47:32] = din;
                    3: nx_fill_data[63:48] = din;
                endcase
            end
        end
    end
endgenerate

generate
    if( DW == 8 ) begin : gen_byte
        if( BURSTLEN == 16 ) begin : gen_burst16
            assign dout = read_addr[0] ? pre_dout[15:8] : pre_dout[7:0];
        end else if( BURSTLEN == 32 ) begin : gen_burst32
            assign dout = read_addr[1] ? (read_addr[0] ? pre_dout[31:24] : pre_dout[23:16]) :
                                         (read_addr[0] ? pre_dout[15: 8] : pre_dout[ 7: 0]);
        end else if( BURSTLEN == 64 ) begin : gen_burst64
            assign dout = read_addr[2] ? (read_addr[1] ? (read_addr[0] ? pre_dout[63:56] : pre_dout[55:48]) :
                                                        (read_addr[0] ? pre_dout[47:40] : pre_dout[39:32])) :
                                         (read_addr[1] ? (read_addr[0] ? pre_dout[31:24] : pre_dout[23:16]) :
                                                        (read_addr[0] ? pre_dout[15: 8] : pre_dout[ 7: 0]));
        end else begin : gen_burst128
            assign dout = pre_dout[ {read_addr[3:0],3'd0} +: 8 ];
        end
    end else if( DW == 64 ) begin : gen_wide // whole 64-bit burst line (roz woven units)
        assign dout = pre_dout[63:0];
    end else if( DW == 16 ) begin : gen_word
        if( BURSTLEN == 16 ) begin : gen_burst16
            assign dout = pre_dout[15:0];
        end else if( BURSTLEN == 32 ) begin : gen_burst32
            assign dout = read_addr[0] ? pre_dout[31:16] : pre_dout[15:0];
        end else begin : gen_burst64
            assign dout = read_addr[1] ? (read_addr[0] ? pre_dout[63:48] : pre_dout[47:32]) :
                                         (read_addr[0] ? pre_dout[31:16] : pre_dout[15: 0]);
        end
    end else begin : gen_long
        if( LINE2X == 1 || BURSTLEN == 128 ) begin : gen_line128
            assign dout = read_addr[2] ? (read_addr[1] ? pre_dout[127:96] : pre_dout[95:64])
                                       : (read_addr[1] ? pre_dout[ 63:32] : pre_dout[31: 0]);
        end else if( BURSTLEN == 32 ) begin : gen_burst32
            assign dout = pre_dout[31:0];
        end else if( BURSTLEN == 64 ) begin : gen_burst64
            assign dout = read_addr[1] ? pre_dout[63:32] : pre_dout[31:0];
        end else begin : gen_invalid
            assign dout = 0;
        end
    end
endgenerate

always @(posedge clk) begin
    if( rst ) begin
        hit_l     <= 0;
        fill_ok   <= 0;
        filling   <= 0;
        receiving <= 0;
        req_pending <= 0;
        fill_beat <= 0;
        read_line_l <= 0;
        read_tag_l  <= 0;
        read_addr_l <= 0;
        addr_ok_l   <= 0;
        valid_l     <= 0;
        req_line  <= 0;
        req_tag   <= 0;
        fill_line <= 0;
        fill_tag  <= 0;
        fill_data <= 0;
        fill_half <= 0;
        burst_acc <= 0;
        valid     <= 0;
    end else begin
        hit_l <= hit && (TAG_EFF ? addr_ok_l : addr_ok) && !filling;
        fill_ok <= line_done;
        read_line_l <= line_index;
        read_tag_l  <= tag;
        read_addr_l <= addr;
        addr_ok_l   <= addr_ok;
        valid_l     <= valid[line_index];
        // A slot may select this request after the client changes address.
        if( req && !req_pending && !filling ) begin
            req_pending <= 1;
            req_line    <= TAG_EFF ? read_line_l : line_index;
            req_tag     <= TAG_EFF ? read_tag_l  : tag;
        end
        if( clr ) valid <= 0;
        if( we && !filling ) begin
            filling   <= 1;
            fill_half <= 0;
            fill_beat <= 0;
            fill_line <= req_line;
            fill_tag  <= req_tag;
            req_pending <= 0;
        end
        if( fill_write ) begin
            burst_acc <= fill_done ? {BAW{1'b0}} : nx_fill_data;
            if( LINE2X==1 && fill_half )
                fill_data[FHI +: 64] <= nx_fill_data;
            else
                fill_data[BAW-1:0] <= nx_fill_data;
            fill_beat <= filling ? fill_beat + 1'd1 : 1;
            receiving <= !din_ok;
            if( fill_done ) begin
                receiving <= 0;
                fill_beat <= 0;
                if( LINE2X==1 && !fill_half ) begin
                    fill_half <= 1;      // second burst of the line follows
                end else begin
                    valid[fill_line] <= 1;
                    filling          <= 0;
                    fill_half        <= 0;
                end
            end
        end
    end
end

`ifdef SIMULATION
initial begin
    if( BURSTLEN != 16 && BURSTLEN != 32 && BURSTLEN != 64 && BURSTLEN != 128 )
        $error("%m BURSTLEN must be 16, 32, 64, or 128 bits");
    if( BURSTLEN == 128 && DW == 16 )
        $error("%m BURSTLEN 128 requires DW 32");
    if( BURSTLEN < DW )
        $error("%m BURSTLEN must be at least the client data width");
    if( CACHE_SIZE < 1024 || (CACHE_SIZE & (CACHE_SIZE-1)) != 0 )
        $error("%m CACHE_SIZE must be a power of two and at least 1kB");
    if( LINE2X == 1 && TAG_EFF == 1 ) // unreachable: TAG_EFF demotes
        $error("%m LINE2X does not support TAG_EFF");
end
`endif

endmodule
