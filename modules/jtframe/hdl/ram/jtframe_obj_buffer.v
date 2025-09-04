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
    Date: 27-10-2017 */

// Generic dual port RAM with clock enable
// parameters:
// DW      => Data bit width, 8 for byte-based memories
// AW      => Address bit width, 10 for 1kB
//
// Transparency when writting
// ALPHAW  => The bits ALPHAW-1:0 will be used for comparison
// ALPHA   => If the input data matches ALPHA it will not be written
//
// Old data deletion
// After rd input goes low, the data at rd_addr will be overwritten
// with the BLANK value. The data is deleted BLANK_DLY clock cycles
// after rd went low

module jtframe_obj_buffer #(parameter
    DW          = 8,
    AW          = 9,
    ALPHAW      = 4,
    ALPHA       = 32'HF,
    BLANK       = ALPHA,
    BLANK_DLY   = 2,
    FLIP_OFFSET = 0,
    SW          = 1,     // Shadow bits width (Use with SHADOW==1)
    SHADOW_PEN  = ALPHA, // Value used by only-shadow sprites. Use independently from shadow bits
                         // requires at least two clock cycles
    SHADOW      = 0,     // 1 enables shadows on data MSB
    KEEP_OLD    = 0      // Do not overwrite old non-ALPHA data
                         // requires address, data and we signals to be held
                         // for at least two clock cycles
)(
    input   clk,
    input   LHBL,
    input   flip,
    // New data writes
    input   [DW-1:0] wr_data,
    input   [AW-1:0] wr_addr,
    input   we,
    // Old data reads (and erases)
    input   [AW-1:0] rd_addr,
    input   rd,                 // data will be erased after the rd event
    output reg [DW-1:0] rd_data
);

localparam EW = SHADOW==1 ? DW-SW : DW;

reg     line, last_LHBL, new_we;
wire    is_opaque, was_blank, is_just_a_shadow;

reg [BLANK_DLY-1:0] dly;
wire                delete_we = dly[0];
wire [EW-1:0]       blank_data = BLANK[EW-1:0];
wire [DW-1:0]       dump_data;
wire [EW-1:0]       old;
wire                shade;

assign is_opaque        = wr_data[ALPHAW-1:0] != ALPHA[ALPHAW-1:0] && we;
assign was_blank        =     old[ALPHAW-1:0] == ALPHA[ALPHAW-1:0];
assign is_just_a_shadow = wr_data[ALPHAW-1:0] == SHADOW_PEN[ALPHAW-1:0];
assign shade            = wr_data[  DW-1-:SW] != 0;

always @* begin
    new_we = is_opaque;
    if( KEEP_OLD==1 && !was_blank || SHADOW==1 && is_just_a_shadow && shade)
        new_we = 0;
end


`ifdef SIMULATION
initial begin
    line = 0;
end
`endif

always @(posedge clk) begin
    last_LHBL <= LHBL;
    if( !LHBL && last_LHBL )
        line <= ~line;
end

always @(posedge clk) begin
    if( rd ) begin
        dly       <= { 1'b1, {BLANK_DLY-1{1'b0}}  };
    end else begin
        dly       <= dly>>1;
    end
    if( delete_we ) rd_data <= dump_data;
end

wire [AW-1:0] wr_af = flip ? ~wr_addr + FLIP_OFFSET[AW-1:0] : wr_addr;

jtframe_dual_ram #(.AW(AW+1),.DW(EW)) u_line(
    .clk0   ( clk           ),
    .clk1   ( clk           ),
    // Port 0
    .data0  (wr_data[EW-1:0]),
    .addr0  ( {line,wr_af}  ),
    .we0    ( new_we        ),
    .q0     ( old           ),
    // Port 1
    .data1  ( blank_data    ),
    .addr1  ({~line,rd_addr}),
    .we1    ( delete_we     ),
    .q1     (dump_data[EW-1:0])
);

generate
    if( SHADOW==1 ) begin
        wire          sh0_wemx, sh1_wemx, sh0_delmx, sh1_delmx,
                      erase_shade, add_shade;
        reg  [AW-1:0] sh_wa;
        wire [AW-1:0] sh0_rdmx, sh1_rdmx;
        wire [SW-1:0] shdout0,shdout1;
        reg  [SW-1:0] shdin;
        reg           newwe_l, we_l, sh_we;

        assign sh0_rdmx  =  line ? wr_af   : rd_addr;
        assign sh1_rdmx  = ~line ? wr_af   : rd_addr;
        assign sh0_wemx  =  line & sh_we;
        assign sh1_wemx  = ~line & sh_we;
        assign sh0_delmx = ~line & delete_we;
        assign sh1_delmx =  line & delete_we;

        assign erase_shade = !shade & new_we;
        assign add_shade   =  shade & we     && is_just_a_shadow;

        always @(posedge clk) begin
            shdin <= wr_data[DW-1-:SW];
            sh_wa <= wr_af;
            sh_we <= add_shade || erase_shade;
        end
        assign dump_data[DW-1-:SW] = ~line ? shdout0 : shdout1;

        jtframe_dual_ram #(.AW(AW),.DW(SW)) u_shadow0(
            .clk0   ( clk           ),
            .clk1   ( clk           ),
            // Port 0
            .data0  ( shdin         ),
            .addr0  ( sh_wa         ),
            .we0    ( sh0_wemx      ),
            .q0     (               ),
            // Port 1
            .data1  ( {SW{1'b0}}    ),
            .addr1  ( sh0_rdmx      ),
            .we1    ( sh0_delmx     ),
            .q1     ( shdout0       )
        );

        jtframe_dual_ram #(.AW(AW),.DW(SW)) u_shadow1(
            .clk0   ( clk           ),
            .clk1   ( clk           ),
            // Port 0
            .data0  ( shdin         ),
            .addr0  ( sh_wa         ),
            .we0    ( sh1_wemx      ),
            .q0     (               ),
            // Port 1
            .data1  ( {SW{1'b0}}    ),
            .addr1  ( sh1_rdmx      ),
            .we1    ( sh1_delmx     ),
            .q1     ( shdout1       )
        );
    end
endgenerate

endmodule