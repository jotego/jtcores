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
    Version: 2.1
    Date: 19-3-2026 */

module jtframe_cache #(parameter
    BLOCKS  =    8,
    BLKSIZE = 1024,
    AW      =   24,
    DW      =    8,
    ENDIAN  =    0,
    EW      =   24,
    AW0     = DW==32 ? 2 : DW==16 ? 1 : 0
)(
    input                   rst,
    input                   clk,

    input      [AW-1:AW0]   addr,
    output reg [DW-1:0]     dout,
    input                   rd,
    output reg              ok,

    output     [EW-1:1]     ext_addr,
    input      [15:0]       ext_din,
    output reg              ext_rd,
    input                   ext_ack,
    input                   ext_dst,
    input                   ext_dok,
    input                   ext_rdy
);

localparam integer BW     = BLOCKS < 2 ? 1 : $clog2(BLOCKS);
localparam integer UW     = AW-AW0;
localparam integer UBYTES = DW >> 3;
localparam integer DEPTH  = BLKSIZE / UBYTES;
localparam integer OFFW   = DEPTH < 2 ? 1 : $clog2(DEPTH);
localparam integer TAGW   = UW - OFFW;
localparam integer WORDS  = BLKSIZE >> 1;
localparam integer WW     = WORDS < 2 ? 1 : $clog2(WORDS);
localparam [WW-1:0] LAST_WORD = WW'(WORDS-1);

reg [TAGW-1:0] tag_mem[0:BLOCKS-1];
reg [BLOCKS-1:0] valid;
reg [15:0] lfsr;

reg [AW-1:AW0] pend_addr;
reg [TAGW-1:0] pend_tag;
reg [OFFW-1:0] pend_off;
reg [BW-1:0]   fill_blk;
reg [BW-1:0]   hit_blk;
reg [WW-1:0]   fill_word;
reg [DW-1:0]   fill_resp;
reg            miss_busy;
reg            wait_data;
reg            fill_active;
reg            hit_sel;
reg            fill_done;

reg            hit_now;
reg [BW-1:0]   hit_blk_now;

wire [UW-1:0] req_addr   = addr;
wire [UW-1:0] pend_uaddr = pend_addr;
wire [TAGW-1:0] req_tag  = req_addr[UW-1:OFFW];
wire [OFFW-1:0] req_off  = req_addr[OFFW-1:0];
wire [UW-1:0] base_addr  = { pend_uaddr[UW-1:OFFW], {OFFW{1'b0}} };
wire [AW-1:0] base_byte  = { base_addr, {AW0{1'b0}} };
wire [BW-1:0] victim     = lfsr[BW-1:0];
wire          wr_en      = wait_data && ext_dok;

wire [DW-1:0] hit_data;
wire          fill_capture;
wire          fill_last;
wire [DW-1:0] fill_capture_data;

assign fill_last = fill_word == LAST_WORD;

integer i;

assign ext_addr = { {(EW-AW){1'b0}}, base_byte[AW-1:1] };

always @* begin
    hit_now = 0;
    hit_blk_now = {BW{1'b0}};
    for(i=0; i<BLOCKS; i=i+1) begin
        if( valid[i] && req_tag == tag_mem[i] ) begin
            hit_now = 1;
            hit_blk_now = i[BW-1:0];
        end
    end
end

generate
    if( DW==8 ) begin : gen_dw8
        localparam integer RW = WORDS < 2 ? 1 : $clog2(WORDS);

        wire [RW-1:0] rd_word = hit_sel ? pend_off[OFFW-1:1] : req_off[OFFW-1:1];
        wire [7:0] q_lo[0:BLOCKS-1];
        wire [7:0] q_hi[0:BLOCKS-1];

        assign hit_data = pend_off[0] ? q_hi[hit_blk] : q_lo[hit_blk];
        assign fill_capture = pend_off[OFFW-1:1] == fill_word[RW-1:0];
        assign fill_capture_data = pend_off[0] ? ext_din[15:8] : ext_din[7:0];

        genvar gi8;
        for(gi8=0; gi8<BLOCKS; gi8=gi8+1) begin : blk8
            jtframe_dual_ram #(.DW(8), .AW(RW)) u_lo(
                .clk0  ( clk                     ),
                .data0 ( ext_din[7:0]           ),
                .addr0 ( fill_word[RW-1:0]      ),
                .we0   ( wr_en && fill_blk==gi8 ),
                .q0    (                         ),
                .clk1  ( clk                     ),
                .data1 ( 8'd0                    ),
                .addr1 ( rd_word                 ),
                .we1   ( 1'b0                    ),
                .q1    ( q_lo[gi8]               )
            );

            jtframe_dual_ram #(.DW(8), .AW(RW)) u_hi(
                .clk0  ( clk                     ),
                .data0 ( ext_din[15:8]          ),
                .addr0 ( fill_word[RW-1:0]      ),
                .we0   ( wr_en && fill_blk==gi8 ),
                .q0    (                         ),
                .clk1  ( clk                     ),
                .data1 ( 8'd0                    ),
                .addr1 ( rd_word                 ),
                .we1   ( 1'b0                    ),
                .q1    ( q_hi[gi8]               )
            );
        end
    end else if( DW==16 ) begin : gen_dw16
        localparam integer RW = DEPTH < 2 ? 1 : $clog2(DEPTH);

        wire [RW-1:0] rd_word = hit_sel ? pend_off : req_off;
        wire [15:0] q_mem[0:BLOCKS-1];

        assign hit_data = q_mem[hit_blk];
        assign fill_capture = pend_off == fill_word[RW-1:0];
        assign fill_capture_data = ext_din;

        genvar gi16;
        for(gi16=0; gi16<BLOCKS; gi16=gi16+1) begin : blk16
            jtframe_dual_ram #(.DW(16), .AW(RW)) u_mem(
                .clk0  ( clk                      ),
                .data0 ( ext_din                  ),
                .addr0 ( fill_word[RW-1:0]       ),
                .we0   ( wr_en && fill_blk==gi16 ),
                .q0    (                          ),
                .clk1  ( clk                      ),
                .data1 ( 16'd0                    ),
                .addr1 ( rd_word                  ),
                .we1   ( 1'b0                     ),
                .q1    ( q_mem[gi16]              )
            );
        end
    end else begin : gen_dw32
        localparam integer D32 = BLKSIZE >> 2;
        localparam integer RW  = D32 < 2 ? 1 : $clog2(D32);

        reg [15:0] fill_lo;
        wire [RW-1:0] rd_word = hit_sel ? pend_off : req_off;
        wire [15:0] q_lo[0:BLOCKS-1];
        wire [15:0] q_hi[0:BLOCKS-1];
        wire        lo_wr_sel = ENDIAN ? fill_word[0]  : !fill_word[0];
        wire        hi_wr_sel = ENDIAN ? !fill_word[0] : fill_word[0];
        wire [31:0] fill_pair = ENDIAN ? { fill_lo, ext_din } : { ext_din, fill_lo };

        assign hit_data = { q_hi[hit_blk], q_lo[hit_blk] };
        assign fill_capture = fill_word[0] && (pend_off == fill_word[WW-1:1]);
        assign fill_capture_data = fill_pair;

        always @(posedge clk) begin
            if( rst ) begin
                fill_lo <= 0;
            end else if( wr_en && !fill_word[0] ) begin
                fill_lo <= ext_din;
            end
        end

        genvar gi32;
        for(gi32=0; gi32<BLOCKS; gi32=gi32+1) begin : blk32
            wire lo_wr = wr_en && lo_wr_sel && fill_blk==gi32;
            wire hi_wr = wr_en && hi_wr_sel && fill_blk==gi32;

            jtframe_dual_ram #(.DW(16), .AW(RW)) u_lo(
                .clk0  ( clk                 ),
                .data0 ( ext_din             ),
                .addr0 ( fill_word[WW-1:1]   ),
                .we0   ( lo_wr               ),
                .q0    (                     ),
                .clk1  ( clk                 ),
                .data1 ( 16'd0               ),
                .addr1 ( rd_word             ),
                .we1   ( 1'b0                ),
                .q1    ( q_lo[gi32]          )
            );

            jtframe_dual_ram #(.DW(16), .AW(RW)) u_hi(
                .clk0  ( clk                 ),
                .data0 ( ext_din             ),
                .addr0 ( fill_word[WW-1:1]   ),
                .we0   ( hi_wr               ),
                .q0    (                     ),
                .clk1  ( clk                 ),
                .data1 ( 16'd0               ),
                .addr1 ( rd_word             ),
                .we1   ( 1'b0                ),
                .q1    ( q_hi[gi32]          )
            );
        end
    end
endgenerate

always @(posedge clk) begin
    if( rst ) begin
        valid       <= 0;
        dout        <= 0;
        ok          <= 0;
        ext_rd      <= 0;
        pend_addr   <= 0;
        pend_tag    <= 0;
        pend_off    <= 0;
        fill_blk    <= 0;
        hit_blk     <= 0;
        fill_word   <= 0;
        fill_resp   <= 0;
        miss_busy   <= 0;
        wait_data   <= 0;
        fill_active <= 0;
        hit_sel     <= 0;
        fill_done   <= 0;
        lfsr        <= 16'h1;
    end else begin
        lfsr <= {lfsr[14:0], lfsr[15]^lfsr[13]^lfsr[12]^lfsr[10]};

        if( fill_done ) begin
            dout <= fill_resp;
            ok   <= 1;
            fill_done <= 0;
        end else if( hit_sel ) begin
            dout <= hit_data;
            ok   <= 1;
            hit_sel <= 0;
        end else begin
            ok <= 0;
        end

        if( rd && hit_now && !miss_busy ) begin
            hit_blk  <= hit_blk_now;
            pend_off <= req_off;
            hit_sel  <= 1;
        end else if( rd && !hit_now && !miss_busy ) begin
            pend_addr   <= addr;
            pend_tag    <= req_tag;
            pend_off    <= req_off;
            fill_blk    <= victim;
            fill_word   <= 0;
            ext_rd      <= 1;
            miss_busy   <= 1;
            wait_data   <= 0;
            fill_active <= 0;
            fill_done   <= 0;
            hit_sel     <= 0;
        end

        if( ext_rd && ext_ack ) begin
            wait_data <= 1;
        end

        if( wr_en ) begin
            fill_active <= !(ext_rdy || fill_last);
            if( fill_capture ) fill_resp <= fill_capture_data;
            if( fill_last ) ext_rd <= 0;
            fill_word <= fill_last ? 0 : fill_word + 1'd1;
            if( ext_rdy ) begin
                valid[fill_blk] <= 1;
                tag_mem[fill_blk] <= pend_tag;
                miss_busy <= 0;
                wait_data <= 0;
                fill_done <= 1;
                fill_word <= 0;
            end
        end

        if( wait_data && ext_rdy && !wr_en ) begin
            valid[fill_blk] <= 1;
            tag_mem[fill_blk] <= pend_tag;
            miss_busy <= 0;
            wait_data <= 0;
            fill_done <= 1;
            fill_word <= 0;
        end
    end
end

endmodule
