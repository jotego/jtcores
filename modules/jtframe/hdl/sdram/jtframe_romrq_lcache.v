/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 24-8-2026 */

// Direct-mapped ROM cache for the short-burst SDRAM controller.
// Cache lines are exactly one controller burst: 16, 32, or 64 bits.
// Latency: 1 clock + SDRAM service time (if cache miss)
module jtframe_romrq_lcache #(parameter
    SDRAMW   = 22,
    AW       = 18,
    DW       =  8,
    CACHE_SIZE=1024,
    BURSTLEN = 32
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
localparam LINE_AW       = BURSTLEN == 64 ? 2 : (BURSTLEN == 32 ? 1 : 0);
localparam LINE_INDEX_AW = CACHE_AW-1-LINE_AW;
localparam CACHE_LINES   = 1<<LINE_INDEX_AW;

wire [SDRAMW-1:0] addr_word;
wire [SDRAMW-1:0] line_addr;
wire [LINE_INDEX_AW-1:0] line_index;
wire [SDRAMW-CACHE_AW:0] tag;
wire               hit, cache_data_match;
wire               fill_write;
wire               fill_done;
reg                hit_l, fill_ok, filling, receiving;
reg [ 1:0]         fill_beat;
reg [LINE_INDEX_AW-1:0] read_line_l;
reg [SDRAMW-CACHE_AW:0] read_tag_l;
reg [LINE_INDEX_AW-1:0] fill_line;
reg [SDRAMW-CACHE_AW:0] fill_tag;
reg [CACHE_LINES-1:0] valid;
reg [SDRAMW-CACHE_AW:0] tags[0:CACHE_LINES-1];
reg [63:0]        fill_data, nx_fill_data;
wire [BURSTLEN-1:0] cache_data, pre_dout;

assign addr_word  = offset + (DW == 8 ? {{(SDRAMW-AW){1'b0}},addr}>>1 : {{(SDRAMW-AW){1'b0}},addr});
assign line_addr  = LINE_AW == 0 ? addr_word :
                    LINE_AW == 1 ? {addr_word[SDRAMW-1:1],1'b0} :
                                   {addr_word[SDRAMW-1:2],2'b0};
assign line_index = addr_word[CACHE_AW-2:LINE_AW];
assign tag        = addr_word[SDRAMW-1:CACHE_AW-1];
assign hit        = valid[line_index] && tags[line_index] == tag;
assign cache_data_match = line_index == read_line_l && tag == read_tag_l;
assign req        = addr_ok && !hit && !filling;
assign sdram_addr = line_addr;
assign data_ok    = addr_ok && hit && !filling &&
                    (fill_ok || (hit_l && cache_data_match));
assign fill_write = we && (dst || receiving);
assign fill_done  = fill_write && din_ok;
assign pre_dout   = fill_ok ? fill_data[BURSTLEN-1:0] : cache_data;

jtframe_rpwp_ram #(.DW(BURSTLEN),.AW(LINE_INDEX_AW)) u_ram(
    .clk     ( clk        ),
    .rd_addr ( line_index ),
    .dout    ( cache_data ),
    .wr_addr ( fill_line  ),
    .din     ( nx_fill_data[BURSTLEN-1:0] ),
    .we      ( fill_done  )
);

always @(*) begin
    nx_fill_data = fill_data;
    if( fill_write ) begin
        case( filling ? fill_beat : 0 )
            0: nx_fill_data[15: 0] = din;
            1: nx_fill_data[31:16] = din;
            2: nx_fill_data[47:32] = din;
            3: nx_fill_data[63:48] = din;
        endcase
    end
end

generate
    if( DW == 8 ) begin : gen_byte
        if( BURSTLEN == 16 ) begin : gen_burst16
            assign dout = addr[0] ? pre_dout[15:8] : pre_dout[7:0];
        end else if( BURSTLEN == 32 ) begin : gen_burst32
            assign dout = addr[1] ? (addr[0] ? pre_dout[31:24] : pre_dout[23:16]) :
                                    (addr[0] ? pre_dout[15: 8] : pre_dout[ 7: 0]);
        end else begin : gen_burst64
            assign dout = addr[2] ? (addr[1] ? (addr[0] ? pre_dout[63:56] : pre_dout[55:48]) :
                                              (addr[0] ? pre_dout[47:40] : pre_dout[39:32])) :
                                    (addr[1] ? (addr[0] ? pre_dout[31:24] : pre_dout[23:16]) :
                                              (addr[0] ? pre_dout[15: 8] : pre_dout[ 7: 0]));
        end
    end else if( DW == 16 ) begin : gen_word
        if( BURSTLEN == 16 ) begin : gen_burst16
            assign dout = pre_dout[15:0];
        end else if( BURSTLEN == 32 ) begin : gen_burst32
            assign dout = addr[0] ? pre_dout[31:16] : pre_dout[15:0];
        end else begin : gen_burst64
            assign dout = addr[1] ? (addr[0] ? pre_dout[63:48] : pre_dout[47:32]) :
                                    (addr[0] ? pre_dout[31:16] : pre_dout[15: 0]);
        end
    end else begin : gen_long
        if( BURSTLEN == 32 ) begin : gen_burst32
            assign dout = pre_dout[31:0];
        end else if( BURSTLEN == 64 ) begin : gen_burst64
            assign dout = addr[1] ? pre_dout[63:32] : pre_dout[31:0];
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
        fill_beat <= 0;
        read_line_l <= 0;
        read_tag_l  <= 0;
        fill_line <= 0;
        fill_tag  <= 0;
        fill_data <= 0;
        valid     <= 0;
    end else begin
        hit_l <= hit && addr_ok && !filling;
        fill_ok <= fill_done;
        read_line_l <= line_index;
        read_tag_l  <= tag;
        if( clr ) valid <= 0;
        if( we && !filling ) begin
            filling   <= 1;
            fill_beat <= 0;
            fill_line <= line_index;
            fill_tag  <= tag;
        end
        if( fill_write ) begin
            fill_data <= nx_fill_data;
            fill_beat <= filling ? fill_beat + 1'd1 : 1;
            receiving <= !din_ok;
            if( fill_done ) begin
                valid[fill_line] <= 1;
                tags[fill_line]  <= fill_tag;
                filling           <= 0;
                receiving         <= 0;
            end
        end
    end
end

`ifdef SIMULATION
initial begin
    if( BURSTLEN != 16 && BURSTLEN != 32 && BURSTLEN != 64 )
        $error("%m BURSTLEN must be 16, 32, or 64 bits");
    if( BURSTLEN < DW )
        $error("%m BURSTLEN must be at least the client data width");
    if( CACHE_SIZE < 1024 || (CACHE_SIZE & (CACHE_SIZE-1)) != 0 )
        $error("%m CACHE_SIZE must be a power of two and at least 1kB");
end
`endif

endmodule
