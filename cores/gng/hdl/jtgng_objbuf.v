/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 11-1-2019 */

// Original hardware had at least two variants:
// 24 sprites per line: GnG, Commando... the buffer ran at 6MHz
// 32 sprites per line: Tiger Road, Bionic Commando... ran at 8MHz

// Comparison of resources, the old version
// was used upto commit ac7aef116158
//      LC / Regs / M9K
// Old 126 / 39   / 2
// New 102 / 31   / 1

module jtgng_objbuf #(parameter
    DW          = 8,
    AW          = 9,
    LAYOUT      = 0,
    OBJMAX      = 10'h180, // 180h for 96 objects (GnG)
    OBJMAX_LINE = 6'd24
) (
    input               rst,
    input               clk,
    (*direct_enable*) input draw_cen,
    // screen
    input               HINIT_draw,
    input               LVBL,
    input       [7:0]   V,
    output reg  [7:0]   VF,
    input               flip,
    // sprite data scan
    output reg [AW-1:0] pre_scan,
    input      [DW-1:0] dma_dout,
    // sprite data buffer
    output reg [DW-1:0] objbuf_data,
    input       [4:0]   objcnt,
    input       [3:0]   pxlcnt,
    input               rom_wait,
    output reg          line
);

// sprite buffer
reg          fill;
reg  [5:0]   post_scan;
reg          line_obj_we;

localparam lineA=1'b0, lineB=1'b1;
localparam THREE=3;
wire [DW-1:0] q_a, q_b;
wire [6:0] hscan = { objcnt, pxlcnt[1:0] };

reg trf_state;

localparam SEARCH=1'b0, TRANSFER=1'b1;

always @(posedge clk, posedge rst) begin
    if( rst )
        line <= lineA;
    else if(draw_cen) begin
        if( HINIT_draw ) begin
            VF <= {8{flip}} ^ V;
            line <= ~line;
        end
    end
end

reg [8:0] Vsum;
reg       MATCH;
reg       pre_scan_msb;
reg [1:0] extend;

localparam BIT8   = DW-4; // This will be 8 when DW==12. (Verilator workaround)
localparam EXTBIT = LAYOUT==9 ? 10 : 0;

always @(*) begin
    Vsum  = {1'b0, dma_dout[7:0]} + {1'b0,(~VF + { {6{~flip}}, 2'b10 })};
    MATCH =
        LAYOUT == 9 /* SF */ ? &Vsum[7:5] :
        DW==8 ? &Vsum[7:4] // 8-bit games: GnG, GunSmoke...
        :  &{ ~^{dma_dout[BIT8],Vsum[8]}, Vsum[7:4] };  // 16-bit games: Tora, Biocom...
end

localparam DMAEND = OBJMAX-1;
wire       dmaend     = {pre_scan_msb,pre_scan}>=DMAEND;
wire [5:0] objcnt_end = OBJMAX_LINE-6'd1;

always @(posedge clk, posedge rst)
    if( rst ) begin
        trf_state   <= SEARCH;
        line_obj_we <= 0;
        extend      <= 2'd0;
    end
    else if(draw_cen) begin
        case( trf_state )
            SEARCH: begin
                line_obj_we <= 0;
                extend      <= 2'd0;
                if( !LVBL || fill || dmaend ) begin
                    {pre_scan_msb, pre_scan} <= 2;
                    post_scan<= 6'd0; // store obj data in reverse order
                    // so we can print them in straight order while taking
                    // advantage of horizontal blanking to avoid graphic clash
                    if( HINIT_draw ) fill <= 0; // gets out of this state at this signal
                    else if(dmaend) fill <= 1;
                end
                else begin
                    //if( dma_dout<=(VF+'d3) && (dma_dout+8'd12)>=VF  ) begin
                    if( MATCH ) begin
                        pre_scan[1:0] <= 2'd0;
                        line_obj_we <= 1'b1;
                        trf_state <= TRANSFER;
                    end
                    else begin
                        if( dmaend ) begin
                            fill <= 1'b1;
                        end else begin
                            /* verilator lint_off WIDTH */
                            {pre_scan_msb,pre_scan} <= {pre_scan_msb,pre_scan} + 3'd4;
                            /* verilator lint_on WIDTH */
                        end
                    end
                end
            end
            TRANSFER: begin
                // line_obj_we <= 1'b0;
                if( pre_scan[1:0]==2'b11 ) begin
                    if( post_scan == objcnt_end ) begin // Transfer done before the end of the line
                        line_obj_we <= 1'b0;
                        trf_state <= SEARCH;
                        fill <= 1'd1;
                    end else begin
                        post_scan <= post_scan+1'b1;
                        if( !extend[0] ) begin
                            // advance to next obj
                            pre_scan <= pre_scan + THREE[AW-1:0];
                            trf_state  <= SEARCH;
                            line_obj_we <= 1'b0;
                        end else begin
                            // repeat and modify ID/X
                            extend[1] <= 1;
                            pre_scan[1:0] <= 2'd0;
                        end
                    end
                end
                else begin
                    pre_scan[1:0] <= pre_scan[1:0]+1'b1;
                    if( LAYOUT==9 && pre_scan[1:0]==2'd1 ) begin
                        extend[0] <= extend[0] ^ dma_dout[EXTBIT];
                    end
                end
            end
        endcase
    end

reg     [2:0] we_clr;
reg     [7:0] wr_addr, rd_addr;
reg           wr_en;
reg  [DW-1:0] wr_data;
wire [DW-1:0] pre_q;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        we_clr      <= 0;
        objbuf_data <= 0;
    end else begin
        we_clr <= { we_clr[1:0], draw_cen & ~rom_wait};
        if( we_clr[1] ) objbuf_data <= pre_q;
    end
end

localparam [DW-1:0] CLRVAL = 'hF8;

function [DW-1:0] apply_ext;
    input [DW-1:0] dma_dout;
    input [   1:0] pre_scan;

    if( LAYOUT == 9 ) begin
        case( pre_scan )
            //2'd0: apply_ext = dma_dout + extend[1];
            2'd1: apply_ext = { extend[1], dma_dout[DW-2:0] }; // mark MSB
            2'd3: apply_ext = dma_dout + { {DW-5{1'b0}}, extend[1], 4'd0 };
            default: apply_ext = dma_dout;
        endcase
    end else begin
        apply_ext = dma_dout;
    end
endfunction

wire [DW-1:0] dma_ext = apply_ext( dma_dout, pre_scan[1:0] );

always @(*) begin
    rd_addr = { line, hscan};
    wr_addr = {~line, ~post_scan[4:0], pre_scan[1:0]};
    wr_data = fill ? CLRVAL : dma_ext;
    wr_en   = line_obj_we & draw_cen;
end

jtframe_dual_ram #(.DW(DW),.AW(8)) u_objbuf(
    .clk0   ( clk       ),
    .clk1   ( clk       ),
    // Port 0: writes
    .data0  ( wr_data   ),
    .addr0  ( wr_addr   ),
    .we0    ( wr_en     ),
    .q0     (           ),
    // Port 1: reads and clears
    .data1  ( CLRVAL    ),
    .addr1  ( rd_addr   ),
    .we1    ( we_clr[2] ),
    .q1     ( pre_q     )
);

endmodule // jtgng_objbuf