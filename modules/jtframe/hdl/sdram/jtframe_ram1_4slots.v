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
    Date: 1-12-2020 */

module jtframe_ram1_4slots #(parameter
    SDRAMW = 22,
    SLOT0_DW = 8, SLOT1_DW = 8, SLOT2_DW = 8, SLOT3_DW = 8,
    SLOT0_AW = 8, SLOT1_AW = 8, SLOT2_AW = 8, SLOT3_AW = 8,

    SLOT1_LATCH  = 0,
    SLOT2_LATCH  = 0,
    SLOT3_LATCH  = 0,

    SLOT1_DOUBLE = 0,
    SLOT2_DOUBLE = 0,
    SLOT3_DOUBLE = 0,

    SLOT1_OKLATCH= 1,
    SLOT2_OKLATCH= 1,
    SLOT3_OKLATCH= 1,

/* verilator lint_off WIDTH */
    parameter [SDRAMW-1:0] SLOT1_OFFSET = {SDRAMW{1'b0}},
    parameter [SDRAMW-1:0] SLOT2_OFFSET = {SDRAMW{1'b0}},
    parameter [SDRAMW-1:0] SLOT3_OFFSET = {SDRAMW{1'b0}},
/* verilator lint_on WIDTH */

    parameter REF_FILE="sdram_bank3.hex"
)(
    input               rst,
    input               clk,

    input  [SLOT0_AW-1:0] slot0_addr,
    input  [SLOT1_AW-1:0] slot1_addr,
    input  [SLOT2_AW-1:0] slot2_addr,
    input  [SLOT3_AW-1:0] slot3_addr,

    //  output data
    output [SLOT0_DW-1:0] slot0_dout,
    output [SLOT1_DW-1:0] slot1_dout,
    output [SLOT2_DW-1:0] slot2_dout,
    output [SLOT3_DW-1:0] slot3_dout,

    input    [SDRAMW-1:0] slot0_offset,

    input               slot0_cs,
    input               slot1_cs,
    input               slot2_cs,
    input               slot3_cs,

    output              slot0_ok,
    output              slot1_ok,
    output              slot2_ok,
    output              slot3_ok,

    // Slot 0 accepts 16-bit writes
    input               slot0_wen,
    input  [SLOT0_DW-1:0] slot0_din,
    input  [1:0]        slot0_wrmask,

    // Slot 1-3 cache can be cleared
    input               slot1_clr,
    input               slot2_clr,
    input               slot3_clr,

    // SDRAM controller interface
    input               sdram_ack,
    output  reg         sdram_rd,
    output  reg         sdram_wr,
    output  reg [SDRAMW-1:0] sdram_addr,
    input               data_rdy,
    input               data_dst,
    input       [15:0]  data_read,
    output  reg [15:0]  data_write,  // only 16-bit writes
    output  reg [ 1:0]  sdram_wrmask // each bit is active low
);

localparam SW=4;

wire [SW-1:0] req, slot_ok;
reg  [SW-1:0] slot_sel;
wire          req_rnw; // slot 0
wire [SW-1:0] active = ~slot_sel & req;

wire [SDRAMW-1:0] slot0_addr_req,
                  slot1_addr_req,
                  slot2_addr_req,
                  slot3_addr_req;

assign slot0_ok = slot_ok[0];
assign slot1_ok = slot_ok[1];
assign slot2_ok = slot_ok[2];
assign slot3_ok = slot_ok[3];

jtframe_ram_rq #(.SDRAMW(SDRAMW),.AW(SLOT0_AW),.DW(SLOT0_DW)) u_slot0(
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .addr      ( slot0_addr             ),
    .addr_ok   ( slot0_cs               ),
    .offset    ( slot0_offset           ),
    .wrdata    ( slot0_din              ),
    .wrin      ( slot0_wen              ),
    .req_rnw   ( req_rnw                ),
    .sdram_addr( slot0_addr_req         ),
    .din       ( data_read              ),
    .din_ok    ( data_rdy               ),
    .dst       ( data_dst               ),
    .dout      ( slot0_dout             ),
    .req       ( req[0]                 ),
    .data_ok   ( slot_ok[0]             ),
    .we        ( slot_sel[0]            )
);

jtframe_romrq #(.SDRAMW(SDRAMW),.AW(SLOT1_AW),.DW(SLOT1_DW),
    .LATCH(SLOT1_LATCH),.DOUBLE(SLOT1_DOUBLE),.OKLATCH(SLOT1_OKLATCH))
u_slot1(
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .clr       ( slot1_clr              ),
    .offset    ( SLOT1_OFFSET           ),
    .addr      ( slot1_addr             ),
    .addr_ok   ( slot1_cs               ),
    .sdram_addr( slot1_addr_req         ),
    .din       ( data_read              ),
    .din_ok    ( data_rdy               ),
    .dst       ( data_dst               ),
    .dout      ( slot1_dout             ),
    .req       ( req[1]                 ),
    .data_ok   ( slot_ok[1]             ),
    .we        ( slot_sel[1]            )
);

jtframe_romrq #(.SDRAMW(SDRAMW),.AW(SLOT2_AW),.DW(SLOT2_DW),
    .LATCH(SLOT2_LATCH),.DOUBLE(SLOT2_DOUBLE),.OKLATCH(SLOT2_OKLATCH))
u_slot2(
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .clr       ( slot2_clr              ),
    .offset    ( SLOT2_OFFSET           ),
    .addr      ( slot2_addr             ),
    .addr_ok   ( slot2_cs               ),
    .sdram_addr( slot2_addr_req         ),
    .din       ( data_read              ),
    .din_ok    ( data_rdy               ),
    .dst       ( data_dst               ),
    .dout      ( slot2_dout             ),
    .req       ( req[2]                 ),
    .data_ok   ( slot_ok[2]             ),
    .we        ( slot_sel[2]            )
);

jtframe_romrq #(.SDRAMW(SDRAMW),.AW(SLOT3_AW),.DW(SLOT3_DW),
    .LATCH(SLOT3_LATCH),.DOUBLE(SLOT3_DOUBLE),.OKLATCH(SLOT3_OKLATCH))
u_slot3(
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .clr       ( slot3_clr              ),
    .offset    ( SLOT3_OFFSET           ),
    .addr      ( slot3_addr             ),
    .addr_ok   ( slot3_cs               ),
    .sdram_addr( slot3_addr_req         ),
    .din       ( data_read              ),
    .din_ok    ( data_rdy               ),
    .dst       ( data_dst               ),
    .dout      ( slot3_dout             ),
    .req       ( req[3]                 ),
    .data_ok   ( slot_ok[3]             ),
    .we        ( slot_sel[3]            )
);

always @(posedge clk) begin
    if( rst ) begin
        sdram_addr <= {SDRAMW{1'd0}};
        sdram_rd   <= 0;
        sdram_wr   <= 0;
        slot_sel   <= {SW{1'd0}};
    end else begin
        if( sdram_ack ) begin
            sdram_rd   <= 0;
            sdram_wr   <= 0;
        end

        // accept a new request
        if( slot_sel==0 || data_rdy ) begin
            sdram_rd     <= |active;
            slot_sel     <= {SW{1'd0}};
            sdram_wrmask <= 2'b11;
            if( active[0] ) begin
                sdram_addr  <= slot0_addr_req;
                data_write  <= slot0_din;
                sdram_wrmask<= slot0_wrmask;
                sdram_rd    <= req_rnw;
                sdram_wr    <= ~req_rnw;
                slot_sel[0] <= 1;
            end else if( active[1]) begin
                sdram_addr  <= slot1_addr_req;
                sdram_rd    <= 1;
                sdram_wr    <= 0;
                slot_sel[1] <= 1;
            end else if( active[2]) begin
                sdram_addr  <= slot2_addr_req;
                sdram_rd    <= 1;
                sdram_wr    <= 0;
                slot_sel[2] <= 1;
            end else if( active[3]) begin
                sdram_addr  <= slot3_addr_req;
                sdram_rd    <= 1;
                sdram_wr    <= 0;
                slot_sel[3] <= 1;
            end
        end
    end
end

`ifdef JTFRAME_SDRAM_CHECK

reg [15:0] mem[0:4*1024*1024];

initial begin
    $readmemh( REF_FILE, mem );
end

reg [15:0] expected;
reg [31:0] expected32;
reg        was_a_wr;

always @(*) begin
    expected   = mem[sdram_addr];
    expected32 = { mem[sdram_addr+1], mem[sdram_addr] };
end

always @( posedge clk ) begin
    if( sdram_ack ) begin
        if( sdram_wr ) begin
            mem[ sdram_addr ] <= {
                slot0_wrmask[1] ? expected[15:8] : slot0_din[15:8],
                slot0_wrmask[0] ? expected[ 7:0] : slot0_din[ 7:0] };
        end
        was_a_wr <= sdram_wr;
    end
    if( data_rdy ) begin
        if( !slot_sel ) begin
            $display("ERROR: SDRAM data received but it had not been requested at time %t - %m\n", $time);
            $finish;
        end else if(((slot_sel[0] && (expected   !== data_read[15:0])) ||
                     (slot_sel[1] && (expected32 !== data_read      )) )
                && !was_a_wr ) begin
            $display("ERROR: Wrong data read at time %t - %m", $time);
            $display("       at address %X (slot %d)", sdram_addr, slot_sel-2'd1 );
            $display("       expecting %X_%X - Read %X_%X\n",
                    expected32[31:16], expected32[15:0], data_read[31:16], data_read[15:0]);
            $finish;
        end
    end
end

`endif

endmodule
