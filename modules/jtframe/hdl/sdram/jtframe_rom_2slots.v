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

// 2 slots for SDRAM read-only access
// slot 0 --> maximum priority
// slot 1 --> minimum priority
// Each slot can be used for 8, 16 or 32 bit access
// Small 4 byte cache used for each slot

module jtframe_rom_2slots #(parameter
    SDRAMW   = 22,
    SLOT0_DW = 8, SLOT1_DW = 8,
    SLOT0_AW = 8, SLOT1_AW = 8,

    SLOT0_LATCH  = 0,
    SLOT1_LATCH  = 0,

    SLOT0_DOUBLE = 0,
    SLOT1_DOUBLE = 0,

    SLOT0_OKLATCH= 1,
    SLOT1_OKLATCH= 1,
/* verilator lint_off WIDTH */
    parameter [SDRAMW-1:0] SLOT0_OFFSET = {SDRAMW{1'b0}},
    parameter [SDRAMW-1:0] SLOT1_OFFSET = {SDRAMW{1'b0}},
/* verilator lint_on WIDTH */
    parameter REF_FILE="sdram_bank3.hex"
)(
    input               rst,
    input               clk,

    input  [SLOT0_AW-1:0] slot0_addr,
    input  [SLOT1_AW-1:0] slot1_addr,

    //  output data
    output [SLOT0_DW-1:0] slot0_dout,
    output [SLOT1_DW-1:0] slot1_dout,

    input               slot0_cs,
    input               slot1_cs,

    output              slot0_ok,
    output              slot1_ok,
    // SDRAM controller interface
    input               sdram_ack,
    output  reg         sdram_rd,
    output  reg [SDRAMW-1:0]  sdram_addr,
    input               data_dst,
    input               data_rdy,
    input       [15:0]  data_read
);


reg  [ 3:0] ready_cnt;
reg  [ 3:0] rd_state_last;
wire [ 1:0] req, ok;

reg  [ 1:0] slot_sel;
wire [SDRAMW-1:0] slot0_addr_req,
                  slot1_addr_req;

assign slot0_ok = ok[0];
assign slot1_ok = ok[1];

wire [SDRAMW-1:0] offset0 = SLOT0_OFFSET,
                  offset1 = SLOT1_OFFSET;

jtframe_romrq #(.SDRAMW(SDRAMW),.AW(SLOT0_AW),.DW(SLOT0_DW),
    .LATCH(SLOT0_LATCH),.DOUBLE(SLOT0_DOUBLE),.OKLATCH(SLOT0_OKLATCH))
u_slot0(
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
    .we        ( slot_sel[0]            )
);

jtframe_romrq #(.SDRAMW(SDRAMW),.AW(SLOT1_AW),.DW(SLOT1_DW),
    .LATCH(SLOT1_LATCH),.DOUBLE(SLOT1_DOUBLE),.OKLATCH(SLOT1_OKLATCH))
u_slot1(
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
    .we        ( slot_sel[1]            )
);

wire [1:0] active = ~slot_sel & req;

always @(posedge clk, posedge rst)
if( rst ) begin
    sdram_addr <= 0;
    sdram_rd  <= 0;
    slot_sel   <= 0;
end else begin
    if( sdram_ack ) sdram_rd <= 0;
    // accept a new request
    if( slot_sel==0 || data_rdy ) begin
        sdram_rd <= |active;
        slot_sel  <= 2'd0;
        if( active[0] ) begin
            sdram_addr <= slot0_addr_req;
            slot_sel[0] <= 1;
        end else if( active[1] ) begin
            sdram_addr <= slot1_addr_req;
            slot_sel[1] <= 1;
        end
    end
end

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