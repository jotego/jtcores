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

// 9 slots for SDRAM read-only access
// slot 0 --> maximum priority
// slot 8 --> minimum priority
// Each slot can be used for 8, 16 or 32 bit access
// Small 4 byte cache used for each slot

/* verilator tracing_off */

module jtframe_rom #(parameter
    SLOT0_DW = 8, SLOT1_DW = 8, SLOT2_DW = 8, SLOT3_DW = 8,
    SLOT4_DW = 8, SLOT5_DW = 8, SLOT6_DW = 8, SLOT7_DW = 8, SLOT8_DW = 8,

    SLOT0_AW = 8, SLOT1_AW = 8, SLOT2_AW = 8, SLOT3_AW = 8,
    SLOT4_AW = 8, SLOT5_AW = 8, SLOT6_AW = 8, SLOT7_AW = 8, SLOT8_AW = 8,

    parameter [21:0] SLOT0_OFFSET = 22'h0,
    parameter [21:0] SLOT1_OFFSET = 22'h0,
    parameter [21:0] SLOT2_OFFSET = 22'h0,
    parameter [21:0] SLOT3_OFFSET = 22'h0,
    parameter [21:0] SLOT4_OFFSET = 22'h0,
    parameter [21:0] SLOT5_OFFSET = 22'h0,
    parameter [21:0] SLOT6_OFFSET = 22'h0,
    parameter [21:0] SLOT7_OFFSET = 22'h0,
    parameter [21:0] SLOT8_OFFSET = 22'h0

    // SLOT0_BRAM   = 0,
    // SLOT1_BRAM   = 0
)(
    input               rst,
    input               clk,

    input  [SLOT0_AW-1:0] slot0_addr, //  32 kB
    input  [SLOT1_AW-1:0] slot1_addr, // 160 kB, addressed as 8-bit words
    input  [SLOT2_AW-1:0] slot2_addr, //  32 kB
    input  [SLOT3_AW-1:0] slot3_addr, //  64 kB
    input  [SLOT4_AW-1:0] slot4_addr, // 256 kB
    input  [SLOT5_AW-1:0] slot5_addr, // 256 kB (16-bit words)
    input  [SLOT6_AW-1:0] slot6_addr, //  64 kB
    input  [SLOT7_AW-1:0] slot7_addr, //  32 kB
    input  [SLOT8_AW-1:0] slot8_addr, //  32 kB

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

    input               slot0_cs,
    input               slot1_cs,
    input               slot2_cs,
    input               slot3_cs,
    input               slot4_cs,
    input               slot5_cs,
    input               slot6_cs,
    input               slot7_cs,
    input               slot8_cs,

    output              slot0_ok,
    output              slot1_ok,
    output              slot2_ok,
    output              slot3_ok,
    output              slot4_ok,
    output              slot5_ok,
    output              slot6_ok,
    output              slot7_ok,
    output              slot8_ok,
    // SDRAM controller interface
    input               sdram_ack,
    output  reg         sdram_rd,
    output  reg [21:0]  sdram_addr,
    input               data_dst,
    input               data_rdy,
    input       [15:0]  data_read
);


reg  [ 3:0] rd_state_last;
wire [ 8:0] req, ok;

reg  [ 8:0] data_sel;
wire [21:0] slot0_addr_req,
            slot1_addr_req,
            slot2_addr_req,
            slot3_addr_req,
            slot4_addr_req,
            slot5_addr_req,
            slot6_addr_req,
            slot7_addr_req,
            slot8_addr_req;

assign slot0_ok = ok[0];
assign slot1_ok = ok[1];
assign slot2_ok = ok[2];
assign slot3_ok = ok[3];
assign slot4_ok = ok[4];
assign slot5_ok = ok[5];
assign slot6_ok = ok[6];
assign slot7_ok = ok[7];
assign slot8_ok = ok[8];

wire [21:0] offset0 = SLOT0_OFFSET,
            offset1 = SLOT1_OFFSET,
            offset2 = SLOT2_OFFSET,
            offset3 = SLOT3_OFFSET,
            offset4 = SLOT4_OFFSET,
            offset5 = SLOT5_OFFSET,
            offset6 = SLOT6_OFFSET,
            offset7 = SLOT7_OFFSET,
            offset8 = SLOT8_OFFSET;

jtframe_romrq #(.AW(SLOT0_AW),.DW(SLOT0_DW)) u_slot0(
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .clr       ( 1'b0                   ),
    .offset    ( offset0                ),
    .addr      ( slot0_addr             ),
    .addr_ok   ( slot0_cs               ),
    .sdram_addr( slot0_addr_req         ),
    .din       ( data_read              ),
    .din_ok    ( data_rdy               ),
    .dst       ( data_dst               ),
    .dout      ( slot0_dout             ),
    .req       ( req[0]                 ),
    .data_ok   ( ok[0]                  ),
    .we        ( data_sel[0]            )
);

jtframe_romrq #(.AW(SLOT1_AW),.DW(SLOT1_DW)) u_slot1(
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .clr       ( 1'b0                   ),
    .offset    ( offset1                ),
    .addr      ( slot1_addr             ),
    .addr_ok   ( slot1_cs               ),
    .sdram_addr( slot1_addr_req         ),
    .din       ( data_read              ),
    .din_ok    ( data_rdy               ),
    .dst       ( data_dst               ),
    .dout      ( slot1_dout             ),
    .req       ( req[1]                 ),
    .data_ok   ( ok[1]                  ),
    .we        ( data_sel[1]            )
);

jtframe_romrq #(.AW(SLOT2_AW),.DW(SLOT2_DW)) u_slot2(
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .clr       ( 1'b0                   ),
    .offset    ( offset2                ),
    .addr      ( slot2_addr             ),
    .addr_ok   ( slot2_cs               ),
    .sdram_addr( slot2_addr_req         ),
    .din       ( data_read              ),
    .din_ok    ( data_rdy               ),
    .dst       ( data_dst               ),
    .dout      ( slot2_dout             ),
    .req       ( req[2]                 ),
    .data_ok   ( ok[2]                  ),
    .we        ( data_sel[2]            )
);

jtframe_romrq #(.AW(SLOT3_AW),.DW(SLOT3_DW)) u_slot3(
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .clr       ( 1'b0                   ),
    .offset    ( offset3                ),
    .addr      ( slot3_addr             ),
    .addr_ok   ( slot3_cs               ),
    .sdram_addr( slot3_addr_req         ),
    .din       ( data_read              ),
    .din_ok    ( data_rdy               ),
    .dst       ( data_dst               ),
    .dout      ( slot3_dout             ),
    .req       ( req[3]                 ),
    .data_ok   ( ok[3]                  ),
    .we        ( data_sel[3]            )
);

jtframe_romrq #(.AW(SLOT4_AW),.DW(SLOT4_DW)) u_slot4(
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .clr       ( 1'b0                   ),
    .offset    ( offset4                ),
    .addr      ( slot4_addr             ),
    .addr_ok   ( slot4_cs               ),
    .sdram_addr( slot4_addr_req         ),
    .din       ( data_read              ),
    .din_ok    ( data_rdy               ),
    .dst       ( data_dst               ),
    .dout      ( slot4_dout             ),
    .req       ( req[4]                 ),
    .data_ok   ( ok[4]                  ),
    .we        ( data_sel[4]            )
);

jtframe_romrq #(.AW(SLOT5_AW),.DW(SLOT5_DW)) u_slot5(
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .clr       ( 1'b0                   ),
    .offset    ( offset5                ),
    .addr      ( slot5_addr             ),
    .addr_ok   ( slot5_cs               ),
    .sdram_addr( slot5_addr_req         ),
    .din       ( data_read              ),
    .din_ok    ( data_rdy               ),
    .dst       ( data_dst               ),
    .dout      ( slot5_dout             ),
    .req       ( req[5]                 ),
    .data_ok   ( ok[5]                  ),
    .we        ( data_sel[5]            )
);

jtframe_romrq #(.AW(SLOT6_AW),.DW(SLOT6_DW)) u_slot6(
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .clr       ( 1'b0                   ),
    .offset    ( offset6                ),
    .addr      ( slot6_addr             ),
    .addr_ok   ( slot6_cs               ),
    .sdram_addr( slot6_addr_req         ),
    .din       ( data_read              ),
    .din_ok    ( data_rdy               ),
    .dst       ( data_dst               ),
    .dout      ( slot6_dout             ),
    .req       ( req[6]                 ),
    .data_ok   ( ok[6]                  ),
    .we        ( data_sel[6]            )
);

jtframe_romrq #(.AW(SLOT7_AW),.DW(SLOT7_DW)) u_slot7(
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .clr       ( 1'b0                   ),
    .offset    ( offset7                ),
    .addr      ( slot7_addr             ),
    .addr_ok   ( slot7_cs               ),
    .sdram_addr( slot7_addr_req         ),
    .din       ( data_read              ),
    .din_ok    ( data_rdy               ),
    .dst       ( data_dst               ),
    .dout      ( slot7_dout             ),
    .req       ( req[7]                 ),
    .data_ok   ( ok[7]                  ),
    .we        ( data_sel[7]            )
);


jtframe_romrq #(.AW(SLOT8_AW),.DW(SLOT8_DW)) u_slot8(
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .clr       ( 1'b0                   ),
    .offset    ( offset8                ),
    .addr      ( slot8_addr             ),
    .addr_ok   ( slot8_cs               ),
    .sdram_addr( slot8_addr_req         ),
    .din       ( data_read              ),
    .din_ok    ( data_rdy               ),
    .dst       ( data_dst               ),
    .dout      ( slot8_dout             ),
    .req       ( req[8]                 ),
    .data_ok   ( ok[8]                  ),
    .we        ( data_sel[8]            )
);

wire [8:0] active = ~data_sel & req;

always @(posedge clk, posedge rst)
if( rst ) begin
    sdram_addr <= 22'd0;
    sdram_rd  <=  1'b0;
    data_sel   <=  9'd0;
end else begin
    if( sdram_ack ) sdram_rd <= 1'b0;
    // accept a new request
    if( data_sel==9'd0 || data_rdy ) begin
        sdram_rd <= |active;
        data_sel  <= 9'd0;
        case( 1'b1 )
            active[0]: begin
                sdram_addr <= slot0_addr_req;
                data_sel[0] <= 1'b1;
            end
            active[1]: begin
                sdram_addr <= slot1_addr_req;
                data_sel[1] <= 1'b1;
            end
            active[2]: begin
                sdram_addr <= slot2_addr_req;
                data_sel[2] <= 1'b1;
            end
            active[3]: begin
                sdram_addr <= slot3_addr_req;
                data_sel[3] <= 1'b1;
            end
            active[4]: begin
                sdram_addr <= slot4_addr_req;
                data_sel[4] <= 1'b1;
            end
            active[5]: begin
                sdram_addr <= slot5_addr_req;
                data_sel[5] <= 1'b1;
            end
            active[6]: begin
                sdram_addr <= slot6_addr_req;
                data_sel[6] <= 1'b1;
            end
            active[7]: begin
                sdram_addr <= slot7_addr_req;
                data_sel[7] <= 1'b1;
            end
            active[8]: begin
                sdram_addr <= slot8_addr_req;
                data_sel[8] <= 1'b1;
            end
            default: ;
        endcase
    end
end

/* verilator tracing_on */

endmodule // jtframe_rom