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
    Date: 6-12-2019 */

// 10 slots for SDRAM access
// slot 0 --> maximum priority
// slot 9 --> minimum priority
// Each slot can be used for 8, 16 or 32 bit access
// Small 4 byte cache used for each slot. Cache can be turned off at synthesis time
// Three types of slots:
// 0 = read only    ( default )
// 1 = write only
// 2 = R/W

module jtframe_sdram_mux #(parameter
    SLOT0_DW = 8, SLOT1_DW = 8, SLOT2_DW = 8, SLOT3_DW = 8, SLOT4_DW = 8,
    SLOT5_DW = 8, SLOT6_DW = 8, SLOT7_DW = 8, SLOT8_DW = 8, SLOT9_DW = 8,

    SLOT0_AW = 8, SLOT1_AW = 8, SLOT2_AW = 8, SLOT3_AW = 8, SLOT4_AW = 8,
    SLOT5_AW = 8, SLOT6_AW = 8, SLOT7_AW = 8, SLOT8_AW = 8, SLOT9_AW = 8,

    SLOT0_TYPE = 0, SLOT1_TYPE = 0, SLOT2_TYPE = 0, SLOT3_TYPE = 0, SLOT4_TYPE = 0,
    SLOT5_TYPE = 0, SLOT6_TYPE = 0, SLOT7_TYPE = 0, SLOT8_TYPE = 0, SLOT9_TYPE = 0
)(
    input               rst,
    input               clk,
    input               vblank,

    input  [SLOT0_AW-1:0] slot0_addr,
    input  [SLOT1_AW-1:0] slot1_addr,
    input  [SLOT2_AW-1:0] slot2_addr,
    input  [SLOT3_AW-1:0] slot3_addr,
    input  [SLOT4_AW-1:0] slot4_addr,
    input  [SLOT5_AW-1:0] slot5_addr,
    input  [SLOT6_AW-1:0] slot6_addr,
    input  [SLOT7_AW-1:0] slot7_addr,
    input  [SLOT8_AW-1:0] slot8_addr,
    input  [SLOT9_AW-1:0] slot9_addr,

    input  [        21:0] slot0_offset,
    input  [        21:0] slot1_offset,
    input  [        21:0] slot2_offset,
    input  [        21:0] slot3_offset,
    input  [        21:0] slot4_offset,
    input  [        21:0] slot5_offset,
    input  [        21:0] slot6_offset,
    input  [        21:0] slot7_offset,
    input  [        21:0] slot8_offset,
    input  [        21:0] slot9_offset,

    //  output data
    output [SLOT0_DW-1:0] slot0_dout,
    output [SLOT1_DW-1:0] slot1_dout,
    output [SLOT2_DW-1:0] slot2_dout,
    output [SLOT3_DW-1:0] slot3_dout,
    output [SLOT4_DW-1:0] slot4_dout,
    output [SLOT5_DW-1:0] slot5_dout,
    output [SLOT6_DW-1:0] slot6_dout,
    output [SLOT7_DW-1:0] slot7_dout,
    output [SLOT8_DW-1:0] slot8_dout,
    output [SLOT9_DW-1:0] slot9_dout,

    //  input data
    input  [SLOT0_DW-1:0] slot0_din,
    input  [SLOT1_DW-1:0] slot1_din,
    input  [SLOT2_DW-1:0] slot2_din,
    input  [SLOT3_DW-1:0] slot3_din,
    input  [SLOT4_DW-1:0] slot4_din,
    input  [SLOT5_DW-1:0] slot5_din,
    input  [SLOT6_DW-1:0] slot6_din,
    input  [SLOT7_DW-1:0] slot7_din,
    input  [SLOT8_DW-1:0] slot8_din,
    input  [SLOT9_DW-1:0] slot9_din,
    output  reg         ready=1'b0,

    input  [9:0]        slot_cs,
    input  [9:0]        slot_wr,
    output [9:0]        slot_ok,
    input  [9:0]        slot_clr,

    // Slot 1 accepts 16-bit writes
    input  [1:0]        slot1_wrmask,

    output [9:0]        slot_active,   // currently active slot

    // SDRAM controller interface
    input               downloading,
    input               loop_rst,
    input               sdram_ack,
    output  reg         sdram_rd,
    output  reg         sdram_rnw,
    output  reg         refresh_en,
    output  reg [21:0]  sdram_addr,
    input               data_rdy,
    input       [31:0]  data_read,
    output  reg [15:0]  data_write,  // only 16-bit writes
    output  reg [ 1:0]  sdram_wrmask // each bit is active low
);

reg  [ 3:0] ready_cnt;
reg  [ 3:0] rd_state_last;
wire [ 9:0] req, req_rnw;
reg  [ 9:0] data_sel, slot_we;
wire [ 9:0] active = ~data_sel & req;
reg         wait_cycle;

assign      slot_active = data_sel;

wire [21:0] slot0_addr_req,
            slot1_addr_req,
            slot2_addr_req,
            slot3_addr_req,
            slot4_addr_req,
            slot5_addr_req,
            slot6_addr_req,
            slot7_addr_req,
            slot8_addr_req,
            slot9_addr_req;

jtframe_sdram_rq #(.AW(SLOT0_AW),.DW(SLOT0_DW),.TYPE(SLOT0_TYPE)) u_slot0(
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .clr       ( slot_clr[0]            ),
    .addr      ( slot0_addr             ),
    .addr_ok   ( slot_cs[0]             ),
    .offset    ( slot0_offset           ),
    .wrdata    ( slot0_din              ),
    .wrin      ( slot_wr[0]             ),
    .req_rnw   ( req_rnw[0]             ),
    .sdram_addr( slot0_addr_req         ),
    .din       ( data_read              ),
    .din_ok    ( data_rdy               ),
    .dout      ( slot0_dout             ),
    .req       ( req[0]                 ),
    .data_ok   ( slot_ok[0]             ),
    .we        ( slot_we[0]             )
);

jtframe_sdram_rq #(.AW(SLOT1_AW),.DW(SLOT1_DW),.TYPE(SLOT1_TYPE)) u_slot1(
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .clr       ( slot_clr[1]            ),
    .addr      ( slot1_addr             ),
    .addr_ok   ( slot_cs[1]             ),
    .offset    ( slot1_offset           ),
    .wrdata    ( slot1_din              ),
    .wrin      ( slot_wr[1]             ),
    .req_rnw   ( req_rnw[1]             ),
    .sdram_addr( slot1_addr_req         ),
    .din       ( data_read              ),
    .din_ok    ( data_rdy               ),
    .dout      ( slot1_dout             ),
    .req       ( req[1]                 ),
    .data_ok   ( slot_ok[1]             ),
    .we        ( slot_we[1]             )
);

jtframe_sdram_rq #(.AW(SLOT2_AW),.DW(SLOT2_DW),.TYPE(SLOT2_TYPE)) u_slot2(
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .clr       ( slot_clr[2]            ),
    .addr      ( slot2_addr             ),
    .addr_ok   ( slot_cs[2]             ),
    .offset    ( slot2_offset           ),
    .wrdata    ( slot2_din              ),
    .wrin      ( slot_wr[2]             ),
    .req_rnw   ( req_rnw[2]             ),
    .sdram_addr( slot2_addr_req         ),
    .din       ( data_read              ),
    .din_ok    ( data_rdy               ),
    .dout      ( slot2_dout             ),
    .req       ( req[2]                 ),
    .data_ok   ( slot_ok[2]             ),
    .we        ( slot_we[2]             )
);

jtframe_sdram_rq #(.AW(SLOT3_AW),.DW(SLOT3_DW),.TYPE(SLOT3_TYPE)) u_slot3(
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .clr       ( slot_clr[3]            ),
    .addr      ( slot3_addr             ),
    .addr_ok   ( slot_cs[3]             ),
    .offset    ( slot3_offset           ),
    .wrdata    ( slot3_din              ),
    .wrin      ( slot_wr[3]             ),
    .req_rnw   ( req_rnw[3]             ),
    .sdram_addr( slot3_addr_req         ),
    .din       ( data_read              ),
    .din_ok    ( data_rdy               ),
    .dout      ( slot3_dout             ),
    .req       ( req[3]                 ),
    .data_ok   ( slot_ok[3]             ),
    .we        ( slot_we[3]             )
);

jtframe_sdram_rq #(.AW(SLOT4_AW),.DW(SLOT4_DW),.TYPE(SLOT4_TYPE)) u_slot4(
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .clr       ( slot_clr[4]            ),
    .addr      ( slot4_addr             ),
    .addr_ok   ( slot_cs[4]             ),
    .offset    ( slot4_offset           ),
    .wrdata    ( slot4_din              ),
    .wrin      ( slot_wr[4]             ),
    .req_rnw   ( req_rnw[4]             ),
    .sdram_addr( slot4_addr_req         ),
    .din       ( data_read              ),
    .din_ok    ( data_rdy               ),
    .dout      ( slot4_dout             ),
    .req       ( req[4]                 ),
    .data_ok   ( slot_ok[4]             ),
    .we        ( slot_we[4]             )
);

jtframe_sdram_rq #(.AW(SLOT5_AW),.DW(SLOT5_DW),.TYPE(SLOT5_TYPE)) u_slot5(
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .clr       ( slot_clr[5]            ),
    .addr      ( slot5_addr             ),
    .addr_ok   ( slot_cs[5]             ),
    .offset    ( slot5_offset           ),
    .wrdata    ( slot5_din              ),
    .wrin      ( slot_wr[5]             ),
    .req_rnw   ( req_rnw[5]             ),
    .sdram_addr( slot5_addr_req         ),
    .din       ( data_read              ),
    .din_ok    ( data_rdy               ),
    .dout      ( slot5_dout             ),
    .req       ( req[5]                 ),
    .data_ok   ( slot_ok[5]             ),
    .we        ( slot_we[5]             )
);

jtframe_sdram_rq #(.AW(SLOT6_AW),.DW(SLOT6_DW),.TYPE(SLOT6_TYPE)) u_slot6(
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .clr       ( slot_clr[6]            ),
    .addr      ( slot6_addr             ),
    .addr_ok   ( slot_cs[6]             ),
    .offset    ( slot6_offset           ),
    .wrdata    ( slot6_din              ),
    .wrin      ( slot_wr[6]             ),
    .req_rnw   ( req_rnw[6]             ),
    .sdram_addr( slot6_addr_req         ),
    .din       ( data_read              ),
    .din_ok    ( data_rdy               ),
    .dout      ( slot6_dout             ),
    .req       ( req[6]                 ),
    .data_ok   ( slot_ok[6]             ),
    .we        ( slot_we[6]             )
);

jtframe_sdram_rq #(.AW(SLOT7_AW),.DW(SLOT7_DW),.TYPE(SLOT7_TYPE)) u_slot7(
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .clr       ( slot_clr[7]            ),
    .addr      ( slot7_addr             ),
    .addr_ok   ( slot_cs[7]             ),
    .offset    ( slot7_offset           ),
    .wrdata    ( slot7_din              ),
    .wrin      ( slot_wr[7]             ),
    .req_rnw   ( req_rnw[7]             ),
    .sdram_addr( slot7_addr_req         ),
    .din       ( data_read              ),
    .din_ok    ( data_rdy               ),
    .dout      ( slot7_dout             ),
    .req       ( req[7]                 ),
    .data_ok   ( slot_ok[7]             ),
    .we        ( slot_we[7]             )
);

jtframe_sdram_rq #(.AW(SLOT8_AW),.DW(SLOT8_DW),.TYPE(SLOT8_TYPE)) u_slot8(
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .clr       ( slot_clr[8]            ),
    .addr      ( slot8_addr             ),
    .addr_ok   ( slot_cs[8]             ),
    .offset    ( slot8_offset           ),
    .wrdata    ( slot8_din              ),
    .wrin      ( slot_wr[8]             ),
    .req_rnw   ( req_rnw[8]             ),
    .sdram_addr( slot8_addr_req         ),
    .din       ( data_read              ),
    .din_ok    ( data_rdy               ),
    .dout      ( slot8_dout             ),
    .req       ( req[8]                 ),
    .data_ok   ( slot_ok[8]             ),
    .we        ( slot_we[8]             )
);

jtframe_sdram_rq #(.AW(SLOT9_AW),.DW(SLOT9_DW),.TYPE(SLOT9_TYPE)) u_slot9(
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .clr       ( slot_clr[9]            ),
    .addr      ( slot9_addr             ),
    .addr_ok   ( slot_cs[9]             ),
    .offset    ( slot9_offset           ),
    .wrdata    ( slot9_din              ),
    .wrin      ( slot_wr[9]             ),
    .req_rnw   ( req_rnw[9]             ),
    .sdram_addr( slot9_addr_req         ),
    .din       ( data_read              ),
    .din_ok    ( data_rdy               ),
    .dout      ( slot9_dout             ),
    .req       ( req[9]                 ),
    .data_ok   ( slot_ok[9]             ),
    .we        ( slot_we[9]             )
);

always @(posedge clk)
if( rst || loop_rst || downloading ) begin
    sdram_addr <= 22'd0;
    ready_cnt  <=  4'd0;
    ready      <=  1'b0;
    sdram_rd  <=  1'b0;
    data_sel   <= 10'd0;
    refresh_en <=  1'b1;
    slot_we    <= 10'd0;
end else begin
    {ready, ready_cnt}  <= {ready_cnt, 1'b1};
    if( sdram_ack ) begin
        sdram_rd <= 1'b0;
        wait_cycle <= 1'b0;
    end

    refresh_en <= 1'b0;
    // accept a new request
    slot_we <= data_sel;
    if( data_sel==10'd0 || (data_rdy&&!wait_cycle) ) begin
        sdram_rd <= |active;
        wait_cycle<= |active;
        data_sel  <= 10'd0;
        sdram_wrmask <= 2'b11;
        sdram_rnw    <= 1'b1;
        case( 1'b1 )
            active[0]: begin
                sdram_addr <= slot0_addr_req;
                if( SLOT0_TYPE != 0) begin
                    data_write <= slot0_din;
                    sdram_rnw  <= req_rnw[0];
                end
                data_sel[0] <= 1'b1;
            end
            active[1]: begin
                sdram_addr <= slot1_addr_req;
                if( SLOT1_TYPE != 0) begin
                    data_write   <= slot1_din;
                    sdram_rnw    <= req_rnw[1];
                    sdram_wrmask <= slot1_wrmask;
                end
                data_sel[1] <= 1'b1;
            end
            active[2]: begin
                sdram_addr <= slot2_addr_req;
                if( SLOT2_TYPE != 0) begin
                    data_write <= slot2_din;
                    sdram_rnw  <= req_rnw[2];
                end
                data_sel[2] <= 1'b1;
            end
            active[3]: begin
                sdram_addr <= slot3_addr_req;
                if( SLOT3_TYPE != 0) begin
                    data_write <= slot3_din;
                    sdram_rnw  <= req_rnw[3];
                end
                data_sel[3] <= 1'b1;
            end
            active[4]: begin
                sdram_addr <= slot4_addr_req;
                if( SLOT4_TYPE != 0) begin
                    data_write <= slot4_din;
                    sdram_rnw  <= req_rnw[4];
                end
                data_sel[4] <= 1'b1;
            end
            active[5]: begin
                sdram_addr <= slot5_addr_req;
                if( SLOT5_TYPE != 0) begin
                    data_write <= slot5_din;
                    sdram_rnw  <= req_rnw[5];
                end
                data_sel[5] <= 1'b1;
            end
            active[6]: begin
                sdram_addr <= slot6_addr_req;
                if( SLOT6_TYPE != 0) begin
                    data_write <= slot6_din;
                    sdram_rnw  <= req_rnw[6];
                end
                data_sel[6] <= 1'b1;
            end
            active[7]: begin
                sdram_addr <= slot7_addr_req;
                if( SLOT7_TYPE != 0) begin
                    data_write <= slot7_din;
                    sdram_rnw  <= req_rnw[7];
                end
                data_sel[7] <= 1'b1;
            end
            active[8]: begin
                sdram_addr <= slot8_addr_req;
                if( SLOT8_TYPE != 0) begin
                    data_write <= slot8_din;
                    sdram_rnw  <= req_rnw[8];
                end
                data_sel[8] <= 1'b1;
            end
            active[9]: begin
                sdram_addr <= slot9_addr_req;
                if( SLOT0_TYPE != 9) begin
                    data_write <= slot9_din;
                    sdram_rnw  <= req_rnw[9];
                end
                data_sel[9] <= 1'b1;
            end
            default: refresh_en <= vblank;
        endcase
    end
end

endmodule
