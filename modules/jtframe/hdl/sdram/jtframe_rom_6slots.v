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
    Date: 2-11-2022 */

// 6 slots for SDRAM read-only access
// slot 0 --> maximum priority
// slot 5 --> minimum priority
// Each slot can be used for 8, 16 or 32 bit access
// Small 4 byte cache used for each slot

module jtframe_rom_6slots #(parameter
    SDRAMW = 22,
    SLOT0_DW = 8, SLOT1_DW = 8, SLOT2_DW = 8,
    SLOT3_DW = 8, SLOT4_DW = 8, SLOT5_DW = 8,
    SLOT0_AW = 8, SLOT1_AW = 8, SLOT2_AW = 8,
    SLOT3_AW = 8, SLOT4_AW = 8, SLOT5_AW = 8,

    SLOT0_LATCH  = 0,
    SLOT1_LATCH  = 0,
    SLOT2_LATCH  = 0,
    SLOT3_LATCH  = 0,
    SLOT4_LATCH  = 0,
    SLOT5_LATCH  = 0,

    SLOT0_DOUBLE = 0,
    SLOT1_DOUBLE = 0,
    SLOT2_DOUBLE = 0,
    SLOT3_DOUBLE = 0,
    SLOT4_DOUBLE = 0,
    SLOT5_DOUBLE = 0,

    SLOT0_OKLATCH= 1,
    SLOT1_OKLATCH= 1,
    SLOT2_OKLATCH= 1,
    SLOT3_OKLATCH= 1,
    SLOT4_OKLATCH= 1,
    SLOT5_OKLATCH= 1,

    CACHE0_SIZE = 0,
    CACHE1_SIZE = 0,
    CACHE2_SIZE = 0,
    CACHE3_SIZE = 0,
    CACHE4_SIZE = 0,
    CACHE5_SIZE = 0,
/* verilator lint_off WIDTH */
    parameter [SDRAMW-1:0] SLOT0_OFFSET = 0,
    parameter [SDRAMW-1:0] SLOT1_OFFSET = 0,
    parameter [SDRAMW-1:0] SLOT2_OFFSET = 0,
    parameter [SDRAMW-1:0] SLOT3_OFFSET = 0,
    parameter [SDRAMW-1:0] SLOT4_OFFSET = 0,
    parameter [SDRAMW-1:0] SLOT5_OFFSET = 0,
/* verilator lint_on WIDTH */
    parameter REF_FILE="sdram_bank4.hex"
)(
    input               rst,
    input               clk,

    input  [SLOT0_AW-1:0] slot0_addr,
    input  [SLOT1_AW-1:0] slot1_addr,
    input  [SLOT2_AW-1:0] slot2_addr,
    input  [SLOT3_AW-1:0] slot3_addr,
    input  [SLOT4_AW-1:0] slot4_addr,
    input  [SLOT5_AW-1:0] slot5_addr,

    //  output data
    output [SLOT0_DW-1:0] slot0_dout,
    output [SLOT1_DW-1:0] slot1_dout,
    output [SLOT2_DW-1:0] slot2_dout,
    output [SLOT3_DW-1:0] slot3_dout,
    output [SLOT4_DW-1:0] slot4_dout,
    output [SLOT5_DW-1:0] slot5_dout,

    input               slot0_cs,
    input               slot1_cs,
    input               slot2_cs,
    input               slot3_cs,
    input               slot4_cs,
    input               slot5_cs,

    output              slot0_ok,
    output              slot1_ok,
    output              slot2_ok,
    output              slot3_ok,
    output              slot4_ok,
    output              slot5_ok,

    // SDRAM controller interface
    input               sdram_ack,
    output              sdram_rd,
    output [SDRAMW-1:0] sdram_addr,
    input               data_dst,
    input               data_rdy,
    input       [15:0]  data_read
);

localparam SW=6;

wire [SW-1:0] req, ok;
wire [SW-1:0] slot_sel;
wire [SDRAMW-1:0] slot0_addr_req, slot1_addr_req, slot2_addr_req,
                  slot3_addr_req, slot4_addr_req, slot5_addr_req;

assign slot0_ok = ok[0];
assign slot1_ok = ok[1];
assign slot2_ok = ok[2];
assign slot3_ok = ok[3];
assign slot4_ok = ok[4];
assign slot5_ok = ok[5];

wire [SDRAMW-1:0] offset0 = SLOT0_OFFSET,
                  offset1 = SLOT1_OFFSET,
                  offset2 = SLOT2_OFFSET,
                  offset3 = SLOT3_OFFSET,
                  offset4 = SLOT4_OFFSET,
                  offset5 = SLOT5_OFFSET;

jtframe_romrq #(.SDRAMW(SDRAMW),.AW(SLOT0_AW),.DW(SLOT0_DW),
    .LATCH(SLOT0_LATCH),.DOUBLE(SLOT0_DOUBLE),.OKLATCH(SLOT0_OKLATCH),
    .CACHE_SIZE(CACHE0_SIZE))
u_slot0(
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .clr       ( 1'd0                   ),
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
    .we        ( slot_sel[0]            )
);

jtframe_romrq #(.SDRAMW(SDRAMW),.AW(SLOT1_AW),.DW(SLOT1_DW),
    .LATCH(SLOT1_LATCH),.DOUBLE(SLOT1_DOUBLE),.OKLATCH(SLOT1_OKLATCH),
    .CACHE_SIZE(CACHE1_SIZE))
u_slot1(
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .clr       ( 1'd0                   ),
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
    .we        ( slot_sel[1]            )
);

jtframe_romrq #(.SDRAMW(SDRAMW),.AW(SLOT2_AW),.DW(SLOT2_DW),
    .LATCH(SLOT2_LATCH),.DOUBLE(SLOT2_DOUBLE),.OKLATCH(SLOT2_OKLATCH),
    .CACHE_SIZE(CACHE2_SIZE))
u_slot2(
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .clr       ( 1'd0                   ),
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
    .we        ( slot_sel[2]            )
);

jtframe_romrq #(.SDRAMW(SDRAMW),.AW(SLOT3_AW),.DW(SLOT3_DW),
    .LATCH(SLOT3_LATCH),.DOUBLE(SLOT3_DOUBLE),.OKLATCH(SLOT3_OKLATCH),
    .CACHE_SIZE(CACHE3_SIZE))
u_slot3(
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .clr       ( 1'd0                   ),
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
    .we        ( slot_sel[3]            )
);

jtframe_romrq #(.SDRAMW(SDRAMW),.AW(SLOT4_AW),.DW(SLOT4_DW),
    .LATCH(SLOT4_LATCH),.DOUBLE(SLOT4_DOUBLE),.OKLATCH(SLOT4_OKLATCH),
    .CACHE_SIZE(CACHE4_SIZE))
u_slot4(
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .clr       ( 1'd0                   ),
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
    .we        ( slot_sel[4]            )
);

jtframe_romrq #(.SDRAMW(SDRAMW),.AW(SLOT5_AW),.DW(SLOT5_DW),
    .LATCH(SLOT5_LATCH),.DOUBLE(SLOT5_DOUBLE),.OKLATCH(SLOT5_OKLATCH),
    .CACHE_SIZE(CACHE5_SIZE))
u_slot5(
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .clr       ( 1'd0                   ),
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
    .we        ( slot_sel[5]            )
);

jtframe_ramslot_ctrl #(
    .SDRAMW         ( SDRAMW        ),
    .SW             (     SW        ),
    .WRSW           (      0        )
)u_ctrl(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .req            ( req           ),
    .slot_addr_req  ({  slot5_addr_req, slot4_addr_req,
                        slot3_addr_req, slot2_addr_req,
                        slot1_addr_req, slot0_addr_req }),
    .slot_sel       ( slot_sel      ),
    // SDRAM controller interface
    .sdram_ack      ( sdram_ack     ),
    .sdram_rd       ( sdram_rd      ),
    .sdram_addr     ( sdram_addr    ),
    .data_rdy       ( data_rdy      ),

    // RAM section ignored
    .erase_bsy      (  1'b0         ),
    .req_rnw        (  1'b1         ),
    .slot_din       ( 16'd0         ),
    .wrmask         (  2'd0         ),
    .sdram_wr       (               ),
    .data_write     (               ),
    .sdram_wrmask   (               )
);

`ifdef JTFRAME_SDRAM_CHECK

reg [15:0] mem[0:4*1024*1024];

initial begin
    $readmemh( REF_FILE, mem );
end

always @( posedge clk ) begin
    if( data_rdy ) begin
        if( !slot_sel ) begin
            $display("ERROR: SDRAM data received but it had not been requested at time %t - %m\n", $time);
            $finish;
        end else if( { mem[sdram_addr+1], mem[sdram_addr] } !== data_read ) begin
            $display("ERROR: Wrong data read at time %t - %m", $time);
            $display("       at address %X", sdram_addr );
            $display("       expecting %X_%X - Read %X_%X\n",
                    mem[sdram_addr+1], mem[sdram_addr], data_read[31:16], data_read[15:0]);
            $finish;
        end
    end
end

`endif

endmodule